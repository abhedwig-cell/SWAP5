program test_fmr23_reference_et_runtime_binding
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_canonical_contracts, only: canonical_interval_t
  use mod_reference_et_demand_process
  use mod_fmr_reference_et_demand_binding
  implicit none

  integer :: failures

  failures = 0
  call test_arbitrary_subday_interval(failures)
  call test_subinterval_rate_invariance(failures)
  call test_forcing_containment_fail_closed(failures)
  call test_invalid_interval_and_span(failures)
  call test_process_rejection_fail_closed(failures)
  call test_nonemerged_dependency_semantics(failures)
  call test_stateless_replay(failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'FMR23_FAILURE_COUNT=', failures
    error stop 1
  end if

  write(*,'(A)') 'FMR23_ARBITRARY_SUBDAY_INTERVAL=PASS'
  write(*,'(A)') 'FMR23_FORCING_SPAN_CONTAINMENT=PASS'
  write(*,'(A)') 'FMR23_RATE_NOT_IMPLICITLY_TIME_INTEGRATED=PASS'
  write(*,'(A)') 'FMR23_INVALID_TIME_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FMR23_PROCESS_REJECTION_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FMR23_NONEMERGED_CANOPY_SEMANTICS=PASS'
  write(*,'(A)') 'FMR23_STATELESS_A_B_A_IDENTITY=PASS'
  write(*,'(A)') 'FMR23_REFERENCE_ET_RUNTIME_BINDING_TEST PASS'

contains

  subroutine configure_active(parameters, forcing_span, canopy)
    type(reference_et_demand_parameters_t), intent(out) :: parameters
    type(fmr_reference_et_forcing_span_t), intent(out) :: forcing_span
    type(reference_et_demand_canopy_view_t), intent(out) :: canopy

    parameters%pond_evaporation_factor = 1.2_real64
    forcing_span%t0 = 2700.0_real64
    forcing_span%t1 = 2701.0_real64
    forcing_span%reference_et_mm_per_day = 5.2_real64
    canopy%crop_emerged = .true.
    canopy%vegetation_cover_fraction = 0.65_real64
    canopy%crop_factor = 1.1_real64
    canopy%co2_transpiration_factor = 0.9_real64
  end subroutine configure_active

  subroutine evaluate(interval, forcing_span, parameters, canopy, result, diagnostics)
    type(canonical_interval_t), intent(in) :: interval
    type(fmr_reference_et_forcing_span_t), intent(in) :: forcing_span
    type(reference_et_demand_parameters_t), intent(in) :: parameters
    type(reference_et_demand_canopy_view_t), intent(in) :: canopy
    type(reference_et_demand_result_t), intent(out) :: result
    type(fmr_reference_et_binding_diagnostics_t), intent(out) :: diagnostics
    type(reference_et_demand_diagnostics_t) :: process_diagnostics

    call fmr_evaluate_reference_et_demand(interval, forcing_span, parameters, canopy, result, &
                                          process_diagnostics, diagnostics)
  end subroutine evaluate

  subroutine test_arbitrary_subday_interval(failures)
    integer, intent(inout) :: failures
    type(canonical_interval_t) :: interval
    type(reference_et_demand_parameters_t) :: parameters
    type(fmr_reference_et_forcing_span_t) :: forcing_span
    type(reference_et_demand_canopy_view_t) :: canopy
    type(reference_et_demand_result_t) :: result
    type(fmr_reference_et_binding_diagnostics_t) :: diagnostics

    call configure_active(parameters, forcing_span, canopy)
    interval%t0 = 2700.125_real64
    interval%t1 = 2700.375_real64
    call evaluate(interval, forcing_span, parameters, canopy, result, diagnostics)

    call assert_true(diagnostics%status == FMR_REFERENCE_ET_BINDING_OK, 'subday status', failures)
    call assert_true(diagnostics%interval_valid, 'subday interval valid', failures)
    call assert_true(diagnostics%forcing_span_valid, 'subday forcing valid', failures)
    call assert_true(diagnostics%forcing_covers_interval, 'subday forcing covers', failures)
    call assert_true(diagnostics%process_called, 'subday process called', failures)
    call assert_true(diagnostics%result_produced, 'subday result produced', failures)
    call assert_close(diagnostics%interval_duration, 0.25_real64, 'subday duration', failures)
    call assert_close(result%potential_soil_evaporation_cm_per_day, 0.182_real64, 'subday peva rate', failures)
    call assert_close(result%potential_pond_evaporation_cm_per_day, 0.2184_real64, 'subday epond rate', failures)
    call assert_close(result%potential_transpiration_cm_per_day, 0.33462_real64, 'subday ptra rate', failures)
  end subroutine test_arbitrary_subday_interval

  subroutine test_subinterval_rate_invariance(failures)
    integer, intent(inout) :: failures
    type(canonical_interval_t) :: a, b
    type(reference_et_demand_parameters_t) :: parameters
    type(fmr_reference_et_forcing_span_t) :: forcing_span
    type(reference_et_demand_canopy_view_t) :: canopy
    type(reference_et_demand_result_t) :: ra, rb
    type(fmr_reference_et_binding_diagnostics_t) :: diagnostics

    call configure_active(parameters, forcing_span, canopy)
    a%t0 = 2700.0_real64
    a%t1 = 2700.1_real64
    b%t0 = 2700.6_real64
    b%t1 = 2700.95_real64

    call evaluate(a, forcing_span, parameters, canopy, ra, diagnostics)
    call assert_true(diagnostics%status == FMR_REFERENCE_ET_BINDING_OK, 'rate invariant A status', failures)
    call evaluate(b, forcing_span, parameters, canopy, rb, diagnostics)
    call assert_true(diagnostics%status == FMR_REFERENCE_ET_BINDING_OK, 'rate invariant B status', failures)

    call assert_same_result_bits(ra, rb, 'subinterval rate invariance', failures)
  end subroutine test_subinterval_rate_invariance

  subroutine test_forcing_containment_fail_closed(failures)
    integer, intent(inout) :: failures
    type(canonical_interval_t) :: interval
    type(reference_et_demand_parameters_t) :: parameters
    type(fmr_reference_et_forcing_span_t) :: forcing_span
    type(reference_et_demand_canopy_view_t) :: canopy
    type(reference_et_demand_result_t) :: result
    type(fmr_reference_et_binding_diagnostics_t) :: diagnostics

    call configure_active(parameters, forcing_span, canopy)
    interval%t0 = 2699.9_real64
    interval%t1 = 2700.1_real64
    call evaluate(interval, forcing_span, parameters, canopy, result, diagnostics)
    call assert_true(diagnostics%status == FMR_REFERENCE_ET_BINDING_FORCING_NOT_COVERING_INTERVAL, &
                     'left containment rejected', failures)
    call assert_true(.not. diagnostics%process_called, 'left containment process not called', failures)
    call assert_zero_result(result, 'left containment zero', failures)

    interval%t0 = 2700.9_real64
    interval%t1 = 2701.1_real64
    call evaluate(interval, forcing_span, parameters, canopy, result, diagnostics)
    call assert_true(diagnostics%status == FMR_REFERENCE_ET_BINDING_FORCING_NOT_COVERING_INTERVAL, &
                     'right containment rejected', failures)
    call assert_true(.not. diagnostics%process_called, 'right containment process not called', failures)
    call assert_zero_result(result, 'right containment zero', failures)
  end subroutine test_forcing_containment_fail_closed

  subroutine test_invalid_interval_and_span(failures)
    integer, intent(inout) :: failures
    type(canonical_interval_t) :: interval
    type(reference_et_demand_parameters_t) :: parameters
    type(fmr_reference_et_forcing_span_t) :: forcing_span
    type(reference_et_demand_canopy_view_t) :: canopy
    type(reference_et_demand_result_t) :: result
    type(fmr_reference_et_binding_diagnostics_t) :: diagnostics

    call configure_active(parameters, forcing_span, canopy)
    interval%t0 = 2700.5_real64
    interval%t1 = 2700.5_real64
    call evaluate(interval, forcing_span, parameters, canopy, result, diagnostics)
    call assert_true(diagnostics%status == FMR_REFERENCE_ET_BINDING_INVALID_INTERVAL, 'zero interval rejected', failures)
    call assert_zero_result(result, 'zero interval result', failures)

    interval%t0 = ieee_value(0.0_real64, ieee_quiet_nan)
    interval%t1 = 2700.5_real64
    call evaluate(interval, forcing_span, parameters, canopy, result, diagnostics)
    call assert_true(diagnostics%status == FMR_REFERENCE_ET_BINDING_INVALID_INTERVAL, 'NaN interval rejected', failures)
    call assert_zero_result(result, 'NaN interval result', failures)

    interval%t0 = 2700.2_real64
    interval%t1 = 2700.3_real64
    forcing_span%t1 = forcing_span%t0
    call evaluate(interval, forcing_span, parameters, canopy, result, diagnostics)
    call assert_true(diagnostics%status == FMR_REFERENCE_ET_BINDING_INVALID_FORCING_SPAN, 'zero forcing span rejected', failures)
    call assert_zero_result(result, 'zero forcing span result', failures)
  end subroutine test_invalid_interval_and_span

  subroutine test_process_rejection_fail_closed(failures)
    integer, intent(inout) :: failures
    type(canonical_interval_t) :: interval
    type(reference_et_demand_parameters_t) :: parameters
    type(fmr_reference_et_forcing_span_t) :: forcing_span
    type(reference_et_demand_canopy_view_t) :: canopy
    type(reference_et_demand_result_t) :: result
    type(fmr_reference_et_binding_diagnostics_t) :: diagnostics

    call configure_active(parameters, forcing_span, canopy)
    interval%t0 = 2700.2_real64
    interval%t1 = 2700.3_real64
    forcing_span%reference_et_mm_per_day = -1.0_real64
    call evaluate(interval, forcing_span, parameters, canopy, result, diagnostics)
    call assert_true(diagnostics%status == FMR_REFERENCE_ET_BINDING_PROCESS_REJECTED, 'negative ET process rejection', failures)
    call assert_true(diagnostics%process_called, 'negative ET process called', failures)
    call assert_true(.not. diagnostics%result_produced, 'negative ET no result', failures)
    call assert_zero_result(result, 'negative ET zero result', failures)
  end subroutine test_process_rejection_fail_closed

  subroutine test_nonemerged_dependency_semantics(failures)
    integer, intent(inout) :: failures
    type(canonical_interval_t) :: interval
    type(reference_et_demand_parameters_t) :: parameters
    type(fmr_reference_et_forcing_span_t) :: forcing_span
    type(reference_et_demand_canopy_view_t) :: canopy
    type(reference_et_demand_result_t) :: result
    type(fmr_reference_et_binding_diagnostics_t) :: diagnostics

    call configure_active(parameters, forcing_span, canopy)
    interval%t0 = 2700.4_real64
    interval%t1 = 2700.6_real64
    canopy%crop_emerged = .false.
    canopy%vegetation_cover_fraction = 0.3_real64
    canopy%crop_factor = ieee_value(0.0_real64, ieee_quiet_nan)
    canopy%co2_transpiration_factor = ieee_value(0.0_real64, ieee_quiet_nan)

    call evaluate(interval, forcing_span, parameters, canopy, result, diagnostics)
    call assert_true(diagnostics%status == FMR_REFERENCE_ET_BINDING_OK, 'nonemerged status', failures)
    call assert_close(result%potential_transpiration_cm_per_day, 0.0_real64, 'nonemerged ptra', failures)
    call assert_close(result%potential_soil_evaporation_cm_per_day, 0.364_real64, 'nonemerged peva', failures)
    call assert_close(result%potential_pond_evaporation_cm_per_day, 0.4368_real64, 'nonemerged epond', failures)
  end subroutine test_nonemerged_dependency_semantics

  subroutine test_stateless_replay(failures)
    integer, intent(inout) :: failures
    type(canonical_interval_t) :: ia, ib
    type(reference_et_demand_parameters_t) :: pa, pb
    type(fmr_reference_et_forcing_span_t) :: fa, fb
    type(reference_et_demand_canopy_view_t) :: ca, cb
    type(reference_et_demand_result_t) :: ra1, rb, ra2
    type(fmr_reference_et_binding_diagnostics_t) :: diagnostics

    call configure_active(pa, fa, ca)
    ia%t0 = 2700.125_real64
    ia%t1 = 2700.375_real64

    pb%pond_evaporation_factor = 0.8_real64
    fb%t0 = 900.0_real64
    fb%t1 = 902.0_real64
    fb%reference_et_mm_per_day = 2.5_real64
    cb%crop_emerged = .false.
    cb%vegetation_cover_fraction = 0.2_real64
    cb%crop_factor = 9.0_real64
    cb%co2_transpiration_factor = 9.0_real64
    ib%t0 = 901.1_real64
    ib%t1 = 901.9_real64

    call evaluate(ia, fa, pa, ca, ra1, diagnostics)
    call evaluate(ib, fb, pb, cb, rb, diagnostics)
    call evaluate(ia, fa, pa, ca, ra2, diagnostics)
    call assert_same_result_bits(ra1, ra2, 'A-B-A', failures)
  end subroutine test_stateless_replay

  subroutine assert_zero_result(result, label, failures)
    type(reference_et_demand_result_t), intent(in) :: result
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    call assert_close(result%potential_transpiration_cm_per_day, 0.0_real64, trim(label)//' ptra', failures)
    call assert_close(result%potential_soil_evaporation_cm_per_day, 0.0_real64, trim(label)//' peva', failures)
    call assert_close(result%potential_pond_evaporation_cm_per_day, 0.0_real64, trim(label)//' epond', failures)
  end subroutine assert_zero_result

  subroutine assert_same_result_bits(a, b, label, failures)
    type(reference_et_demand_result_t), intent(in) :: a, b
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    call assert_true(same_bits(a%potential_transpiration_cm_per_day, b%potential_transpiration_cm_per_day), &
                     trim(label)//' ptra bits', failures)
    call assert_true(same_bits(a%potential_soil_evaporation_cm_per_day, b%potential_soil_evaporation_cm_per_day), &
                     trim(label)//' peva bits', failures)
    call assert_true(same_bits(a%potential_pond_evaporation_cm_per_day, b%potential_pond_evaporation_cm_per_day), &
                     trim(label)//' epond bits', failures)
  end subroutine assert_same_result_bits

  subroutine assert_true(condition, label, failures)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    if (.not. condition) then
      failures = failures + 1
      write(*,'(A,A)') 'FAIL ', trim(label)
    end if
  end subroutine assert_true

  subroutine assert_close(actual, expected, label, failures)
    real(real64), intent(in) :: actual, expected
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    real(real64) :: tolerance
    tolerance = 1.0e-13_real64 * max(1.0_real64, abs(expected))
    if (abs(actual - expected) > tolerance) then
      failures = failures + 1
      write(*,'(A,A,2(1X,ES24.16))') 'FAIL ', trim(label), actual, expected
    end if
  end subroutine assert_close

  logical function same_bits(a, b) result(equal)
    real(real64), intent(in) :: a, b
    equal = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function same_bits

end program test_fmr23_reference_et_runtime_binding
