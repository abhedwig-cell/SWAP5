module mod_fmr_root_uptake_attribution_receipt
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_soil_water_solver_contract, only: top_boundary_provider_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_serialized_commit_receipt_record_t, &
       fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK
  implicit none
  private

  integer, parameter, public :: FMR_ROOT_ATTRIBUTION_OK = 0
  integer, parameter, public :: FMR_ROOT_ATTRIBUTION_NOT_COMMITTED = 1
  integer, parameter, public :: FMR_ROOT_ATTRIBUTION_INVALID_FORCING = 2
  integer, parameter, public :: FMR_ROOT_ATTRIBUTION_PROVENANCE_MISMATCH = 3
  integer, parameter, public :: FMR_ROOT_ATTRIBUTION_MASS_SUBSET_MISMATCH = 4
  integer, parameter, public :: FMR_ROOT_ATTRIBUTION_RUNTIME_REJECTED = 5

  ! Postcommit reconciliation metadata only.  The amount is the accepted
  ! root-extraction subset already present in the generic transaction mass_out;
  ! it must never be booked into the water balance a second time.
  type, public :: fmr_root_uptake_attribution_receipt_t
    private
    logical :: initialized = .false.
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: origin_revision_value = -1_int64
    integer(int64) :: committed_revision_value = -1_int64
    real(real64) :: t0_value = 0.0_real64
    real(real64) :: t1_value = 0.0_real64
    real(real64) :: actual_transpiration_amount_value = 0.0_real64
  contains
    procedure, public :: ready => attribution_ready
    procedure, public :: current_lineage_id => attribution_lineage_id
    procedure, public :: origin_revision => attribution_origin_revision
    procedure, public :: committed_revision => attribution_committed_revision
    procedure, public :: origin_interval => attribution_origin_interval
    procedure, public :: actual_transpiration_amount => attribution_actual_transpiration_amount
  end type fmr_root_uptake_attribution_receipt_t

  type, public :: fmr_root_uptake_attribution_record_t
    integer(int64) :: column_id = 0_int64
    integer :: status = FMR_ROOT_ATTRIBUTION_RUNTIME_REJECTED
    type(fmr_root_uptake_attribution_receipt_t) :: receipt
  end type fmr_root_uptake_attribution_record_t

  public :: fmr_run_serialized_root_uptake_attribution

contains

  ! Trusted composition seam.  There is intentionally no public procedure that
  ! accepts an already-created candidate and an independently supplied forcing.
  ! The exact forcing registry used by the physical runtime is retained in this
  ! same call frame and is the only source from which attribution is derived.
  subroutine fmr_run_serialized_root_uptake_attribution(columns, templates, parameter_registry, forcing_registry, &
                                                        state_registry, numerical_config, top_boundary, t0, t1, &
                                                        batch_size, attribution_column_ids, results, diagnostics, &
                                                        aggregate, dispatch_status, attributions, runtime_diagnostics)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_template_t), intent(in) :: templates(:)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameter_registry(:)
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing_registry(:)
    type(kernel_committed_state_t), intent(inout) :: state_registry(:)
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    class(top_boundary_provider_t), target, intent(in) :: top_boundary
    real(real64), intent(in) :: t0, t1
    integer, intent(in) :: batch_size
    integer(int64), intent(in) :: attribution_column_ids(:)
    type(fmr_serialized_column_result_t), allocatable, intent(out) :: results(:)
    type(fmr_column_diagnostics_t), allocatable, intent(out) :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t), intent(out) :: aggregate
    integer, intent(out) :: dispatch_status
    type(fmr_root_uptake_attribution_record_t), allocatable, intent(out) :: attributions(:)
    type(fmr_serialized_batch_diagnostics_t), intent(out), optional :: runtime_diagnostics

    type(fmr_serialized_commit_receipt_record_t), allocatable :: commit_receipts(:)
    type(fmr_serialized_batch_diagnostics_t) :: local_runtime
    integer :: i

    allocate(attributions(size(attribution_column_ids)))
    do i = 1, size(attributions)
      attributions(i) = fmr_root_uptake_attribution_record_t()
      attributions(i)%column_id = attribution_column_ids(i)
    end do

    call fmr_run_serialized_physical_multiswap(columns, templates, parameter_registry, forcing_registry, state_registry, &
         numerical_config, top_boundary, t0, t1, batch_size, results, diagnostics, aggregate, dispatch_status, &
         runtime_diagnostics=local_runtime, receipt_column_ids=attribution_column_ids, commit_receipts=commit_receipts)
    if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime

    if (dispatch_status /= FMR_SERIAL_DISPATCH_OK) then
      do i = 1, size(attributions)
        attributions(i)%status = FMR_ROOT_ATTRIBUTION_RUNTIME_REJECTED
      end do
      return
    end if

    if (.not. allocated(commit_receipts) .or. size(commit_receipts) /= size(attributions)) then
      do i = 1, size(attributions)
        attributions(i)%status = FMR_ROOT_ATTRIBUTION_RUNTIME_REJECTED
      end do
      return
    end if

    do i = 1, size(attributions)
      call materialize_attribution(columns, parameter_registry, forcing_registry, results, &
           commit_receipts(i), attributions(i))
    end do
  end subroutine fmr_run_serialized_root_uptake_attribution

  subroutine materialize_attribution(columns, parameter_registry, forcing_registry, results, commit_record, attribution)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameter_registry(:)
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing_registry(:)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    type(fmr_serialized_commit_receipt_record_t), intent(in) :: commit_record
    type(fmr_root_uptake_attribution_record_t), intent(inout) :: attribution

    integer :: column_index, result_index, forcing_index, parameter_index
    integer(int64) :: lineage_id, origin_revision, committed_revision
    real(real64) :: t0, t1, amount, tolerance, mass_out
    logical :: interval_available

    attribution%receipt = fmr_root_uptake_attribution_receipt_t()
    attribution%status = FMR_ROOT_ATTRIBUTION_NOT_COMMITTED
    if (commit_record%column_id /= attribution%column_id) return
    if (.not. commit_record%receipt%ready()) return

    column_index = find_column_index(columns, attribution%column_id)
    result_index = find_result_index(results, attribution%column_id)
    if (column_index <= 0 .or. result_index <= 0) then
      attribution%status = FMR_ROOT_ATTRIBUTION_PROVENANCE_MISMATCH
      return
    end if
    if (.not. results(result_index)%committed .or. .not. results(result_index)%completed) return

    forcing_index = int(columns(column_index)%forcing_handle)
    parameter_index = int(columns(column_index)%parameter_ref)
    attribution%status = FMR_ROOT_ATTRIBUTION_INVALID_FORCING
    if (forcing_index < 1 .or. forcing_index > size(forcing_registry)) return
    if (parameter_index < 1 .or. parameter_index > size(parameter_registry)) return
    if (.not. allocated(forcing_registry(forcing_index)%root_extraction_sink)) return
    if (size(forcing_registry(forcing_index)%root_extraction_sink) /= parameter_registry(parameter_index)%active_nodes) return
    if (any(.not. ieee_is_finite(forcing_registry(forcing_index)%root_extraction_sink))) return
    if (any(forcing_registry(forcing_index)%root_extraction_sink < 0.0_real64)) return

    call commit_record%receipt%origin_interval(t0, t1, interval_available)
    attribution%status = FMR_ROOT_ATTRIBUTION_PROVENANCE_MISMATCH
    if (.not. interval_available .or. .not. ieee_is_finite(t0) .or. .not. ieee_is_finite(t1) .or. t1 <= t0) return

    lineage_id = commit_record%receipt%current_lineage_id()
    origin_revision = commit_record%receipt%origin_revision()
    committed_revision = commit_record%receipt%committed_revision()
    if (origin_revision < 0_int64 .or. committed_revision /= origin_revision + 1_int64) return
    if (results(result_index)%initial_revision /= origin_revision) return
    if (results(result_index)%final_revision /= committed_revision) return
    if (.not. results(result_index)%final_committed_time_bound) return
    if (.not. same_time_value(results(result_index)%final_committed_time, t1)) return
    if (.not. results(result_index)%mass%complete) return
    if (results(result_index)%mass%origin_lineage_id /= lineage_id) return
    if (results(result_index)%mass%origin_revision /= origin_revision) return
    if (.not. same_time_value(results(result_index)%mass%interval_t0, t0)) return
    if (.not. same_time_value(results(result_index)%mass%interval_t1, t1)) return

    attribution%status = FMR_ROOT_ATTRIBUTION_INVALID_FORCING
    amount = sum(forcing_registry(forcing_index)%root_extraction_sink) * (t1 - t0)
    if (.not. ieee_is_finite(amount) .or. amount < 0.0_real64) return

    ! Root uptake is a named subset of the already-accounted total outflow.
    ! This is a reconciliation check only; no mass field is modified here.
    mass_out = results(result_index)%mass%total_out
    tolerance = 128.0_real64 * epsilon(1.0_real64) * max(1.0_real64, abs(amount), abs(mass_out))
    attribution%status = FMR_ROOT_ATTRIBUTION_MASS_SUBSET_MISMATCH
    if (.not. ieee_is_finite(mass_out) .or. amount > mass_out + tolerance) return

    attribution%receipt%lineage_id = lineage_id
    attribution%receipt%origin_revision_value = origin_revision
    attribution%receipt%committed_revision_value = committed_revision
    attribution%receipt%t0_value = t0
    attribution%receipt%t1_value = t1
    attribution%receipt%actual_transpiration_amount_value = amount
    attribution%receipt%initialized = .true.
    attribution%status = FMR_ROOT_ATTRIBUTION_OK
  end subroutine materialize_attribution

  integer function find_column_index(columns, column_id) result(index)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    integer(int64), intent(in) :: column_id
    integer :: i
    index = 0
    do i = 1, size(columns)
      if (columns(i)%column_id == column_id) then
        index = i
        return
      end if
    end do
  end function find_column_index

  integer function find_result_index(results, column_id) result(index)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    integer(int64), intent(in) :: column_id
    integer :: i
    index = 0
    do i = 1, size(results)
      if (results(i)%column_id == column_id) then
        index = i
        return
      end if
    end do
  end function find_result_index

  pure logical function attribution_ready(self) result(ready)
    class(fmr_root_uptake_attribution_receipt_t), intent(in) :: self
    ready = self%initialized .and. self%lineage_id > 0_int64 .and. self%origin_revision_value >= 0_int64 .and. &
         self%committed_revision_value == self%origin_revision_value + 1_int64 .and. &
         ieee_is_finite(self%t0_value) .and. ieee_is_finite(self%t1_value) .and. self%t1_value > self%t0_value .and. &
         ieee_is_finite(self%actual_transpiration_amount_value) .and. self%actual_transpiration_amount_value >= 0.0_real64
  end function attribution_ready

  pure integer(int64) function attribution_lineage_id(self) result(value)
    class(fmr_root_uptake_attribution_receipt_t), intent(in) :: self
    value = self%lineage_id
  end function attribution_lineage_id

  pure integer(int64) function attribution_origin_revision(self) result(value)
    class(fmr_root_uptake_attribution_receipt_t), intent(in) :: self
    value = self%origin_revision_value
  end function attribution_origin_revision

  pure integer(int64) function attribution_committed_revision(self) result(value)
    class(fmr_root_uptake_attribution_receipt_t), intent(in) :: self
    value = self%committed_revision_value
  end function attribution_committed_revision

  subroutine attribution_origin_interval(self, t0, t1, available)
    class(fmr_root_uptake_attribution_receipt_t), intent(in) :: self
    real(real64), intent(out) :: t0, t1
    logical, intent(out) :: available
    available = self%ready()
    if (available) then
      t0 = self%t0_value
      t1 = self%t1_value
    else
      t0 = 0.0_real64
      t1 = 0.0_real64
    end if
  end subroutine attribution_origin_interval

  pure real(real64) function attribution_actual_transpiration_amount(self) result(value)
    class(fmr_root_uptake_attribution_receipt_t), intent(in) :: self
    if (self%ready()) then
      value = self%actual_transpiration_amount_value
    else
      value = 0.0_real64
    end if
  end function attribution_actual_transpiration_amount

  pure logical function same_time_value(a, b) result(matches)
    real(real64), intent(in) :: a, b
    real(real64) :: scale
    if (.not. ieee_is_finite(a) .or. .not. ieee_is_finite(b)) then
      matches = .false.
      return
    end if
    scale = max(1.0_real64, abs(a), abs(b))
    matches = abs(a-b) <= 64.0_real64 * epsilon(1.0_real64) * scale
  end function same_time_value

end module mod_fmr_root_uptake_attribution_receipt
