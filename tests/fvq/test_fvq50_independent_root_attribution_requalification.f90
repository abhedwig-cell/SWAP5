program test_fvq50_independent_root_attribution_requalification
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, TX_MASS_MISSING_NONE, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fvq50_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  implicit none

  integer, parameter :: ncol = 7
  real(real64), parameter :: t0 = 731.3125_real64
  real(real64), parameter :: t1 = 732.84375_real64
  real(real64), parameter :: dt = t1 - t0
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64

  type(fmr_serialized_column_result_t), allocatable :: a(:), b(:), c(:), d(:), a2(:)
  type(fmr_column_diagnostics_t), allocatable :: da(:), db(:), dc(:), dd(:), da2(:)
  type(fmr_aggregate_diagnostics_t) :: aga, agb, agc, agd, aga2
  type(fmr_serialized_batch_diagnostics_t) :: rta, rtb, rtc, rtd, rta2
  type(kernel_committed_state_t), allocatable :: sa(:), sb(:), sc(:), sd(:), sa2(:)
  integer :: status

  call run_case(1, 0, a, da, aga, rta, sa, status)
  call require(status == FMR_SERIAL_DISPATCH_OK, 'case A dispatch')
  call validate_case(a, rta, sa)

  call run_case(2, 1, b, db, agb, rtb, sb, status)
  call require(status == FMR_SERIAL_DISPATCH_OK, 'case B dispatch')
  call validate_case(b, rtb, sb)
  call require(result_sets_equal_by_id(a,b), 'reverse/batch identity')

  call run_case(5, 2, c, dc, agc, rtc, sc, status)
  call require(status == FMR_SERIAL_DISPATCH_OK, 'case C dispatch')
  call validate_case(c, rtc, sc)
  call require(result_sets_equal_by_id(a,c), 'permuted/batch identity')

  call run_case(7, 0, d, dd, agd, rtd, sd, status)
  call require(status == FMR_SERIAL_DISPATCH_OK, 'case D dispatch')
  call validate_case(d, rtd, sd)
  call require(result_sets_equal_by_id(a,d), 'full-batch identity')

  call run_case(1, 0, a2, da2, aga2, rta2, sa2, status)
  call require(status == FMR_SERIAL_DISPATCH_OK, 'case A2 dispatch')
  call require(result_sets_equal_by_id(a,a2), 'A-B-C-D-A deterministic replay')
  call require(same_bits(rta%authoritative_aggregate_mass%total_out, rta2%authoritative_aggregate_mass%total_out), &
       'A replay aggregate total_out')
  call require(same_bits(rta%authoritative_aggregate_mass%residual, rta2%authoritative_aggregate_mass%residual), &
       'A replay aggregate residual')
  write(*,'(A)') 'FVQ50_A_B_A_REPLAY=PASS'

  call tamper_after_return()

  call require(same_bits(result_for_id(a,50001_int64)%actual_transpiration_amount, &
       result_for_id(a,50003_int64)%actual_transpiration_amount), 'shared B handle identity')
  call require(same_bits(result_for_id(a,50002_int64)%actual_transpiration_amount, &
       result_for_id(a,50004_int64)%actual_transpiration_amount), 'shared A handle identity')
  call require(.not. same_bits(result_for_id(a,50001_int64)%actual_transpiration_amount, &
       result_for_id(a,50002_int64)%actual_transpiration_amount), 'distinct handle distinction')
  write(*,'(A)') 'FVQ50_EXACT_FORCING_HANDLE_ASSOCIATION=PASS'
  write(*,'(A)') 'FVQ50_INDEPENDENT_ROOT_ATTRIBUTION_REQUALIFICATION PASS'

contains

  subroutine run_case(batch_size, order_mode, results, diagnostics, aggregate, runtime, states, dispatch)
    integer, intent(in) :: batch_size, order_mode
    type(fmr_serialized_column_result_t), allocatable, intent(out) :: results(:)
    type(fmr_column_diagnostics_t), allocatable, intent(out) :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t), intent(out) :: aggregate
    type(fmr_serialized_batch_diagnostics_t), intent(out) :: runtime
    type(kernel_committed_state_t), allocatable, intent(out) :: states(:)
    integer, intent(out) :: dispatch
    type(fmr_logical_column_t) :: columns(ncol), ordered(ncol)
    type(fmr_template_t) :: templates(1)
    type(fmr_b110_physical_parameters_t) :: parameters(3)
    type(fmr_b110_physical_forcing_t) :: forcings(3)
    type(canonical_numerical_config_t) :: config
    type(fmr04_fixed_flux_top_provider_t), target :: top
    integer :: permutation(ncol), i

    call configure_case(columns, templates, parameters, forcings, states, config)
    select case(order_mode)
    case(0)
      permutation = [1,2,3,4,5,6,7]
    case(1)
      permutation = [7,6,5,4,3,2,1]
    case(2)
      permutation = [4,1,7,3,6,2,5]
    case default
      error stop 'F-VQ50 invalid order mode'
    end select
    do i=1,ncol
      ordered(i) = columns(permutation(i))
    end do

    call fmr_run_serialized_physical_multiswap(ordered, templates, parameters, forcings, states, config, top, &
         t0, t1, batch_size, results, diagnostics, aggregate, dispatch, runtime)
  end subroutine run_case

  subroutine configure_case(columns, templates, parameters, forcings, states, config)
    type(fmr_logical_column_t), intent(out) :: columns(ncol)
    type(fmr_template_t), intent(out) :: templates(1)
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters(3)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcings(3)
    type(kernel_committed_state_t), allocatable, intent(out) :: states(:)
    type(canonical_numerical_config_t), intent(out) :: config
    integer :: i

    templates(1)%template_id = 5050_int64
    templates(1)%physics_topology_id = 50501_int64
    templates(1)%vertical_layout_id = 50502_int64
    templates(1)%state_layout_id = 50503_int64
    templates(1)%solver_interface_id = 50504_int64
    templates(1)%optional_state_layout_id = 0_int64
    templates(1)%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    parameters(1)%admitted = .true.
    parameters(1)%active_nodes = 3
    parameters(1)%root_extraction_active = .true.
    parameters(1)%independent_background_out_rate = 0.07_real64
    parameters(2) = parameters(1)
    parameters(2)%root_extraction_active = .false.
    parameters(2)%independent_background_out_rate = 0.03_real64
    parameters(3) = parameters(1)
    parameters(3)%admitted = .false.

    allocate(forcings(1)%root_extraction_sink(3))
    forcings(1)%root_extraction_sink = [0.10_real64, 0.20_real64, 0.05_real64]
    allocate(forcings(2)%root_extraction_sink(3))
    forcings(2)%root_extraction_sink = [0.40_real64, 0.00_real64, 0.15_real64]
    allocate(forcings(3)%root_extraction_sink(3))
    forcings(3)%root_extraction_sink = 0.0_real64

    allocate(states(ncol))
    do i=1,ncol
      columns(i)%column_id = 50000_int64 + int(i,int64)
      columns(i)%template_id = templates(1)%template_id
      columns(i)%parameter_ref = 1_int64
      columns(i)%state_handle = int(i,int64)
      columns(i)%forcing_handle = 1_int64
      columns(i)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
      call initialize_state(states(i), columns(i)%column_id)
    end do

    columns(1)%forcing_handle = 2_int64
    columns(2)%forcing_handle = 1_int64
    columns(3)%forcing_handle = 2_int64
    columns(4)%forcing_handle = 1_int64
    columns(5)%forcing_handle = 3_int64
    columns(6)%parameter_ref = 2_int64
    columns(6)%forcing_handle = 1_int64
    columns(7)%parameter_ref = 3_int64
    columns(7)%forcing_handle = 2_int64

    config%transaction%temporal_tolerance = 0.0_real64
    config%transaction%mass_tolerance = hard_mass_gate
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 2
    config%transaction%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
    config%max_committed_substeps = 8
    config%progress_tolerance = 0.0_real64
  end subroutine configure_case

  subroutine initialize_state(state, lineage)
    type(kernel_committed_state_t), intent(out) :: state
    integer(int64), intent(in) :: lineage
    class(transaction_state_t), allocatable :: physical
    logical :: ok
    allocate(fvq50_physical_state_t :: physical)
    select type (physical)
    type is (fvq50_physical_state_t)
      physical%storage = 50.0_real64
    end select
    call state%initialize(lineage, physical, ok, t0)
    call require(ok, 'committed state init')
  end subroutine initialize_state

  subroutine validate_case(results, runtime, states)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    type(fmr_serialized_batch_diagnostics_t), intent(in) :: runtime
    type(kernel_committed_state_t), intent(in) :: states(:)
    type(fmr_serialized_column_result_t) :: r
    real(real64) :: root_amount, background_amount, expected_total, sum_total
    integer :: id

    sum_total = 0.0_real64
    do id=1,5
      r = result_for_id(results,50000_int64+int(id,int64))
      call require(r%committed .and. r%completed, 'active root column committed')
      call require(r%actual_transpiration_available, 'active root attribution available')
      if (id == 1 .or. id == 3) then
        root_amount = 0.55_real64 * dt
      else if (id == 2 .or. id == 4) then
        root_amount = 0.35_real64 * dt
      else
        root_amount = 0.0_real64
      end if
      background_amount = 0.07_real64 * dt
      expected_total = root_amount + background_amount
      call assert_close(r%actual_transpiration_amount, root_amount, 'exact root forcing integral')
      call assert_close(r%mass%total_out, expected_total, 'independent root plus background mass_out')
      call assert_close(r%mass%total_out-r%actual_transpiration_amount, background_amount, 'background separation')
      call require(r%mass%complete .and. r%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, 'mass complete')
      call require(abs(r%mass%residual) <= hard_mass_gate, 'hard mass residual')
      call require(states(id)%current_revision() == 1_int64, 'active revision advanced')
      sum_total = sum_total + r%mass%total_out
    end do
    write(*,'(A)') 'FVQ50_ATTRIBUTION_NOT_DERIVED_FROM_TOTAL_MASS_OUT=PASS'
    write(*,'(A)') 'FVQ50_ACTIVE_ZERO_ATTRIBUTION_AVAILABLE=PASS'

    r = result_for_id(results,50006_int64)
    background_amount = 0.03_real64 * dt
    call require(r%committed .and. r%completed, 'root-inactive column committed')
    call require(.not. r%actual_transpiration_available, 'root-inactive attribution unavailable')
    call assert_close(r%actual_transpiration_amount,0.0_real64,'root-inactive zero attribution')
    call assert_close(r%mass%total_out,background_amount,'root-inactive background mass')
    call require(abs(r%mass%residual) <= hard_mass_gate, 'root-inactive hard mass residual')
    call require(states(6)%current_revision() == 1_int64, 'root-inactive revision advanced')
    sum_total = sum_total + r%mass%total_out
    write(*,'(A)') 'FVQ50_ROOT_INACTIVE_ATTRIBUTION_UNAVAILABLE=PASS'

    r = result_for_id(results,50007_int64)
    call require(.not. r%committed .and. .not. r%completed, 'not-admitted column not committed')
    call require(.not. r%actual_transpiration_available, 'not-admitted attribution unavailable')
    call assert_close(r%actual_transpiration_amount,0.0_real64,'not-admitted zero attribution')
    call require(states(7)%current_revision() == 0_int64, 'not-admitted revision unchanged')
    write(*,'(A)') 'FVQ50_NONCOMMITTED_ATTRIBUTION_UNAVAILABLE=PASS'

    call assert_close(runtime%authoritative_aggregate_mass%total_out,sum_total,'aggregate exactly once total_out')
    call require(abs(runtime%authoritative_aggregate_mass%residual) <= hard_mass_gate, 'aggregate hard mass residual')
    write(*,'(A)') 'FVQ50_NO_SECOND_MASS_BOOKING=PASS'
    write(*,'(A)') 'FVQ50_HARD_MASS_BALANCE=PASS'
  end subroutine validate_case

  subroutine tamper_after_return()
    type(fmr_logical_column_t) :: columns(ncol)
    type(fmr_template_t) :: templates(1)
    type(fmr_b110_physical_parameters_t) :: parameters(3)
    type(fmr_b110_physical_forcing_t) :: forcings(3)
    type(kernel_committed_state_t), allocatable :: states(:)
    type(canonical_numerical_config_t) :: config
    type(fmr04_fixed_flux_top_provider_t), target :: top
    type(fmr_serialized_column_result_t), allocatable :: results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(fmr_serialized_column_result_t) :: before, after
    integer :: dispatch

    call configure_case(columns,templates,parameters,forcings,states,config)
    call fmr_run_serialized_physical_multiswap(columns,templates,parameters,forcings,states,config,top, &
         t0,t1,2,results,diagnostics,aggregate,dispatch,runtime)
    call require(dispatch == FMR_SERIAL_DISPATCH_OK,'tamper case dispatch')
    before = result_for_id(results,50002_int64)
    forcings(1)%root_extraction_sink = forcings(2)%root_extraction_sink
    after = result_for_id(results,50002_int64)
    call require(same_bits(before%actual_transpiration_amount,after%actual_transpiration_amount), &
         'published attribution immutable after forcing mutation')
    call require(same_bits(before%mass%total_out,after%mass%total_out),'published mass immutable after forcing mutation')
    call assert_close(after%actual_transpiration_amount,0.35_real64*dt,'tamper retains original A attribution')
    write(*,'(A)') 'FVQ50_BY_VALUE_POSTRUN_FORCING_TAMPER_RESISTANCE=PASS'
  end subroutine tamper_after_return

  logical function result_sets_equal_by_id(left,right) result(equal)
    type(fmr_serialized_column_result_t), intent(in) :: left(:), right(:)
    type(fmr_serialized_column_result_t) :: r
    integer :: i
    equal = size(left) == size(right)
    if (.not. equal) return
    do i=1,size(left)
      r = result_for_id(right,left(i)%column_id)
      if (left(i)%committed .neqv. r%committed) then; equal=.false.; return; end if
      if (left(i)%actual_transpiration_available .neqv. r%actual_transpiration_available) then; equal=.false.; return; end if
      if (.not. same_bits(left(i)%actual_transpiration_amount,r%actual_transpiration_amount)) then; equal=.false.; return; end if
      if (.not. same_bits(left(i)%mass%total_out,r%mass%total_out)) then; equal=.false.; return; end if
      if (.not. same_bits(left(i)%mass%residual,r%mass%residual)) then; equal=.false.; return; end if
      if (left(i)%final_revision /= r%final_revision) then; equal=.false.; return; end if
    end do
  end function result_sets_equal_by_id

  function result_for_id(results,id) result(value)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    integer(int64), intent(in) :: id
    type(fmr_serialized_column_result_t) :: value
    integer :: i
    value = fmr_serialized_column_result_t()
    do i=1,size(results)
      if (results(i)%column_id == id) then
        value = results(i)
        return
      end if
    end do
    error stop 'F-VQ50 result id not found'
  end function result_for_id

  pure logical function same_bits(x,y) result(equal)
    real(real64), intent(in) :: x,y
    integer(int64) :: ix,iy
    ix = transfer(x,ix)
    iy = transfer(y,iy)
    equal = ix == iy
  end function same_bits

  subroutine assert_close(actual,expected,label)
    real(real64), intent(in) :: actual,expected
    character(len=*), intent(in) :: label
    real(real64) :: tolerance
    tolerance = 512.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(actual),abs(expected))
    call require(abs(actual-expected) <= tolerance,label)
  end subroutine assert_close

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FVQ50_ASSERT_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fvq50_independent_root_attribution_requalification
