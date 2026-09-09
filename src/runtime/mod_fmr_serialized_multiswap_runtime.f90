module mod_fmr_serialized_multiswap_runtime
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: TX_MASS_MISSING_NONE, TX_MASS_MISSING_UNSPECIFIED
  use mod_canonical_contracts, only: canonical_mass_accounting_t, canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_result_t, kernel_diagnostics_t, kernel_executor_t, KERNEL_STATUS_NOT_ADMITTED
  use mod_soil_water_solver_contract, only: top_boundary_provider_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint, fmr_commit_candidate, fmr_discard_candidate
  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t, fmr_commit_candidate_with_receipt, &
       FMR_COMMIT_RECEIPT_OK, FMR_COMMIT_RECEIPT_COMMIT_REJECTED
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, fmr_build_execution_order, fmr_count_templates, &
       FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, &
       fmr_serialized_physical_observation_t
  implicit none
  private

  integer, parameter, public :: FMR_SERIAL_DISPATCH_OK = 0
  integer, parameter, public :: FMR_SERIAL_DISPATCH_INVALID_REQUEST = 1
  integer, parameter, public :: FMR_SERIAL_DISPATCH_REGISTRY_REJECTED = 2
  integer, parameter, public :: FMR_SERIAL_DISPATCH_RECEIPT_REQUEST_REJECTED = 3

  type, public :: fmr_serialized_column_result_t
    integer(int64) :: column_id = 0_int64
    integer :: dispatch_ordinal = 0
    real(real64) :: requested_t0 = 0.0_real64
    real(real64) :: requested_t1 = 0.0_real64
    logical :: admission_assessed = .false.
    logical :: admitted = .false.
    character(len=40) :: admission_status = 'NOT_ASSESSED'
    integer :: kernel_status = 0
    integer :: commit_status = -1
    logical :: completed = .false.
    logical :: committed = .false.
    logical :: solver_executed = .false.
    character(len=32) :: solver_route = 'not-run'
    integer :: solver_iterations = 0
    integer :: accepted_substeps = 0
    integer :: solver_nonlinear_iterations = 0
    integer :: solver_internal_retries = 0
    integer :: solver_headcalc_calls = 0
    integer :: solver_jacobian_builds = 0
    integer :: solver_linear_solves = 0
    integer :: solver_backtracking_attempts = 0
    integer :: solver_alternative_solver_calls = 0
    integer(int64) :: initial_revision = -1_int64
    integer(int64) :: final_revision = -1_int64
    real(real64) :: final_committed_time = 0.0_real64
    logical :: final_committed_time_bound = .false.
    type(canonical_mass_accounting_t) :: mass
  end type fmr_serialized_column_result_t

  ! F-MR05-specific composition diagnostics.  This is deliberately separate
  ! from the generic F-MR01 aggregate type so the strict serialized physical
  ! admission constraint does not leak into the logical runtime core.
  type, public :: fmr_serialized_batch_diagnostics_t
    integer :: number_requested = 0
    integer :: number_admitted = 0
    integer :: number_executed = 0
    integer :: number_committed = 0
    integer :: number_rejected = 0
    integer :: physical_solve_count = 0
    integer :: max_simultaneous_real_physical_solves = 0
    logical :: deterministic_collection = .false.
    real(real64) :: effective_t0 = 0.0_real64
    real(real64) :: effective_t1 = 0.0_real64
    real(real64) :: max_abs_column_mass_residual = 0.0_real64
    type(canonical_mass_accounting_t) :: authoritative_aggregate_mass
  end type fmr_serialized_batch_diagnostics_t

  public :: fmr_run_serialized_physical_multiswap

contains

  subroutine fmr_run_serialized_physical_multiswap(columns, templates, parameter_registry, forcing_registry, &
                                                    state_registry, numerical_config, top_boundary, t0, t1, &
                                                    batch_size, results, diagnostics, aggregate, dispatch_status, &
                                                    runtime_diagnostics, receipt_column_ids, commit_receipts)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_template_t), intent(in) :: templates(:)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameter_registry(:)
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing_registry(:)
    type(kernel_committed_state_t), intent(inout) :: state_registry(:)
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    class(top_boundary_provider_t), target, intent(in) :: top_boundary
    real(real64), intent(in) :: t0, t1
    integer, intent(in) :: batch_size
    type(fmr_serialized_column_result_t), allocatable, intent(out) :: results(:)
    type(fmr_column_diagnostics_t), allocatable, intent(out) :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t), intent(out) :: aggregate
    integer, intent(out) :: dispatch_status
    type(fmr_serialized_batch_diagnostics_t), intent(out), optional :: runtime_diagnostics
    integer(int64), intent(in), optional :: receipt_column_ids(:)
    type(fmr_accepted_commit_receipt_t), allocatable, intent(out), optional :: commit_receipts(:)

    type(fmr_serialized_reference_backend_t), target :: backend
    type(kernel_executor_t) :: transaction_control
    type(fmr_serialized_batch_diagnostics_t) :: local_runtime
    integer, allocatable :: order(:)
    integer :: batch_start, batch_end, pos, idx, batches, active_physical_calls, receipt_slot

    call initialize_outputs(columns, t0, t1, results, diagnostics, aggregate)
    call initialize_runtime_diagnostics(size(columns), t0, t1, local_runtime)
    active_physical_calls = 0
    dispatch_status = FMR_SERIAL_DISPATCH_OK
    if (present(commit_receipts)) allocate(commit_receipts(0))

    ! Receipt requests are optional feature-scoped runtime metadata. Validate
    ! the complete sparse request before backend initialization or any physical
    ! trial so every expected request error is transactionally precommit.
    if (present(receipt_column_ids) .neqv. present(commit_receipts)) then
      dispatch_status = FMR_SERIAL_DISPATCH_RECEIPT_REQUEST_REJECTED
      call mark_all_rejected(diagnostics, 'RECEIPT_REQUEST_REJECTED')
      call build_aggregate(columns, diagnostics, 0, aggregate)
      call finalize_runtime_diagnostics(results, local_runtime)
      if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
      return
    end if
    if (present(receipt_column_ids)) then
      if (.not. receipt_request_valid(columns, receipt_column_ids)) then
        dispatch_status = FMR_SERIAL_DISPATCH_RECEIPT_REQUEST_REJECTED
        call mark_all_rejected(diagnostics, 'RECEIPT_REQUEST_REJECTED')
        call build_aggregate(columns, diagnostics, 0, aggregate)
        call finalize_runtime_diagnostics(results, local_runtime)
        if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
        return
      end if
      deallocate(commit_receipts)
      allocate(commit_receipts(size(receipt_column_ids)))
    end if

    if (batch_size <= 0 .or. t1 <= t0) then
      dispatch_status = FMR_SERIAL_DISPATCH_INVALID_REQUEST
      call mark_all_rejected(diagnostics, 'INVALID_DISPATCH_REQUEST')
      call build_aggregate(columns, diagnostics, 0, aggregate)
      call finalize_runtime_diagnostics(results, local_runtime)
      if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
      return
    end if

    if (.not. registry_structure_valid(columns, templates, state_registry)) then
      dispatch_status = FMR_SERIAL_DISPATCH_REGISTRY_REJECTED
      call mark_all_rejected(diagnostics, 'REGISTRY_STRUCTURE_REJECTED')
      call build_aggregate(columns, diagnostics, 0, aggregate)
      call finalize_runtime_diagnostics(results, local_runtime)
      if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
      return
    end if

    call backend%initialize(top_boundary)
    call fmr_build_execution_order(columns, order)
    batches = 0
    do batch_start = 1, size(columns), batch_size
      batches = batches + 1
      batch_end = min(size(columns), batch_start + batch_size - 1)
      do pos = batch_start, batch_end
        idx = order(pos)
        results(idx)%dispatch_ordinal = pos
        receipt_slot = 0
        if (present(receipt_column_ids)) receipt_slot = find_receipt_slot(columns(idx)%column_id, receipt_column_ids)
        if (receipt_slot > 0) then
          call execute_column(backend, transaction_control, columns(idx), templates, parameter_registry, &
               forcing_registry, state_registry, numerical_config, t0, t1, results(idx), diagnostics(idx), &
               local_runtime, active_physical_calls, commit_receipts(receipt_slot))
        else
          call execute_column(backend, transaction_control, columns(idx), templates, parameter_registry, &
               forcing_registry, state_registry, numerical_config, t0, t1, results(idx), diagnostics(idx), &
               local_runtime, active_physical_calls)
        end if
      end do
    end do

    local_runtime%deterministic_collection = .true.
    call build_aggregate(columns, diagnostics, batches, aggregate, order)
    call finalize_runtime_diagnostics(results, local_runtime, order)
    if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
  end subroutine fmr_run_serialized_physical_multiswap

  subroutine initialize_outputs(columns, t0, t1, results, diagnostics, aggregate)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    real(real64), intent(in) :: t0, t1
    type(fmr_serialized_column_result_t), allocatable, intent(out) :: results(:)
    type(fmr_column_diagnostics_t), allocatable, intent(out) :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t), intent(out) :: aggregate
    integer :: i

    allocate(results(size(columns)), diagnostics(size(columns)))
    aggregate = fmr_aggregate_diagnostics_t()
    do i = 1, size(columns)
      results(i)%column_id = columns(i)%column_id
      results(i)%requested_t0 = t0
      results(i)%requested_t1 = t1
      diagnostics(i)%column_id = columns(i)%column_id
      diagnostics(i)%template_id = columns(i)%template_id
      diagnostics(i)%backend = columns(i)%backend_id
      diagnostics(i)%execution_class = columns(i)%execution_class
      allocate(diagnostics(i)%worker_assignments(1))
      diagnostics(i)%worker_assignments(1) = 1
    end do
  end subroutine initialize_outputs

  subroutine initialize_runtime_diagnostics(number_requested, t0, t1, runtime)
    integer, intent(in) :: number_requested
    real(real64), intent(in) :: t0, t1
    type(fmr_serialized_batch_diagnostics_t), intent(out) :: runtime

    runtime = fmr_serialized_batch_diagnostics_t()
    runtime%number_requested = number_requested
    runtime%effective_t0 = t0
    runtime%effective_t1 = t1
    runtime%authoritative_aggregate_mass = canonical_mass_accounting_t()
    runtime%authoritative_aggregate_mass%interval_t0 = t0
    runtime%authoritative_aggregate_mass%interval_t1 = t1
    runtime%authoritative_aggregate_mass%missing_contribution_mask = TX_MASS_MISSING_UNSPECIFIED
  end subroutine initialize_runtime_diagnostics

  logical function receipt_request_valid(columns, receipt_column_ids) result(valid)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    integer(int64), intent(in) :: receipt_column_ids(:)
    integer :: i, j

    valid = .true.
    do i = 1, size(receipt_column_ids)
      if (receipt_column_ids(i) <= 0_int64) then
        valid = .false.
        return
      end if
      if (.not. any(columns%column_id == receipt_column_ids(i))) then
        valid = .false.
        return
      end if
      do j = i + 1, size(receipt_column_ids)
        if (receipt_column_ids(j) == receipt_column_ids(i)) then
          valid = .false.
          return
        end if
      end do
    end do
  end function receipt_request_valid

  integer function find_receipt_slot(column_id, receipt_column_ids) result(slot)
    integer(int64), intent(in) :: column_id
    integer(int64), intent(in) :: receipt_column_ids(:)
    integer :: i

    slot = 0
    do i = 1, size(receipt_column_ids)
      if (receipt_column_ids(i) == column_id) then
        slot = i
        return
      end if
    end do
  end function find_receipt_slot

  logical function registry_structure_valid(columns, templates, states) result(valid)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_template_t), intent(in) :: templates(:)
    type(kernel_committed_state_t), intent(in) :: states(:)
    logical, allocatable :: state_claimed(:)
    integer :: i, j, state_index

    valid = .false.

    do i = 1, size(templates)
      if (templates(i)%template_id <= 0_int64) return
      do j = i + 1, size(templates)
        if (templates(j)%template_id == templates(i)%template_id) return
      end do
    end do

    allocate(state_claimed(size(states)))
    state_claimed = .false.
    do i = 1, size(columns)
      if (columns(i)%column_id <= 0_int64) return
      do j = i + 1, size(columns)
        if (columns(j)%column_id == columns(i)%column_id) return
      end do
      if (columns(i)%state_handle < 1_int64 .or. &
          columns(i)%state_handle > int(size(states), int64)) return
      state_index = int(columns(i)%state_handle)
      if (state_claimed(state_index)) return
      state_claimed(state_index) = .true.
    end do

    valid = .true.
  end function registry_structure_valid

  subroutine execute_column(backend, transaction_control, column, templates, parameter_registry, forcing_registry, &
                            state_registry, numerical_config, t0, t1, output, diagnostic, runtime, active_physical_calls, &
                            commit_receipt)
    type(fmr_serialized_reference_backend_t), intent(inout) :: backend
    type(kernel_executor_t), intent(inout) :: transaction_control
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: templates(:)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameter_registry(:)
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing_registry(:)
    type(kernel_committed_state_t), intent(inout) :: state_registry(:)
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    real(real64), intent(in) :: t0, t1
    type(fmr_serialized_column_result_t), intent(inout) :: output
    type(fmr_column_diagnostics_t), intent(inout) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t), intent(inout) :: runtime
    integer, intent(inout) :: active_physical_calls
    type(fmr_accepted_commit_receipt_t), intent(out), optional :: commit_receipt

    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_result_t) :: kernel_result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: kernel_diag
    type(fmr_serialized_physical_observation_t) :: observation
    integer :: state_index, parameter_index, forcing_index, commit_status, receipt_status
    logical :: checkpoint_ok, candidate_ready, did_commit

    if (.not. column_is_routable(column, templates, parameter_registry, forcing_registry)) then
      output%admission_status = 'ROUTING_REJECTED'
      diagnostic%rejected = 1
      diagnostic%failure_classification = 'ROUTING_REJECTED'
      call update_committed_provenance_by_handle(column, state_registry, output, diagnostic)
      return
    end if

    state_index = int(column%state_handle)
    parameter_index = int(column%parameter_ref)
    forcing_index = int(column%forcing_handle)
    output%initial_revision = state_registry(state_index)%current_revision()

    call fmr_capture_checkpoint(state_registry(state_index), checkpoint, checkpoint_ok)
    if (.not. checkpoint_ok) then
      output%admission_status = 'CHECKPOINT_CAPTURE_FAILED'
      diagnostic%rejected = 1
      diagnostic%failure_classification = 'CHECKPOINT_CAPTURE_FAILED'
      call update_committed_provenance(state_registry(state_index), output, diagnostic)
      return
    end if

    diagnostic%checkpoint_captures = 1
    diagnostic%checkpoint_replays = 1
    diagnostic%runtime_attempts = 1

    active_physical_calls = active_physical_calls + 1
    call backend%run_trial(column, templates(find_template_index(column%template_id, templates)), &
         parameter_registry(parameter_index), state_registry(state_index), forcing_registry(forcing_index), &
         numerical_config, t0, t1, checkpoint, kernel_result, candidate, kernel_diag)

    output%kernel_status = kernel_result%status
    output%mass = kernel_result%mass
    diagnostic%attempts = kernel_diag%attempts
    diagnostic%retries = kernel_diag%retries
    output%accepted_substeps = kernel_diag%accepted_substeps
    output%solver_nonlinear_iterations = kernel_diag%nonlinear_iterations
    output%solver_internal_retries = kernel_diag%internal_retries
    output%solver_headcalc_calls = kernel_diag%headcalc_calls
    output%solver_jacobian_builds = kernel_diag%jacobian_builds
    output%solver_linear_solves = kernel_diag%linear_solves
    output%solver_backtracking_attempts = kernel_diag%backtracking_attempts
    output%solver_alternative_solver_calls = kernel_diag%alternative_solver_calls
    candidate_ready = candidate%ready()

    if (kernel_diag%admission_rejections > 0 .or. kernel_result%status == KERNEL_STATUS_NOT_ADMITTED) then
      output%admission_assessed = .true.
      output%admitted = .false.
      output%admission_status = 'PHYSICAL_PROFILE_REJECTED'
    else if (kernel_diag%transaction_calls > 0 .or. kernel_result%completed) then
      output%admission_assessed = .true.
      output%admitted = .true.
      output%admission_status = 'ADMITTED'
    else
      output%admission_status = 'PRE_ADMISSION_REJECTED'
    end if

    if (kernel_diag%transaction_calls > 0) then
      observation = backend%observation()
      output%solver_executed = observation%solver_executed
      output%solver_route = observation%solver_diagnostics%route
      output%solver_iterations = observation%solver_diagnostics%nonlinear_iterations
      if (output%solver_executed) then
        runtime%max_simultaneous_real_physical_solves = max( &
             runtime%max_simultaneous_real_physical_solves, active_physical_calls)
      end if
    end if
    active_physical_calls = active_physical_calls - 1

    if (.not. kernel_result%completed) then
      if (candidate_ready) call fmr_discard_candidate(transaction_control, candidate, kernel_diag)
      diagnostic%rejected = 1
      diagnostic%failure_classification = 'KERNEL_REJECTED'
      call update_committed_provenance(state_registry(state_index), output, diagnostic)
      return
    end if

    if (.not. kernel_result%mass%complete .or. &
        kernel_result%mass%missing_contribution_mask /= TX_MASS_MISSING_NONE) then
      if (candidate_ready) call fmr_discard_candidate(transaction_control, candidate, kernel_diag)
      diagnostic%rejected = 1
      diagnostic%failure_classification = 'MASS_INCOMPLETE'
      call update_committed_provenance(state_registry(state_index), output, diagnostic)
      return
    end if

    if (.not. candidate_ready) then
      diagnostic%rejected = 1
      diagnostic%failure_classification = 'CANDIDATE_INVALID'
      call update_committed_provenance(state_registry(state_index), output, diagnostic)
      return
    end if

    if (present(commit_receipt)) then
      call fmr_commit_candidate_with_receipt(transaction_control, checkpoint, state_registry(state_index), candidate, &
           kernel_diag, did_commit, commit_receipt, receipt_status, commit_status)
    else
      receipt_status = FMR_COMMIT_RECEIPT_OK
      call fmr_commit_candidate(transaction_control, state_registry(state_index), candidate, kernel_diag, &
           did_commit, commit_status)
    end if
    output%commit_status = commit_status
    if (.not. did_commit) then
      diagnostic%rejected = 1
      if (present(commit_receipt) .and. receipt_status /= FMR_COMMIT_RECEIPT_COMMIT_REJECTED) then
        diagnostic%failure_classification = 'RECEIPT_PREVALIDATION_REJECTED'
      else
        diagnostic%failure_classification = 'COMMIT_REJECTED'
      end if
      call update_committed_provenance(state_registry(state_index), output, diagnostic)
      return
    end if
    if (present(commit_receipt)) then
      if (receipt_status /= FMR_COMMIT_RECEIPT_OK .or. .not. commit_receipt%ready()) &
           error stop 'F-MR18: successful physical commit without ready accepted receipt'
    end if

    output%completed = .true.
    output%committed = .true.
    diagnostic%accepted = 1
    diagnostic%failure_classification = 'NONE'
    diagnostic%unrounded_mass_residual = output%mass%residual
    call update_committed_provenance(state_registry(state_index), output, diagnostic)
  end subroutine execute_column

  logical function column_is_routable(column, templates, parameter_registry, forcing_registry) result(routable)
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: templates(:)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameter_registry(:)
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing_registry(:)
    integer :: template_index

    template_index = find_template_index(column%template_id, templates)
    routable = template_index > 0 .and. column%backend_id == FMR_BACKEND_SERIALIZED_REFERENCE .and. &
         column%parameter_ref >= 1_int64 .and. &
         column%parameter_ref <= int(size(parameter_registry), int64) .and. &
         column%forcing_handle >= 1_int64 .and. &
         column%forcing_handle <= int(size(forcing_registry), int64)
    if (routable) routable = templates(template_index)%compatible_backend_id == FMR_BACKEND_SERIALIZED_REFERENCE
  end function column_is_routable

  integer function find_template_index(template_id, templates) result(index)
    integer(int64), intent(in) :: template_id
    type(fmr_template_t), intent(in) :: templates(:)
    integer :: i

    index = 0
    do i = 1, size(templates)
      if (templates(i)%template_id == template_id) then
        index = i
        return
      end if
    end do
  end function find_template_index

  subroutine update_committed_provenance_by_handle(column, states, output, diagnostic)
    type(fmr_logical_column_t), intent(in) :: column
    type(kernel_committed_state_t), intent(in) :: states(:)
    type(fmr_serialized_column_result_t), intent(inout) :: output
    type(fmr_column_diagnostics_t), intent(inout) :: diagnostic
    integer :: state_index

    if (column%state_handle < 1_int64 .or. column%state_handle > int(size(states), int64)) return
    state_index = int(column%state_handle)
    call update_committed_provenance(states(state_index), output, diagnostic)
  end subroutine update_committed_provenance_by_handle

  subroutine update_committed_provenance(committed, output, diagnostic)
    type(kernel_committed_state_t), intent(in) :: committed
    type(fmr_serialized_column_result_t), intent(inout) :: output
    type(fmr_column_diagnostics_t), intent(inout) :: diagnostic
    logical :: available

    output%final_revision = committed%current_revision()
    call committed%current_time(output%final_committed_time, available)
    output%final_committed_time_bound = available
    diagnostic%committed_revision = output%final_revision
    diagnostic%committed_time = output%final_committed_time
    diagnostic%committed_time_bound = available
  end subroutine update_committed_provenance

  subroutine mark_all_rejected(diagnostics, classification)
    type(fmr_column_diagnostics_t), intent(inout) :: diagnostics(:)
    character(len=*), intent(in) :: classification
    integer :: i

    do i = 1, size(diagnostics)
      diagnostics(i)%rejected = 1
      diagnostics(i)%failure_classification = classification
    end do
  end subroutine mark_all_rejected

  subroutine build_aggregate(columns, diagnostics, batches, aggregate, execution_order)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_column_diagnostics_t), intent(in) :: diagnostics(:)
    integer, intent(in) :: batches
    type(fmr_aggregate_diagnostics_t), intent(inout) :: aggregate
    integer, intent(in), optional :: execution_order(:)
    integer, allocatable :: local_order(:)
    integer :: pos, i

    aggregate = fmr_aggregate_diagnostics_t()
    aggregate%columns = size(columns)
    aggregate%templates = fmr_count_templates(columns)
    aggregate%batches = batches
    aggregate%workers = 1
    allocate(aggregate%work_distribution(1))
    aggregate%work_distribution = 0_int64

    allocate(local_order(size(columns)))
    if (present(execution_order)) then
      local_order = execution_order
    else
      do i = 1, size(columns)
        local_order(i) = i
      end do
    end if

    do pos = 1, size(local_order)
      i = local_order(pos)
      aggregate%attempts = aggregate%attempts + diagnostics(i)%attempts
      aggregate%retries = aggregate%retries + diagnostics(i)%retries
      if (diagnostics(i)%accepted == 0) aggregate%failures = aggregate%failures + 1
      if (diagnostics(i)%accepted == 1) then
        aggregate%aggregate_unrounded_mass_residual = aggregate%aggregate_unrounded_mass_residual + &
             diagnostics(i)%unrounded_mass_residual
      end if
    end do
    aggregate%work_distribution(1) = int(aggregate%attempts, int64)
  end subroutine build_aggregate

  subroutine finalize_runtime_diagnostics(results, runtime, execution_order)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    type(fmr_serialized_batch_diagnostics_t), intent(inout) :: runtime
    integer, intent(in), optional :: execution_order(:)
    integer, allocatable :: local_order(:)
    integer :: pos, i
    logical :: aggregate_complete

    runtime%number_admitted = 0
    runtime%number_executed = 0
    runtime%number_committed = 0
    runtime%number_rejected = 0
    runtime%physical_solve_count = 0
    runtime%max_abs_column_mass_residual = 0.0_real64
    runtime%authoritative_aggregate_mass%complete = .false.
    runtime%authoritative_aggregate_mass%origin_lineage_id = 0_int64
    runtime%authoritative_aggregate_mass%origin_revision = -1_int64
    runtime%authoritative_aggregate_mass%accepted_transaction_count = 0
    runtime%authoritative_aggregate_mass%storage_start = 0.0_real64
    runtime%authoritative_aggregate_mass%storage_end = 0.0_real64
    runtime%authoritative_aggregate_mass%storage_change = 0.0_real64
    runtime%authoritative_aggregate_mass%total_in = 0.0_real64
    runtime%authoritative_aggregate_mass%total_out = 0.0_real64
    runtime%authoritative_aggregate_mass%residual = 0.0_real64
    aggregate_complete = .true.

    allocate(local_order(size(results)))
    if (present(execution_order)) then
      local_order = execution_order
    else
      do i = 1, size(results)
        local_order(i) = i
      end do
    end if

    do pos = 1, size(local_order)
      i = local_order(pos)
      if (results(i)%admitted) runtime%number_admitted = runtime%number_admitted + 1
      if (results(i)%solver_executed) then
        runtime%number_executed = runtime%number_executed + 1
        runtime%physical_solve_count = runtime%physical_solve_count + 1
      end if
      if (results(i)%committed) then
        runtime%number_committed = runtime%number_committed + 1
        aggregate_complete = aggregate_complete .and. results(i)%mass%complete .and. &
             results(i)%mass%missing_contribution_mask == TX_MASS_MISSING_NONE
        runtime%authoritative_aggregate_mass%accepted_transaction_count = &
             runtime%authoritative_aggregate_mass%accepted_transaction_count + &
             results(i)%mass%accepted_transaction_count
        runtime%authoritative_aggregate_mass%storage_start = runtime%authoritative_aggregate_mass%storage_start + &
             results(i)%mass%storage_start
        runtime%authoritative_aggregate_mass%storage_end = runtime%authoritative_aggregate_mass%storage_end + &
             results(i)%mass%storage_end
        runtime%authoritative_aggregate_mass%storage_change = runtime%authoritative_aggregate_mass%storage_change + &
             results(i)%mass%storage_change
        runtime%authoritative_aggregate_mass%total_in = runtime%authoritative_aggregate_mass%total_in + &
             results(i)%mass%total_in
        runtime%authoritative_aggregate_mass%total_out = runtime%authoritative_aggregate_mass%total_out + &
             results(i)%mass%total_out
        runtime%authoritative_aggregate_mass%residual = runtime%authoritative_aggregate_mass%residual + &
             results(i)%mass%residual
        runtime%max_abs_column_mass_residual = max(runtime%max_abs_column_mass_residual, abs(results(i)%mass%residual))
      else
        runtime%number_rejected = runtime%number_rejected + 1
      end if
    end do

    if (runtime%number_committed > 0 .and. aggregate_complete) then
      runtime%authoritative_aggregate_mass%complete = .true.
      runtime%authoritative_aggregate_mass%missing_contribution_mask = TX_MASS_MISSING_NONE
    else
      runtime%authoritative_aggregate_mass%complete = .false.
      runtime%authoritative_aggregate_mass%missing_contribution_mask = TX_MASS_MISSING_UNSPECIFIED
    end if
  end subroutine finalize_runtime_diagnostics

end module mod_fmr_serialized_multiswap_runtime
