program test_fmr18_multiswap_receipt_integration
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_soil_water_solver_contract, only: top_boundary_provider_t, soil_water_boundary_conditions_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr18_test_physical_state_t, &
       fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_commit_receipt_record_t, fmr_run_serialized_physical_multiswap, &
       FMR_SERIAL_DISPATCH_OK, FMR_SERIAL_DISPATCH_RECEIPT_REQUEST_REJECTED
  implicit none

  real(real64), parameter :: t0 = 42.125_real64
  real(real64), parameter :: t1 = 42.625_real64
  integer, parameter :: ncol = 4
  integer(int64), parameter :: receipt_ids(3) = [18001_int64, 18003_int64, 18004_int64]

  type, extends(top_boundary_provider_t) :: dummy_top_provider_t
  contains
    procedure :: evaluate => dummy_top_evaluate
  end type dummy_top_provider_t

  type(fmr_serialized_column_result_t), allocatable :: a_results(:), b_results(:), a2_results(:), plain_results(:)
  type(fmr_column_diagnostics_t), allocatable :: a_diag(:), b_diag(:), a2_diag(:), plain_diag(:)
  type(fmr_serialized_commit_receipt_record_t), allocatable :: a_receipts(:), b_receipts(:), a2_receipts(:)
  type(kernel_committed_state_t), allocatable :: a_states(:), b_states(:), a2_states(:), plain_states(:)
  type(fmr_aggregate_diagnostics_t) :: a_aggregate, b_aggregate, a2_aggregate, plain_aggregate
  integer :: status

  call run_case(1, .false., .true., a_results, a_diag, a_aggregate, a_states, a_receipts, status)
  call require(status == FMR_SERIAL_DISPATCH_OK, 'A dispatch')
  call validate_receipt_case(a_results, a_states, a_receipts)

  call run_case(4, .true., .true., b_results, b_diag, b_aggregate, b_states, b_receipts, status)
  call require(status == FMR_SERIAL_DISPATCH_OK, 'B dispatch')
  call validate_receipt_case(b_results, b_states, b_receipts)
  call require(result_sets_equal_by_id(a_results, b_results), 'batch/input-order result identity')
  call require(state_sets_equal(a_states, b_states), 'batch/input-order committed-state identity')
  call require(receipt_sets_equal(a_receipts, b_receipts), 'batch/input-order receipt identity')
  print '(a)', 'FMR18_GATE_C_BATCH_AND_INPUT_ORDER_RECEIPT_IDENTITY=PASS'

  call run_case(1, .false., .true., a2_results, a2_diag, a2_aggregate, a2_states, a2_receipts, status)
  call require(status == FMR_SERIAL_DISPATCH_OK, 'A2 dispatch')
  call require(result_sets_equal_by_id(a_results, a2_results), 'A-B-A result identity')
  call require(state_sets_equal(a_states, a2_states), 'A-B-A state identity')
  call require(receipt_sets_equal(a_receipts, a2_receipts), 'A-B-A receipt identity')
  print '(a)', 'FMR18_GATE_C_A_B_A_RECEIPT_REPLAY=PASS'

  call run_case(2, .false., .false., plain_results, plain_diag, plain_aggregate, plain_states, status=status)
  call require(status == FMR_SERIAL_DISPATCH_OK, 'plain dispatch')
  call require(result_sets_equal_by_id(a_results, plain_results), 'receipt versus no-receipt result identity')
  call require(state_sets_equal(a_states, plain_states), 'receipt versus no-receipt state identity')
  call require(same_bits(a_aggregate%aggregate_unrounded_mass_residual, &
       plain_aggregate%aggregate_unrounded_mass_residual), 'receipt versus no-receipt aggregate mass identity')
  print '(a)', 'FMR18_GATE_C_LEGACY_NO_RECEIPT_BEHAVIOR_IDENTITY=PASS'

  call validate_invalid_requests()
  print '(a)', 'FMR18_GATE_C_INVALID_REQUESTS_PRECOMMIT=PASS'

  call require(a_receipts(1)%receipt%ready() .and. a_receipts(2)%receipt%ready(), 'accepted receipts ready')
  call require(.not. a_receipts(3)%receipt%ready(), 'rejected requested column has no receipt')
  call require(a_receipts(1)%column_id == receipt_ids(1) .and. &
       a_receipts(2)%column_id == receipt_ids(2) .and. &
       a_receipts(3)%column_id == receipt_ids(3), 'self-describing sparse receipt records')
  print '(a)', 'FMR18_GATE_C_ACCEPTED_EXACTLY_ONE_REJECTED_NONE=PASS'
  print '(a)', 'FMR18_GATE_C_SPARSE_MULTISWAP_RECEIPT_TEST PASS'

contains

  subroutine run_case(batch_size, reverse_order, with_receipts, results, diagnostics, aggregate, states, receipts, status)
    integer, intent(in) :: batch_size
    logical, intent(in) :: reverse_order, with_receipts
    type(fmr_serialized_column_result_t), allocatable, intent(out) :: results(:)
    type(fmr_column_diagnostics_t), allocatable, intent(out) :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t), intent(out) :: aggregate
    type(kernel_committed_state_t), allocatable, intent(out) :: states(:)
    type(fmr_serialized_commit_receipt_record_t), allocatable, intent(out), optional :: receipts(:)
    integer, intent(out) :: status

    type(fmr_logical_column_t) :: columns(ncol), tmp
    type(fmr_template_t) :: templates(1)
    type(fmr_b110_physical_parameters_t) :: parameters(2)
    type(fmr_b110_physical_forcing_t) :: forcings(ncol)
    type(canonical_numerical_config_t) :: config
    type(dummy_top_provider_t), target :: top
    integer :: i, left, right

    call configure_case(columns, templates, parameters, forcings, states, config)
    if (reverse_order) then
      do left = 1, ncol/2
        right = ncol + 1 - left
        tmp = columns(left)
        columns(left) = columns(right)
        columns(right) = tmp
      end do
    end if

    if (with_receipts) then
      call require(present(receipts), 'receipt output present for receipt case')
      call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, states, config, top, &
           t0, t1, batch_size, results, diagnostics, aggregate, status, &
           receipt_column_ids=receipt_ids, commit_receipts=receipts)
    else
      call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, states, config, top, &
           t0, t1, batch_size, results, diagnostics, aggregate, status)
    end if
  end subroutine run_case

  subroutine configure_case(columns, templates, parameters, forcings, states, config)
    type(fmr_logical_column_t), intent(out) :: columns(ncol)
    type(fmr_template_t), intent(out) :: templates(1)
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters(2)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcings(ncol)
    type(kernel_committed_state_t), allocatable, intent(out) :: states(:)
    type(canonical_numerical_config_t), intent(out) :: config
    integer :: i

    templates(1)%template_id = 1801_int64
    templates(1)%physics_topology_id = 1802_int64
    templates(1)%vertical_layout_id = 1803_int64
    templates(1)%state_layout_id = 1804_int64
    templates(1)%solver_interface_id = 1805_int64
    templates(1)%optional_state_layout_id = 0_int64
    templates(1)%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    parameters(1)%admitted = .true.
    parameters(1)%transfer_rate = 0.2_real64
    parameters(2) = parameters(1)
    parameters(2)%admitted = .false.

    allocate(states(ncol))
    do i = 1, ncol
      columns(i)%column_id = 18000_int64 + int(i, int64)
      columns(i)%template_id = templates(1)%template_id
      columns(i)%parameter_ref = 1_int64
      columns(i)%state_handle = int(i, int64)
      columns(i)%forcing_handle = int(i, int64)
      columns(i)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
      forcings(i)%scale = 1.0_real64 + 0.1_real64*real(i, real64)
      call initialize_state(states(i), columns(i)%column_id)
    end do
    columns(4)%parameter_ref = 2_int64

    config%transaction%temporal_tolerance = 0.0_real64
    config%transaction%mass_tolerance = 1.0e-12_real64
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 2
    config%transaction%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
    config%max_committed_substeps = 8
    config%progress_tolerance = 0.0_real64
  end subroutine configure_case

  subroutine initialize_state(state, lineage_id)
    type(kernel_committed_state_t), intent(out) :: state
    integer(int64), intent(in) :: lineage_id
    class(transaction_state_t), allocatable :: physical
    logical :: ok

    allocate(fmr18_test_physical_state_t :: physical)
    select type (physical)
    type is (fmr18_test_physical_state_t)
      physical%storage_value = 1.0_real64
    end select
    call state%initialize(lineage_id, physical, ok, t0)
    call require(ok, 'initialize committed state')
  end subroutine initialize_state

  subroutine validate_receipt_case(results, states, receipts)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    type(kernel_committed_state_t), intent(in) :: states(:)
    type(fmr_serialized_commit_receipt_record_t), intent(in) :: receipts(:)
    integer :: i

    call require(size(receipts) == size(receipt_ids), 'sparse receipt cardinality')
    do i = 1, 3
      if (i /= 4) call require(result_for_id(results, 18000_int64+int(i,int64))%committed, 'accepted column committed')
    end do
    call require(.not. result_for_id(results, 18004_int64)%committed, 'rejected column not committed')
    call require(states(1)%current_revision() == 1_int64 .and. states(2)%current_revision() == 1_int64 .and. &
         states(3)%current_revision() == 1_int64 .and. states(4)%current_revision() == 0_int64, 'state revisions')
    call validate_receipt(receipts(1), 18001_int64)
    call validate_receipt(receipts(2), 18003_int64)
    call require(receipts(3)%column_id == 18004_int64 .and. .not. receipts(3)%receipt%ready(), &
         'rejected sparse receipt stays unavailable')
  end subroutine validate_receipt_case

  subroutine validate_receipt(record, expected_id)
    type(fmr_serialized_commit_receipt_record_t), intent(in) :: record
    integer(int64), intent(in) :: expected_id
    real(real64) :: rt0, rt1
    logical :: available

    call require(record%column_id == expected_id, 'receipt record id')
    call require(record%receipt%ready(), 'receipt ready')
    call require(record%receipt%current_lineage_id() == expected_id, 'receipt lineage')
    call require(record%receipt%origin_revision() == 0_int64, 'receipt origin revision')
    call require(record%receipt%committed_revision() == 1_int64, 'receipt committed revision')
    call record%receipt%origin_interval(rt0, rt1, available)
    call require(available .and. same_bits(rt0, t0) .and. same_bits(rt1, t1), 'receipt interval')
  end subroutine validate_receipt

  subroutine validate_invalid_requests()
    type(fmr_logical_column_t) :: columns(ncol)
    type(fmr_template_t) :: templates(1)
    type(fmr_b110_physical_parameters_t) :: parameters(2)
    type(fmr_b110_physical_forcing_t) :: forcings(ncol)
    type(kernel_committed_state_t), allocatable :: states(:)
    type(canonical_numerical_config_t) :: config
    type(dummy_top_provider_t), target :: top
    type(fmr_serialized_column_result_t), allocatable :: results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    type(fmr_serialized_commit_receipt_record_t), allocatable :: receipts(:)
    integer(int64) :: duplicate_ids(2), unknown_ids(1)
    integer :: dispatch, i

    duplicate_ids = [18001_int64, 18001_int64]
    call configure_case(columns, templates, parameters, forcings, states, config)
    call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, states, config, top, &
         t0, t1, 2, results, diagnostics, aggregate, dispatch, &
         receipt_column_ids=duplicate_ids, commit_receipts=receipts)
    call require(dispatch == FMR_SERIAL_DISPATCH_RECEIPT_REQUEST_REJECTED, 'duplicate receipt ids rejected')
    call require(all([(states(i)%current_revision() == 0_int64, i=1,ncol)]), 'duplicate request precommit')

    unknown_ids = [19999_int64]
    call configure_case(columns, templates, parameters, forcings, states, config)
    call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, states, config, top, &
         t0, t1, 2, results, diagnostics, aggregate, dispatch, &
         receipt_column_ids=unknown_ids, commit_receipts=receipts)
    call require(dispatch == FMR_SERIAL_DISPATCH_RECEIPT_REQUEST_REJECTED, 'unknown receipt id rejected')
    call require(all([(states(i)%current_revision() == 0_int64, i=1,ncol)]), 'unknown request precommit')

    call configure_case(columns, templates, parameters, forcings, states, config)
    call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, states, config, top, &
         t0, t1, 2, results, diagnostics, aggregate, dispatch, receipt_column_ids=unknown_ids)
    call require(dispatch == FMR_SERIAL_DISPATCH_RECEIPT_REQUEST_REJECTED, 'unpaired ids rejected')
    call require(all([(states(i)%current_revision() == 0_int64, i=1,ncol)]), 'unpaired ids precommit')

    call configure_case(columns, templates, parameters, forcings, states, config)
    call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, states, config, top, &
         t0, t1, 2, results, diagnostics, aggregate, dispatch, commit_receipts=receipts)
    call require(dispatch == FMR_SERIAL_DISPATCH_RECEIPT_REQUEST_REJECTED, 'unpaired output rejected')
    call require(allocated(receipts) .and. size(receipts) == 0, 'unpaired output remains empty')
    call require(all([(states(i)%current_revision() == 0_int64, i=1,ncol)]), 'unpaired output precommit')
  end subroutine validate_invalid_requests

  logical function result_sets_equal_by_id(left, right) result(equal)
    type(fmr_serialized_column_result_t), intent(in) :: left(:), right(:)
    integer :: i
    type(fmr_serialized_column_result_t) :: r

    equal = size(left) == size(right)
    if (.not. equal) return
    do i = 1, size(left)
      r = result_for_id(right, left(i)%column_id)
      if (.not. result_equal(left(i), r)) then
        equal = .false.
        return
      end if
    end do
  end function result_sets_equal_by_id

  logical function result_equal(a, b) result(equal)
    type(fmr_serialized_column_result_t), intent(in) :: a, b
    equal = a%column_id == b%column_id .and. a%kernel_status == b%kernel_status .and. &
         a%commit_status == b%commit_status .and. a%completed .eqv. b%completed .and. &
         a%committed .eqv. b%committed .and. a%initial_revision == b%initial_revision .and. &
         a%final_revision == b%final_revision .and. &
         same_bits(a%final_committed_time, b%final_committed_time) .and. &
         a%mass%complete .eqv. b%mass%complete .and. &
         a%mass%missing_contribution_mask == b%mass%missing_contribution_mask .and. &
         same_bits(a%mass%residual, b%mass%residual)
  end function result_equal

  logical function state_sets_equal(left, right) result(equal)
    type(kernel_committed_state_t), intent(in) :: left(:), right(:)
    integer :: i
    equal = size(left) == size(right)
    if (.not. equal) return
    do i = 1, size(left)
      if (left(i)%current_lineage_id() /= right(i)%current_lineage_id() .or. &
          left(i)%current_revision() /= right(i)%current_revision() .or. &
          .not. same_bits(state_storage(left(i)), state_storage(right(i)))) then
        equal = .false.
        return
      end if
    end do
  end function state_sets_equal

  real(real64) function state_storage(state) result(value)
    type(kernel_committed_state_t), intent(in) :: state
    class(transaction_state_t), allocatable :: copy
    logical :: available
    call state%snapshot(copy, available)
    call require(available, 'state snapshot available')
    select type (copy)
    type is (fmr18_test_physical_state_t)
      value = copy%storage_value
    class default
      error stop 'F-MR18 test unexpected state snapshot type'
    end select
  end function state_storage

  logical function receipt_sets_equal(left, right) result(equal)
    type(fmr_serialized_commit_receipt_record_t), intent(in) :: left(:), right(:)
    integer :: i
    equal = size(left) == size(right)
    if (.not. equal) return
    do i = 1, size(left)
      if (left(i)%column_id /= right(i)%column_id) then
        equal = .false.
        return
      end if
      if (left(i)%receipt%ready() .neqv. right(i)%receipt%ready()) then
        equal = .false.
        return
      end if
      if (left(i)%receipt%ready()) then
        if (left(i)%receipt%current_lineage_id() /= right(i)%receipt%current_lineage_id() .or. &
            left(i)%receipt%origin_revision() /= right(i)%receipt%origin_revision() .or. &
            left(i)%receipt%committed_revision() /= right(i)%receipt%committed_revision()) then
          equal = .false.
          return
        end if
        if (.not. receipt_intervals_equal(left(i)%receipt, right(i)%receipt)) then
          equal = .false.
          return
        end if
      end if
    end do
  end function receipt_sets_equal

  logical function receipt_intervals_equal(a, b) result(equal)
    use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t
    type(fmr_accepted_commit_receipt_t), intent(in) :: a, b
    real(real64) :: a0, a1, b0, b1
    logical :: aa, ba
    call a%origin_interval(a0, a1, aa)
    call b%origin_interval(b0, b1, ba)
    equal = aa .eqv. ba
    if (aa .and. ba) equal = equal .and. same_bits(a0,b0) .and. same_bits(a1,b1)
  end function receipt_intervals_equal

  function result_for_id(results, id) result(value)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    integer(int64), intent(in) :: id
    type(fmr_serialized_column_result_t) :: value
    integer :: i
    value = fmr_serialized_column_result_t()
    do i = 1, size(results)
      if (results(i)%column_id == id) then
        value = results(i)
        return
      end if
    end do
    error stop 'F-MR18 test result id not found'
  end function result_for_id

  subroutine dummy_top_evaluate(self, pressure_head_top, water_content_top, requested, actual_top_flux, surface_head, runoff_flux)
    class(dummy_top_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head_top, water_content_top
    type(soil_water_boundary_conditions_t), intent(in) :: requested
    real(real64), intent(out) :: actual_top_flux, surface_head, runoff_flux
    if (.not. same_type_as(self,self) .or. pressure_head_top /= pressure_head_top .or. &
        water_content_top /= water_content_top) error stop 'F-MR18 dummy top invalid input'
    actual_top_flux = requested%top_flux
    surface_head = 0.0_real64
    runoff_flux = 0.0_real64
  end subroutine dummy_top_evaluate

  pure logical function same_bits(a, b) result(equal)
    real(real64), intent(in) :: a, b
    integer(int64) :: ai, bi
    ai = transfer(a, ai)
    bi = transfer(b, bi)
    equal = ai == bi
  end function same_bits

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,A)') 'FAIL ', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fmr18_multiswap_receipt_integration
