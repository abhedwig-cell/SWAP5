module mod_fmr_wofost_physical_trial_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t, &
       validate_crop_root_uptake_input, CROP_ROOT_INPUT_OK
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t
  use mod_soil_water_solver_contract, only: top_boundary_provider_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_serialized_commit_receipt_record_t, &
       fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK, FMR_SERIAL_DISPATCH_INVALID_REQUEST
  use mod_fmr_wofost_accepted_window_lineage, only: fmr_wofost_accepted_window_t, &
       fmr_wofost_trial_contribution_t, fmr_wofost_accepted_interval_certificate_t, &
       begin_wofost_trial_contribution, accumulate_wofost_trial_process_rate, &
       discard_wofost_trial_contribution, prevalidate_wofost_trial_admission, &
       certify_fkt_accepted_interval, admit_wofost_accepted_trial, FMR_WOFOST_LINEAGE_OK
  implicit none
  private

  integer, parameter, public :: FMR_WOF36_BINDING_OK = 0
  integer, parameter, public :: FMR_WOF36_BINDING_INVALID_REQUEST = 1
  integer, parameter, public :: FMR_WOF36_BINDING_INVALID_REGISTRY = 2
  integer, parameter, public :: FMR_WOF36_BINDING_INVALID_CROP_INPUT = 3
  integer, parameter, public :: FMR_WOF36_BINDING_INVALID_ROOT_SINK = 4
  integer, parameter, public :: FMR_WOF36_BINDING_CHECKPOINT_REJECTED = 5
  integer, parameter, public :: FMR_WOF36_BINDING_TRIAL_REJECTED = 6
  integer, parameter, public :: FMR_WOF36_BINDING_WINDOW_PREVALIDATION_REJECTED = 7

  public :: fmr_run_serialized_multiswap_with_wofost_integrals

contains

  subroutine fmr_run_serialized_multiswap_with_wofost_integrals(columns, templates, parameter_registry, &
       forcing_registry, state_registry, numerical_config, top_boundary, t0, t1, batch_size, &
       wofost_column_ids, crop_inputs, accepted_windows, results, diagnostics, aggregate, dispatch_status, &
       binding_status, runtime_diagnostics)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_template_t), intent(in) :: templates(:)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameter_registry(:)
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing_registry(:)
    type(kernel_committed_state_t), intent(inout) :: state_registry(:)
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    class(top_boundary_provider_t), target, intent(in) :: top_boundary
    real(real64), intent(in) :: t0, t1
    integer, intent(in) :: batch_size
    integer(int64), intent(in) :: wofost_column_ids(:)
    type(crop_root_uptake_input_t), intent(in) :: crop_inputs(:)
    type(fmr_wofost_accepted_window_t), intent(inout) :: accepted_windows(:)
    type(fmr_serialized_column_result_t), allocatable, intent(out) :: results(:)
    type(fmr_column_diagnostics_t), allocatable, intent(out) :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t), intent(out) :: aggregate
    integer, intent(out) :: dispatch_status
    integer, intent(out) :: binding_status
    type(fmr_serialized_batch_diagnostics_t), intent(out), optional :: runtime_diagnostics

    type(kernel_checkpoint_t), allocatable :: checkpoints(:)
    type(fmr_wofost_trial_contribution_t), allocatable :: trials(:)
    type(fmr_serialized_commit_receipt_record_t), allocatable :: receipts(:)
    type(fmr_wofost_accepted_interval_certificate_t) :: certificate
    type(fmr_serialized_batch_diagnostics_t) :: local_runtime
    integer, allocatable :: column_index(:), state_index(:), parameter_index(:), forcing_index(:)
    integer :: i, idx, sidx, pidx, fidx, crop_status, lineage_status
    real(real64) :: ptra_rate, qrot_rate
    logical :: checkpoint_ok

    binding_status = FMR_WOF36_BINDING_OK
    dispatch_status = FMR_SERIAL_DISPATCH_OK
    call initialize_local_runtime(size(columns), t0, t1, local_runtime)

    if (size(wofost_column_ids) == 0) then
      if (size(crop_inputs) /= 0 .or. size(accepted_windows) /= 0) then
        binding_status = FMR_WOF36_BINDING_INVALID_REQUEST
        call reject_before_physical(columns, t0, t1, results, diagnostics, aggregate, dispatch_status)
        if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
        return
      end if
      call fmr_run_serialized_physical_multiswap(columns, templates, parameter_registry, forcing_registry, &
           state_registry, numerical_config, top_boundary, t0, t1, batch_size, results, diagnostics, aggregate, &
           dispatch_status, local_runtime)
      if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
      return
    end if

    if (size(crop_inputs) /= size(wofost_column_ids) .or. &
        size(accepted_windows) /= size(wofost_column_ids) .or. t1 <= t0) then
      binding_status = FMR_WOF36_BINDING_INVALID_REQUEST
      call reject_before_physical(columns, t0, t1, results, diagnostics, aggregate, dispatch_status)
      if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
      return
    end if
    if (.not. unique_positive_ids(wofost_column_ids)) then
      binding_status = FMR_WOF36_BINDING_INVALID_REQUEST
      call reject_before_physical(columns, t0, t1, results, diagnostics, aggregate, dispatch_status)
      if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
      return
    end if

    allocate(checkpoints(size(wofost_column_ids)), trials(size(wofost_column_ids)))
    allocate(column_index(size(wofost_column_ids)), state_index(size(wofost_column_ids)), &
             parameter_index(size(wofost_column_ids)), forcing_index(size(wofost_column_ids)))

    do i = 1, size(wofost_column_ids)
      idx = find_unique_column_index(wofost_column_ids(i), columns)
      if (idx <= 0) then
        binding_status = FMR_WOF36_BINDING_INVALID_REGISTRY
        call reject_before_physical(columns, t0, t1, results, diagnostics, aggregate, dispatch_status)
        if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
        return
      end if
      column_index(i) = idx

      if (columns(idx)%state_handle < 1_int64 .or. &
          columns(idx)%state_handle > int(size(state_registry), int64) .or. &
          columns(idx)%parameter_ref < 1_int64 .or. &
          columns(idx)%parameter_ref > int(size(parameter_registry), int64) .or. &
          columns(idx)%forcing_handle < 1_int64 .or. &
          columns(idx)%forcing_handle > int(size(forcing_registry), int64)) then
        binding_status = FMR_WOF36_BINDING_INVALID_REGISTRY
        call reject_before_physical(columns, t0, t1, results, diagnostics, aggregate, dispatch_status)
        if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
        return
      end if

      sidx = int(columns(idx)%state_handle)
      pidx = int(columns(idx)%parameter_ref)
      fidx = int(columns(idx)%forcing_handle)
      state_index(i) = sidx
      parameter_index(i) = pidx
      forcing_index(i) = fidx

      call validate_crop_root_uptake_input(crop_inputs(i), parameter_registry(pidx)%active_nodes, crop_status)
      if (crop_status /= CROP_ROOT_INPUT_OK) then
        binding_status = FMR_WOF36_BINDING_INVALID_CROP_INPUT
        call reject_before_physical(columns, t0, t1, results, diagnostics, aggregate, dispatch_status)
        if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
        return
      end if
      ptra_rate = crop_inputs(i)%potential_transpiration

      if (.not. parameter_registry(pidx)%root_extraction_active) then
        binding_status = FMR_WOF36_BINDING_INVALID_ROOT_SINK
        call reject_before_physical(columns, t0, t1, results, diagnostics, aggregate, dispatch_status)
        if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
        return
      end if
      if (.not. allocated(forcing_registry(fidx)%root_extraction_sink)) then
        binding_status = FMR_WOF36_BINDING_INVALID_ROOT_SINK
        call reject_before_physical(columns, t0, t1, results, diagnostics, aggregate, dispatch_status)
        if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
        return
      end if
      if (size(forcing_registry(fidx)%root_extraction_sink) /= parameter_registry(pidx)%active_nodes) then
        binding_status = FMR_WOF36_BINDING_INVALID_ROOT_SINK
        call reject_before_physical(columns, t0, t1, results, diagnostics, aggregate, dispatch_status)
        if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
        return
      end if
      if (any(.not. ieee_is_finite(forcing_registry(fidx)%root_extraction_sink)) .or. &
          any(forcing_registry(fidx)%root_extraction_sink < 0.0_real64)) then
        binding_status = FMR_WOF36_BINDING_INVALID_ROOT_SINK
        call reject_before_physical(columns, t0, t1, results, diagnostics, aggregate, dispatch_status)
        if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
        return
      end if
      qrot_rate = sum(forcing_registry(fidx)%root_extraction_sink)
      if (.not. ieee_is_finite(qrot_rate) .or. qrot_rate < 0.0_real64 .or. &
          .not. ieee_is_finite(ptra_rate) .or. ptra_rate < 0.0_real64) then
        binding_status = FMR_WOF36_BINDING_INVALID_ROOT_SINK
        call reject_before_physical(columns, t0, t1, results, diagnostics, aggregate, dispatch_status)
        if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
        return
      end if

      call state_registry(sidx)%capture_checkpoint(checkpoints(i), checkpoint_ok)
      if (.not. checkpoint_ok) then
        binding_status = FMR_WOF36_BINDING_CHECKPOINT_REJECTED
        call reject_before_physical(columns, t0, t1, results, diagnostics, aggregate, dispatch_status)
        if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
        return
      end if

      call begin_wofost_trial_contribution(checkpoints(i), t1, trials(i), lineage_status)
      if (lineage_status /= FMR_WOFOST_LINEAGE_OK) then
        binding_status = FMR_WOF36_BINDING_TRIAL_REJECTED
        call reject_before_physical(columns, t0, t1, results, diagnostics, aggregate, dispatch_status)
        if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
        return
      end if
      call accumulate_wofost_trial_process_rate(trials(i), t0, t1, qrot_rate, ptra_rate, lineage_status)
      if (lineage_status /= FMR_WOFOST_LINEAGE_OK .or. .not. trials(i)%complete()) then
        binding_status = FMR_WOF36_BINDING_TRIAL_REJECTED
        call reject_before_physical(columns, t0, t1, results, diagnostics, aggregate, dispatch_status)
        if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
        return
      end if
      call prevalidate_wofost_trial_admission(accepted_windows(i), trials(i), lineage_status)
      if (lineage_status /= FMR_WOFOST_LINEAGE_OK) then
        binding_status = FMR_WOF36_BINDING_WINDOW_PREVALIDATION_REJECTED
        call reject_before_physical(columns, t0, t1, results, diagnostics, aggregate, dispatch_status)
        if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
        return
      end if
    end do

    call fmr_run_serialized_physical_multiswap(columns, templates, parameter_registry, forcing_registry, &
         state_registry, numerical_config, top_boundary, t0, t1, batch_size, results, diagnostics, aggregate, &
         dispatch_status, local_runtime, receipt_column_ids=wofost_column_ids, commit_receipts=receipts)
    if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
    if (dispatch_status /= FMR_SERIAL_DISPATCH_OK) return

    if (size(receipts) /= size(wofost_column_ids)) &
         error stop 'F-WOF36: sparse receipt cardinality changed after prevalidation'

    do i = 1, size(wofost_column_ids)
      if (receipts(i)%column_id /= wofost_column_ids(i)) &
           error stop 'F-WOF36: sparse receipt column association changed after prevalidation'
      if (.not. receipts(i)%receipt%ready()) then
        call discard_wofost_trial_contribution(trials(i))
        cycle
      end if

      if (.not. receipt_matches_prevalidated_trial(receipts(i), checkpoints(i), t0, t1)) &
           error stop 'F-WOF36: ready receipt does not match prevalidated physical-trial provenance'

      call certify_fkt_accepted_interval(checkpoints(i), state_registry(state_index(i)), certificate, lineage_status)
      if (lineage_status /= FMR_WOFOST_LINEAGE_OK) &
           error stop 'F-WOF36: ready receipt without matching F-KT accepted-interval certificate'

      call admit_wofost_accepted_trial(accepted_windows(i), certificate, trials(i), lineage_status)
      if (lineage_status /= FMR_WOFOST_LINEAGE_OK) &
           error stop 'F-WOF36: prevalidated accepted-window admission failed after physical commit'
    end do
  end subroutine fmr_run_serialized_multiswap_with_wofost_integrals

  subroutine reject_before_physical(columns, t0, t1, results, diagnostics, aggregate, dispatch_status)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    real(real64), intent(in) :: t0, t1
    type(fmr_serialized_column_result_t), allocatable, intent(out) :: results(:)
    type(fmr_column_diagnostics_t), allocatable, intent(out) :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t), intent(out) :: aggregate
    integer, intent(out) :: dispatch_status
    integer :: i

    allocate(results(size(columns)), diagnostics(size(columns)))
    aggregate = fmr_aggregate_diagnostics_t()
    aggregate%columns = size(columns)
    aggregate%workers = 1
    do i = 1, size(columns)
      results(i)%column_id = columns(i)%column_id
      results(i)%requested_t0 = t0
      results(i)%requested_t1 = t1
      diagnostics(i)%column_id = columns(i)%column_id
      diagnostics(i)%template_id = columns(i)%template_id
      diagnostics(i)%backend = columns(i)%backend_id
      diagnostics(i)%execution_class = columns(i)%execution_class
      diagnostics(i)%rejected = 1
      diagnostics(i)%failure_classification = 'WOFOST_BINDING_REJECTED'
      allocate(diagnostics(i)%worker_assignments(1))
      diagnostics(i)%worker_assignments(1) = 1
    end do
    dispatch_status = FMR_SERIAL_DISPATCH_INVALID_REQUEST
  end subroutine reject_before_physical

  subroutine initialize_local_runtime(number_requested, t0, t1, runtime)
    integer, intent(in) :: number_requested
    real(real64), intent(in) :: t0, t1
    type(fmr_serialized_batch_diagnostics_t), intent(out) :: runtime

    runtime = fmr_serialized_batch_diagnostics_t()
    runtime%number_requested = number_requested
    runtime%effective_t0 = t0
    runtime%effective_t1 = t1
  end subroutine initialize_local_runtime

  logical function unique_positive_ids(ids) result(valid)
    integer(int64), intent(in) :: ids(:)
    integer :: i, j

    valid = .false.
    do i = 1, size(ids)
      if (ids(i) <= 0_int64) return
      do j = i + 1, size(ids)
        if (ids(j) == ids(i)) return
      end do
    end do
    valid = .true.
  end function unique_positive_ids

  integer function find_unique_column_index(column_id, columns) result(index)
    integer(int64), intent(in) :: column_id
    type(fmr_logical_column_t), intent(in) :: columns(:)
    integer :: i, matches

    index = 0
    matches = 0
    do i = 1, size(columns)
      if (columns(i)%column_id == column_id) then
        matches = matches + 1
        index = i
      end if
    end do
    if (matches /= 1) index = 0
  end function find_unique_column_index

  logical function receipt_matches_prevalidated_trial(record, checkpoint, expected_t0, expected_t1) result(matches)
    type(fmr_serialized_commit_receipt_record_t), intent(in) :: record
    type(kernel_checkpoint_t), intent(in) :: checkpoint
    real(real64), intent(in) :: expected_t0, expected_t1
    real(real64) :: receipt_t0, receipt_t1, checkpoint_t0
    logical :: receipt_interval_available, checkpoint_time_available

    matches = .false.
    if (.not. record%receipt%ready()) return
    if (.not. checkpoint%ready()) return
    if (record%receipt%current_lineage_id() /= checkpoint%current_lineage_id()) return
    if (record%receipt%origin_revision() /= checkpoint%origin_revision()) return
    if (record%receipt%committed_revision() /= checkpoint%origin_revision() + 1_int64) return

    call record%receipt%origin_interval(receipt_t0, receipt_t1, receipt_interval_available)
    if (.not. receipt_interval_available) return
    call checkpoint%current_time(checkpoint_t0, checkpoint_time_available)
    if (.not. checkpoint_time_available) return
    if (.not. same_time(receipt_t0, checkpoint_t0)) return
    if (.not. same_time(receipt_t0, expected_t0)) return
    if (.not. same_time(receipt_t1, expected_t1)) return
    matches = .true.
  end function receipt_matches_prevalidated_trial

  pure logical function same_time(a, b) result(matches)
    real(real64), intent(in) :: a, b
    real(real64) :: scale

    matches = .false.
    if (.not. ieee_is_finite(a) .or. .not. ieee_is_finite(b)) return
    scale = max(1.0_real64, abs(a), abs(b))
    matches = abs(a-b) <= 64.0_real64 * epsilon(1.0_real64) * scale
  end function same_time

end module mod_fmr_wofost_physical_trial_binding
