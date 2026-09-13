module mod_fmr_accepted_water_thermal_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_soil_water_solver_contract, only: top_boundary_provider_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_serialized_commit_receipt_record_t, &
       fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK, FMR_SERIAL_DISPATCH_INVALID_REQUEST
  implicit none
  private

  integer, parameter, public :: EB_I10R_BINDING_OK = 0
  integer, parameter, public :: EB_I10R_BINDING_INVALID_REQUEST = 1
  integer, parameter, public :: EB_I10R_BINDING_INVALID_REGISTRY = 2
  integer, parameter, public :: EB_I10R_BINDING_THERMAL_TOPOLOGY_REQUIRED = 3
  integer, parameter, public :: EB_I10R_BINDING_PHYSICAL_DISPATCH_REJECTED = 4

  ! Accepted transaction metadata only.  This is deliberately not a detached
  ! capability that can authorize an arbitrary candidate or physical payload.
  ! It can only be produced by the atomic runtime composition below after the
  ! existing F-MR18 receipt has been emitted for the same internal candidate
  ! that the serialized runtime committed.
  type, public :: accepted_water_thermal_transaction_t
    private
    logical :: initialized = .false.
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: origin_revision_value = -1_int64
    integer(int64) :: committed_revision_value = -1_int64
    real(real64) :: t0_value = 0.0_real64
    real(real64) :: t1_value = 0.0_real64
  contains
    procedure, public :: ready => accepted_transaction_ready
    procedure, public :: current_lineage_id => accepted_transaction_lineage
    procedure, public :: origin_revision => accepted_transaction_origin_revision
    procedure, public :: committed_revision => accepted_transaction_committed_revision
    procedure, public :: origin_interval => accepted_transaction_interval
  end type accepted_water_thermal_transaction_t

  type, public :: fmr_accepted_water_thermal_record_t
    integer(int64) :: column_id = 0_int64
    type(accepted_water_thermal_transaction_t) :: transaction
  end type fmr_accepted_water_thermal_record_t

  public :: fmr_run_serialized_multiswap_with_water_thermal_binding

contains

  subroutine fmr_run_serialized_multiswap_with_water_thermal_binding(columns, templates, parameter_registry, &
       forcing_registry, state_registry, numerical_config, top_boundary, t0, t1, batch_size, thermal_column_ids, &
       results, diagnostics, aggregate, dispatch_status, binding_status, accepted_records, runtime_diagnostics)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_template_t), intent(in) :: templates(:)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameter_registry(:)
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing_registry(:)
    type(kernel_committed_state_t), intent(inout) :: state_registry(:)
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    class(top_boundary_provider_t), target, intent(in) :: top_boundary
    real(real64), intent(in) :: t0, t1
    integer, intent(in) :: batch_size
    integer(int64), intent(in) :: thermal_column_ids(:)
    type(fmr_serialized_column_result_t), allocatable, intent(out) :: results(:)
    type(fmr_column_diagnostics_t), allocatable, intent(out) :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t), intent(out) :: aggregate
    integer, intent(out) :: dispatch_status
    integer, intent(out) :: binding_status
    type(fmr_accepted_water_thermal_record_t), allocatable, intent(out) :: accepted_records(:)
    type(fmr_serialized_batch_diagnostics_t), intent(out), optional :: runtime_diagnostics

    type(fmr_serialized_commit_receipt_record_t), allocatable :: receipts(:)
    type(fmr_serialized_batch_diagnostics_t) :: local_runtime
    integer, allocatable :: column_index(:), state_index(:)
    integer :: i, status

    binding_status = EB_I10R_BINDING_OK
    allocate(accepted_records(0))

    if (size(thermal_column_ids) == 0) then
      call fmr_run_serialized_physical_multiswap(columns, templates, parameter_registry, forcing_registry, &
           state_registry, numerical_config, top_boundary, t0, t1, batch_size, results, diagnostics, aggregate, &
           dispatch_status, local_runtime)
      if (dispatch_status /= FMR_SERIAL_DISPATCH_OK) binding_status = EB_I10R_BINDING_PHYSICAL_DISPATCH_REJECTED
      if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
      return
    end if

    call prevalidate_binding_request(columns, templates, parameter_registry, forcing_registry, state_registry, &
         thermal_column_ids, column_index, state_index, status)
    if (status /= EB_I10R_BINDING_OK) then
      binding_status = status
      call reject_before_physical(columns, t0, t1, results, diagnostics, aggregate, dispatch_status, local_runtime)
      if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
      return
    end if

    deallocate(accepted_records)
    allocate(accepted_records(size(thermal_column_ids)))
    do i = 1, size(thermal_column_ids)
      accepted_records(i)%column_id = thermal_column_ids(i)
    end do

    ! This single call owns trial materialization, F-KT commit and F-MR18
    ! receipt publication.  EB-I10R never accepts an external candidate or
    ! external receipt, which removes the same-origin/same-interval alias that
    ! existed in the superseded post-hoc token design.
    call fmr_run_serialized_physical_multiswap(columns, templates, parameter_registry, forcing_registry, &
         state_registry, numerical_config, top_boundary, t0, t1, batch_size, results, diagnostics, aggregate, &
         dispatch_status, local_runtime, receipt_column_ids=thermal_column_ids, commit_receipts=receipts)
    if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
    if (dispatch_status /= FMR_SERIAL_DISPATCH_OK) then
      binding_status = EB_I10R_BINDING_PHYSICAL_DISPATCH_REJECTED
      return
    end if

    if (size(receipts) /= size(thermal_column_ids)) &
         error stop 'EB-I10R: sparse receipt cardinality changed after prevalidation'

    do i = 1, size(thermal_column_ids)
      if (receipts(i)%column_id /= thermal_column_ids(i)) &
           error stop 'EB-I10R: sparse receipt association changed after prevalidation'
      if (.not. receipts(i)%receipt%ready()) cycle

      call assert_postcommit_identity(columns(column_index(i)), state_registry(state_index(i)), &
           result_for_column(results, thermal_column_ids(i)), receipts(i), t0, t1)
      call materialize_accepted_transaction(receipts(i), accepted_records(i)%transaction)
    end do
  end subroutine fmr_run_serialized_multiswap_with_water_thermal_binding

  subroutine prevalidate_binding_request(columns, templates, parameters, forcings, states, thermal_ids, &
       column_index, state_index, status)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_template_t), intent(in) :: templates(:)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters(:)
    type(fmr_b110_physical_forcing_t), intent(in) :: forcings(:)
    type(kernel_committed_state_t), intent(in) :: states(:)
    integer(int64), intent(in) :: thermal_ids(:)
    integer, allocatable, intent(out) :: column_index(:), state_index(:)
    integer, intent(out) :: status
    integer :: i, cidx, tidx, pidx, fidx, sidx

    status = EB_I10R_BINDING_INVALID_REQUEST
    if (.not. unique_positive_ids(thermal_ids)) return

    allocate(column_index(size(thermal_ids)), state_index(size(thermal_ids)))
    do i = 1, size(thermal_ids)
      cidx = find_unique_column_index(thermal_ids(i), columns)
      if (cidx <= 0) then
        status = EB_I10R_BINDING_INVALID_REGISTRY
        return
      end if
      tidx = find_unique_template_index(columns(cidx)%template_id, templates)
      if (tidx <= 0) then
        status = EB_I10R_BINDING_INVALID_REGISTRY
        return
      end if
      if (columns(cidx)%parameter_ref < 1_int64 .or. columns(cidx)%parameter_ref > int(size(parameters), int64) .or. &
          columns(cidx)%forcing_handle < 1_int64 .or. columns(cidx)%forcing_handle > int(size(forcings), int64) .or. &
          columns(cidx)%state_handle < 1_int64 .or. columns(cidx)%state_handle > int(size(states), int64)) then
        status = EB_I10R_BINDING_INVALID_REGISTRY
        return
      end if
      pidx = int(columns(cidx)%parameter_ref)
      fidx = int(columns(cidx)%forcing_handle)
      sidx = int(columns(cidx)%state_handle)
      if (.not. states(sidx)%ready()) then
        status = EB_I10R_BINDING_INVALID_REGISTRY
        return
      end if
      if (templates(tidx)%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE .or. &
          .not. parameters(pidx)%soil_temperature_active .or. .not. allocated(parameters(pidx)%soil_temperature) .or. &
          .not. allocated(forcings(fidx)%soil_temperature)) then
        status = EB_I10R_BINDING_THERMAL_TOPOLOGY_REQUIRED
        return
      end if
      column_index(i) = cidx
      state_index(i) = sidx
    end do
    status = EB_I10R_BINDING_OK
  end subroutine prevalidate_binding_request

  subroutine materialize_accepted_transaction(record, accepted)
    type(fmr_serialized_commit_receipt_record_t), intent(in) :: record
    type(accepted_water_thermal_transaction_t), intent(out) :: accepted
    real(real64) :: rt0, rt1
    logical :: available

    accepted = accepted_water_thermal_transaction_t()
    if (.not. record%receipt%ready()) return
    call record%receipt%origin_interval(rt0, rt1, available)
    if (.not. available) return
    accepted%lineage_id = record%receipt%current_lineage_id()
    accepted%origin_revision_value = record%receipt%origin_revision()
    accepted%committed_revision_value = record%receipt%committed_revision()
    accepted%t0_value = rt0
    accepted%t1_value = rt1
    accepted%initialized = .true.
  end subroutine materialize_accepted_transaction

  subroutine assert_postcommit_identity(column, state, result, receipt_record, requested_t0, requested_t1)
    type(fmr_logical_column_t), intent(in) :: column
    type(kernel_committed_state_t), intent(in) :: state
    type(fmr_serialized_column_result_t), intent(in) :: result
    type(fmr_serialized_commit_receipt_record_t), intent(in) :: receipt_record
    real(real64), intent(in) :: requested_t0, requested_t1
    real(real64) :: rt0, rt1, committed_time
    logical :: interval_available, time_available

    if (.not. result%completed .or. .not. result%committed) &
         error stop 'EB-I10R: ready accepted receipt without committed column result'
    if (result%column_id /= column%column_id .or. receipt_record%column_id /= column%column_id) &
         error stop 'EB-I10R: postcommit column association mismatch'
    if (receipt_record%receipt%current_lineage_id() /= state%current_lineage_id()) &
         error stop 'EB-I10R: postcommit lineage mismatch'
    if (result%initial_revision /= receipt_record%receipt%origin_revision()) &
         error stop 'EB-I10R: result/receipt origin revision mismatch'
    if (result%final_revision /= receipt_record%receipt%committed_revision()) &
         error stop 'EB-I10R: result/receipt committed revision mismatch'
    if (state%current_revision() /= receipt_record%receipt%committed_revision()) &
         error stop 'EB-I10R: state/receipt committed revision mismatch'

    call receipt_record%receipt%origin_interval(rt0, rt1, interval_available)
    if (.not. interval_available .or. .not. same_real_bits(rt0, requested_t0) .or. &
        .not. same_real_bits(rt1, requested_t1)) &
         error stop 'EB-I10R: accepted receipt interval mismatch'
    call state%current_time(committed_time, time_available)
    if (.not. time_available .or. .not. same_real_bits(committed_time, rt1)) &
         error stop 'EB-I10R: committed state time does not match accepted receipt'
  end subroutine assert_postcommit_identity

  function result_for_column(results, column_id) result(found)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    integer(int64), intent(in) :: column_id
    type(fmr_serialized_column_result_t) :: found
    integer :: i, matches

    found = fmr_serialized_column_result_t()
    matches = 0
    do i = 1, size(results)
      if (results(i)%column_id == column_id) then
        matches = matches + 1
        found = results(i)
      end if
    end do
    if (matches /= 1) error stop 'EB-I10R: result association is not unique'
  end function result_for_column

  subroutine reject_before_physical(columns, t0, t1, results, diagnostics, aggregate, dispatch_status, runtime)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    real(real64), intent(in) :: t0, t1
    type(fmr_serialized_column_result_t), allocatable, intent(out) :: results(:)
    type(fmr_column_diagnostics_t), allocatable, intent(out) :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t), intent(out) :: aggregate
    integer, intent(out) :: dispatch_status
    type(fmr_serialized_batch_diagnostics_t), intent(out) :: runtime
    integer :: i

    allocate(results(size(columns)), diagnostics(size(columns)))
    aggregate = fmr_aggregate_diagnostics_t()
    aggregate%columns = size(columns)
    aggregate%workers = 1
    runtime = fmr_serialized_batch_diagnostics_t()
    runtime%number_requested = size(columns)
    runtime%number_rejected = size(columns)
    runtime%effective_t0 = t0
    runtime%effective_t1 = t1
    do i = 1, size(columns)
      results(i)%column_id = columns(i)%column_id
      results(i)%requested_t0 = t0
      results(i)%requested_t1 = t1
      diagnostics(i)%column_id = columns(i)%column_id
      diagnostics(i)%template_id = columns(i)%template_id
      diagnostics(i)%backend = columns(i)%backend_id
      diagnostics(i)%execution_class = columns(i)%execution_class
      diagnostics(i)%rejected = 1
      diagnostics(i)%failure_classification = 'EB_I10R_BINDING_REJECTED'
    end do
    dispatch_status = FMR_SERIAL_DISPATCH_INVALID_REQUEST
  end subroutine reject_before_physical

  logical function unique_positive_ids(ids) result(valid)
    integer(int64), intent(in) :: ids(:)
    integer :: i, j

    valid = .false.
    do i = 1, size(ids)
      if (ids(i) <= 0_int64) return
      do j = i + 1, size(ids)
        if (ids(i) == ids(j)) return
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

  integer function find_unique_template_index(template_id, templates) result(index)
    integer(int64), intent(in) :: template_id
    type(fmr_template_t), intent(in) :: templates(:)
    integer :: i, matches

    index = 0
    matches = 0
    do i = 1, size(templates)
      if (templates(i)%template_id == template_id) then
        matches = matches + 1
        index = i
      end if
    end do
    if (matches /= 1) index = 0
  end function find_unique_template_index

  pure elemental logical function same_real_bits(a, b) result(same)
    real(real64), intent(in) :: a, b
    same = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function same_real_bits

  pure logical function accepted_transaction_ready(self) result(ready)
    class(accepted_water_thermal_transaction_t), intent(in) :: self
    ready = self%initialized .and. self%lineage_id > 0_int64 .and. &
         self%origin_revision_value >= 0_int64 .and. &
         self%committed_revision_value == self%origin_revision_value + 1_int64 .and. &
         self%t1_value > self%t0_value
  end function accepted_transaction_ready

  pure integer(int64) function accepted_transaction_lineage(self) result(value)
    class(accepted_water_thermal_transaction_t), intent(in) :: self
    value = self%lineage_id
  end function accepted_transaction_lineage

  pure integer(int64) function accepted_transaction_origin_revision(self) result(value)
    class(accepted_water_thermal_transaction_t), intent(in) :: self
    value = self%origin_revision_value
  end function accepted_transaction_origin_revision

  pure integer(int64) function accepted_transaction_committed_revision(self) result(value)
    class(accepted_water_thermal_transaction_t), intent(in) :: self
    value = self%committed_revision_value
  end function accepted_transaction_committed_revision

  subroutine accepted_transaction_interval(self, t0, t1, available)
    class(accepted_water_thermal_transaction_t), intent(in) :: self
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
  end subroutine accepted_transaction_interval

end module mod_fmr_accepted_water_thermal_binding
