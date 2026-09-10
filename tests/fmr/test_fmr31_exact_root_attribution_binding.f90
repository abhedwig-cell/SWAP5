program test_fmr31_exact_root_attribution_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_soil_water_solver_contract, only: top_boundary_provider_t, soil_water_boundary_conditions_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr31_test_physical_state_t, &
       fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK
  implicit none

  integer, parameter :: ncol = 6
  real(real64), parameter :: t0 = 731.3125_real64
  real(real64), parameter :: t1 = 732.84375_real64

  type, extends(top_boundary_provider_t) :: dummy_top_provider_t
  contains
    procedure :: evaluate => dummy_top_evaluate
  end type dummy_top_provider_t

  type(fmr_serialized_column_result_t), allocatable :: a_results(:), b_results(:), a2_results(:)
  type(fmr_column_diagnostics_t), allocatable :: a_diag(:), b_diag(:), a2_diag(:)
  type(fmr_aggregate_diagnostics_t) :: a_aggregate, b_aggregate, a2_aggregate
  type(kernel_committed_state_t), allocatable :: a_states(:), b_states(:), a2_states(:)
  integer :: status

  call run_case(1, .false., a_results, a_diag, a_aggregate, a_states, status)
  call require(status == FMR_SERIAL_DISPATCH_OK, 'A dispatch')
  call validate_case(a_results, a_states)

  call run_case(4, .true., b_results, b_diag, b_aggregate, b_states, status)
  call require(status == FMR_SERIAL_DISPATCH_OK, 'B dispatch')
  call validate_case(b_results, b_states)
  call require(result_sets_equal_by_id(a_results, b_results), 'batch/order result identity')
  call require(same_bits(a_aggregate%aggregate_unrounded_mass_residual, &
       b_aggregate%aggregate_unrounded_mass_residual), 'batch/order aggregate residual identity')
  print '(a)', 'FMR31_FORCING_HANDLE_BATCH_ORDER_IDENTITY=PASS'

  call run_case(2, .false., a2_results, a2_diag, a2_aggregate, a2_states, status)
  call require(status == FMR_SERIAL_DISPATCH_OK, 'A2 dispatch')
  call require(result_sets_equal_by_id(a_results, a2_results), 'A-B-A result identity')
  call require(same_bits(a_aggregate%aggregate_unrounded_mass_residual, &
       a2_aggregate%aggregate_unrounded_mass_residual), 'A-B-A aggregate residual identity')
  print '(a)', 'FMR31_A_B_A_RUNTIME_ATTRIBUTION_IDENTITY=PASS'

  call require(same_bits(result_for_id(a_results,31001_int64)%actual_transpiration_amount, &
       result_for_id(a_results,31003_int64)%actual_transpiration_amount), 'shared A forcing identity')
  call require(.not. same_bits(result_for_id(a_results,31001_int64)%actual_transpiration_amount, &
       result_for_id(a_results,31002_int64)%actual_transpiration_amount), 'A/B forcing distinction')
  print '(a)', 'FMR31_EXACT_COLUMN_FORCING_ASSOCIATION=PASS'
  print '(a)', 'FMR31_ROOT_ATTRIBUTION_BINDING_TEST PASS'

contains

  subroutine run_case(batch_size, reverse_order, results, diagnostics, aggregate, states, dispatch)
    integer, intent(in) :: batch_size
    logical, intent(in) :: reverse_order
    type(fmr_serialized_column_result_t), allocatable, intent(out) :: results(:)
    type(fmr_column_diagnostics_t), allocatable, intent(out) :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t), intent(out) :: aggregate
    type(kernel_committed_state_t), allocatable, intent(out) :: states(:)
    integer, intent(out) :: dispatch
    type(fmr_logical_column_t) :: columns(ncol), tmp
    type(fmr_template_t) :: templates(1)
    type(fmr_b110_physical_parameters_t) :: parameters(3)
    type(fmr_b110_physical_forcing_t) :: forcings(3)
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

    call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, states, config, top, &
         t0, t1, batch_size, results, diagnostics, aggregate, dispatch)

    do i = 1, size(results)
      call require(results(i)%column_id == columns(i)%column_id, 'result/input identity')
    end do
  end subroutine run_case

  subroutine configure_case(columns, templates, parameters, forcings, states, config)
    type(fmr_logical_column_t), intent(out) :: columns(ncol)
    type(fmr_template_t), intent(out) :: templates(1)
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters(3)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcings(3)
    type(kernel_committed_state_t), allocatable, intent(out) :: states(:)
    type(canonical_numerical_config_t), intent(out) :: config
    integer :: i

    templates(1)%template_id = 3101_int64
    templates(1)%physics_topology_id = 3102_int64
    templates(1)%vertical_layout_id = 3103_int64
    templates(1)%state_layout_id = 3104_int64
    templates(1)%solver_interface_id = 3105_int64
    templates(1)%optional_state_layout_id = 0_int64
    templates(1)%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    parameters(1)%admitted = .true.
    parameters(1)%active_nodes = 3
    parameters(1)%root_extraction_active = .true.
    parameters(2) = parameters(1)
    parameters(2)%admitted = .false.
    parameters(3) = parameters(1)
    parameters(3)%root_extraction_active = .false.

    allocate(forcings(1)%root_extraction_sink(3))
    forcings(1)%root_extraction_sink = [0.10_real64, 0.20_real64, 0.05_real64]
    allocate(forcings(2)%root_extraction_sink(3))
    forcings(2)%root_extraction_sink = [0.40_real64, 0.00_real64, 0.15_real64]
    allocate(forcings(3)%root_extraction_sink(3))
    forcings(3)%root_extraction_sink = 0.0_real64

    allocate(states(ncol))
    do i = 1, ncol
      columns(i)%column_id = 31000_int64 + int(i,int64)
      columns(i)%template_id = templates(1)%template_id
      columns(i)%parameter_ref = 1_int64
      columns(i)%state_handle = int(i,int64)
      columns(i)%forcing_handle = 1_int64
      columns(i)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
      call initialize_state(states(i), columns(i)%column_id)
    end do
    columns(2)%forcing_handle = 2_int64
    columns(3)%forcing_handle = 1_int64
    columns(4)%forcing_handle = 3_int64
    columns(5)%parameter_ref = 3_int64
    columns(5)%forcing_handle = 3_int64
    columns(6)%parameter_ref = 2_int64
    columns(6)%forcing_handle = 2_int64

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

    allocate(fmr31_test_physical_state_t :: physical)
    select type (physical)
    type is (fmr31_test_physical_state_t)
      physical%storage_value = 10.0_real64
    end select
    call state%initialize(lineage_id, physical, ok, t0)
    call require(ok, 'initialize committed state')
  end subroutine initialize_state

  subroutine validate_case(results, states)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    type(kernel_committed_state_t), intent(in) :: states(:)
    type(fmr_serialized_column_result_t) :: r
    integer :: i

    do i = 1, 4
      r = result_for_id(results, 31000_int64 + int(i,int64))
      call require(r%committed, 'active result committed')
      call require(r%actual_transpiration_available, 'active attribution available')
      call require(states(i)%current_revision() == 1_int64, 'active revision committed')
    end do

    r = result_for_id(results,31001_int64)
    call assert_close(r%actual_transpiration_amount, sum_rates([0.10_real64,0.20_real64,0.05_real64]), 'column 1 amount')
    call assert_close(r%actual_transpiration_amount, r%mass%total_out, 'column 1 mass reconciliation')
    r = result_for_id(results,31002_int64)
    call assert_close(r%actual_transpiration_amount, sum_rates([0.40_real64,0.00_real64,0.15_real64]), 'column 2 amount')
    call assert_close(r%actual_transpiration_amount, r%mass%total_out, 'column 2 mass reconciliation')
    r = result_for_id(results,31003_int64)
    call assert_close(r%actual_transpiration_amount, sum_rates([0.10_real64,0.20_real64,0.05_real64]), 'column 3 amount')
    call assert_close(r%actual_transpiration_amount, r%mass%total_out, 'column 3 mass reconciliation')
    r = result_for_id(results,31004_int64)
    call assert_close(r%actual_transpiration_amount, 0.0_real64, 'active zero amount')
    call assert_close(r%mass%total_out, 0.0_real64, 'active zero mass')
    print '(a)', 'FMR31_ATTRIBUTION_EQUALS_ALREADY_BOOKED_ROOT_MASS=PASS'
    print '(a)', 'FMR31_ACTIVE_ZERO_ROOT_ATTRIBUTION_AVAILABLE=PASS'

    r = result_for_id(results,31005_int64)
    call require(r%committed, 'root-inactive column committed')
    call require(.not. r%actual_transpiration_available, 'root-inactive attribution unavailable')
    call assert_close(r%actual_transpiration_amount, 0.0_real64, 'root-inactive amount default')
    call require(states(5)%current_revision() == 1_int64, 'root-inactive state committed')
    print '(a)', 'FMR31_ROOT_INACTIVE_ATTRIBUTION_UNAVAILABLE=PASS'

    r = result_for_id(results,31006_int64)
    call require(.not. r%committed, 'rejected column not committed')
    call require(.not. r%actual_transpiration_available, 'rejected attribution unavailable')
    call assert_close(r%actual_transpiration_amount, 0.0_real64, 'rejected amount default')
    call require(states(6)%current_revision() == 0_int64, 'rejected state unchanged')
    print '(a)', 'FMR31_NONCOMMITTED_ATTRIBUTION_UNAVAILABLE=PASS'
  end subroutine validate_case

  real(real64) function sum_rates(rates) result(amount)
    real(real64), intent(in) :: rates(:)
    amount = sum(rates) * (t1 - t0)
  end function sum_rates

  logical function result_sets_equal_by_id(left, right) result(equal)
    type(fmr_serialized_column_result_t), intent(in) :: left(:), right(:)
    type(fmr_serialized_column_result_t) :: r
    integer :: i

    equal = size(left) == size(right)
    if (.not. equal) return
    do i = 1, size(left)
      r = result_for_id(right, left(i)%column_id)
      if (left(i)%committed .neqv. r%committed) then
        equal = .false.; return
      end if
      if (left(i)%actual_transpiration_available .neqv. r%actual_transpiration_available) then
        equal = .false.; return
      end if
      if (.not. same_bits(left(i)%actual_transpiration_amount, r%actual_transpiration_amount)) then
        equal = .false.; return
      end if
      if (.not. same_bits(left(i)%mass%total_out, r%mass%total_out)) then
        equal = .false.; return
      end if
      if (.not. same_bits(left(i)%mass%residual, r%mass%residual)) then
        equal = .false.; return
      end if
    end do
  end function result_sets_equal_by_id

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
    error stop 'F-MR31 result id not found'
  end function result_for_id

  subroutine dummy_top_evaluate(self, pressure_head_top, water_content_top, requested, actual_top_flux, surface_head, runoff_flux)
    class(dummy_top_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head_top, water_content_top
    type(soil_water_boundary_conditions_t), intent(in) :: requested
    real(real64), intent(out) :: actual_top_flux, surface_head, runoff_flux
    if (.not. same_type_as(self,self) .or. pressure_head_top /= pressure_head_top .or. &
        water_content_top /= water_content_top) error stop 'F-MR31 dummy top invalid input'
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

  subroutine assert_close(actual, expected, label)
    real(real64), intent(in) :: actual, expected
    character(len=*), intent(in) :: label
    real(real64) :: tolerance
    tolerance = 512.0_real64 * epsilon(1.0_real64) * max(1.0_real64, abs(actual), abs(expected))
    call require(abs(actual-expected) <= tolerance, label)
  end subroutine assert_close

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,1x,a)') 'FMR31_ASSERT_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fmr31_exact_root_attribution_binding
