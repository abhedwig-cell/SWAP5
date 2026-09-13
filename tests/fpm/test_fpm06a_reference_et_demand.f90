program test_fpm06a_reference_et_demand
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_reference_et_demand_process
  implicit none

  integer :: failures

  failures = 0

  call test_active_source_equations(failures)
  call test_surface_cover_semantics(failures)
  call test_inactive_crop_dependency_minimality(failures)
  call test_boundary_cases(failures)
  call test_invalid_inputs_fail_closed(failures)
  call test_stateless_replay(failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'FPM06A_FAILURE_COUNT=', failures
    error stop 1
  end if

  write(*,'(A)') 'FPM06A_B110_REFERENCE_ET_EQUATIONS=PASS'
  write(*,'(A)') 'FPM06A_SURFACE_DEMAND_VCOVER_SEMANTICS=PASS'
  write(*,'(A)') 'FPM06A_INACTIVE_CROP_DEPENDENCY_MINIMAL=PASS'
  write(*,'(A)') 'FPM06A_BOUNDARY_CASES=PASS'
  write(*,'(A)') 'FPM06A_FAIL_CLOSED_INVALID_INPUT=PASS'
  write(*,'(A)') 'FPM06A_STATELESS_A_B_A_IDENTITY=PASS'
  write(*,'(A)') 'FPM06A_REFERENCE_ET_DEMAND_TEST PASS'

contains

  subroutine test_active_source_equations(failures)
    integer, intent(inout) :: failures
    type(reference_et_demand_parameters_t) :: parameters
    type(reference_et_demand_forcing_t) :: forcing
    type(reference_et_demand_canopy_view_t) :: canopy
    type(reference_et_demand_result_t) :: result
    type(reference_et_demand_diagnostics_t) :: diagnostics

    parameters%pond_evaporation_factor = 1.2_real64
    forcing%reference_et_mm_per_day = 5.2_real64
    canopy%crop_emerged = .true.
    canopy%vegetation_cover_fraction = 0.65_real64
    canopy%crop_factor = 1.1_real64
    canopy%co2_transpiration_factor = 0.9_real64

    call evaluate_restricted_reference_et_demand(parameters, forcing, canopy, result, diagnostics)

    call assert_true(diagnostics%status == REF_ET_DEMAND_OK, 'active status', failures)
    call assert_true(diagnostics%forcing_consumed, 'active forcing consumed', failures)
    call assert_true(diagnostics%canopy_cover_consumed, 'active cover consumed', failures)
    call assert_true(diagnostics%crop_specific_factors_consumed, 'active crop factors consumed', failures)
    call assert_true(diagnostics%result_produced, 'active result produced', failures)
    call assert_close(result%potential_soil_evaporation_cm_per_day, 0.182_real64, 'active peva', failures)
    call assert_close(result%potential_pond_evaporation_cm_per_day, 0.2184_real64, 'active epond', failures)
    call assert_close(result%potential_transpiration_cm_per_day, 0.33462_real64, 'active ptra', failures)
  end subroutine test_active_source_equations

  subroutine test_surface_cover_semantics(failures)
    integer, intent(inout) :: failures
    type(reference_et_demand_parameters_t) :: parameters
    type(reference_et_demand_forcing_t) :: forcing
    type(reference_et_demand_canopy_view_t) :: canopy
    type(reference_et_demand_result_t) :: result
    type(reference_et_demand_diagnostics_t) :: diagnostics

    parameters%pond_evaporation_factor = 1.2_real64
    forcing%reference_et_mm_per_day = 5.2_real64
    canopy%crop_emerged = .false.
    canopy%vegetation_cover_fraction = 0.3_real64
    canopy%crop_factor = 7.0_real64
    canopy%co2_transpiration_factor = 8.0_real64

    call evaluate_restricted_reference_et_demand(parameters, forcing, canopy, result, diagnostics)

    call assert_true(diagnostics%status == REF_ET_DEMAND_OK, 'surface semantics status', failures)
    call assert_close(result%potential_transpiration_cm_per_day, 0.0_real64, 'surface semantics ptra', failures)
    call assert_close(result%potential_soil_evaporation_cm_per_day, 0.364_real64, 'surface semantics peva', failures)
    call assert_close(result%potential_pond_evaporation_cm_per_day, 0.4368_real64, 'surface semantics epond', failures)
  end subroutine test_surface_cover_semantics

  subroutine test_inactive_crop_dependency_minimality(failures)
    integer, intent(inout) :: failures
    type(reference_et_demand_parameters_t) :: parameters
    type(reference_et_demand_forcing_t) :: forcing
    type(reference_et_demand_canopy_view_t) :: canopy
    type(reference_et_demand_result_t) :: result
    type(reference_et_demand_diagnostics_t) :: diagnostics

    parameters%pond_evaporation_factor = 1.0_real64
    forcing%reference_et_mm_per_day = 4.0_real64
    canopy%crop_emerged = .false.
    canopy%vegetation_cover_fraction = 0.25_real64
    canopy%crop_factor = ieee_value(0.0_real64, ieee_quiet_nan)
    canopy%co2_transpiration_factor = ieee_value(0.0_real64, ieee_quiet_nan)

    call evaluate_restricted_reference_et_demand(parameters, forcing, canopy, result, diagnostics)

    call assert_true(diagnostics%status == REF_ET_DEMAND_OK, 'inactive stale factors ignored', failures)
    call assert_true(.not. diagnostics%crop_specific_factors_consumed, 'inactive factors not consumed', failures)
    call assert_true(diagnostics%result_produced, 'inactive result produced', failures)
    call assert_close(result%potential_transpiration_cm_per_day, 0.0_real64, 'inactive ptra', failures)
    call assert_close(result%potential_soil_evaporation_cm_per_day, 0.3_real64, 'inactive peva', failures)
    call assert_close(result%potential_pond_evaporation_cm_per_day, 0.3_real64, 'inactive epond', failures)
  end subroutine test_inactive_crop_dependency_minimality

  subroutine test_boundary_cases(failures)
    integer, intent(inout) :: failures
    type(reference_et_demand_parameters_t) :: parameters
    type(reference_et_demand_forcing_t) :: forcing
    type(reference_et_demand_canopy_view_t) :: canopy
    type(reference_et_demand_result_t) :: result
    type(reference_et_demand_diagnostics_t) :: diagnostics

    parameters%pond_evaporation_factor = 1.2_real64
    forcing%reference_et_mm_per_day = 5.2_real64
    canopy%crop_emerged = .true.
    canopy%crop_factor = 1.1_real64
    canopy%co2_transpiration_factor = 0.9_real64

    canopy%vegetation_cover_fraction = 0.0_real64
    call evaluate_restricted_reference_et_demand(parameters, forcing, canopy, result, diagnostics)
    call assert_true(diagnostics%status == REF_ET_DEMAND_OK, 'cover zero status', failures)
    call assert_close(result%potential_transpiration_cm_per_day, 0.0_real64, 'cover zero ptra', failures)
    call assert_close(result%potential_soil_evaporation_cm_per_day, 0.52_real64, 'cover zero peva', failures)
    call assert_close(result%potential_pond_evaporation_cm_per_day, 0.624_real64, 'cover zero epond', failures)

    canopy%vegetation_cover_fraction = 1.0_real64
    call evaluate_restricted_reference_et_demand(parameters, forcing, canopy, result, diagnostics)
    call assert_true(diagnostics%status == REF_ET_DEMAND_OK, 'cover one status', failures)
    call assert_close(result%potential_transpiration_cm_per_day, 0.5148_real64, 'cover one ptra', failures)
    call assert_close(result%potential_soil_evaporation_cm_per_day, 0.0_real64, 'cover one peva', failures)
    call assert_close(result%potential_pond_evaporation_cm_per_day, 0.0_real64, 'cover one epond', failures)

    forcing%reference_et_mm_per_day = 0.0_real64
    canopy%vegetation_cover_fraction = 0.5_real64
    call evaluate_restricted_reference_et_demand(parameters, forcing, canopy, result, diagnostics)
    call assert_true(diagnostics%status == REF_ET_DEMAND_OK, 'zero ET status', failures)
    call assert_close(result%potential_transpiration_cm_per_day, 0.0_real64, 'zero ET ptra', failures)
    call assert_close(result%potential_soil_evaporation_cm_per_day, 0.0_real64, 'zero ET peva', failures)
    call assert_close(result%potential_pond_evaporation_cm_per_day, 0.0_real64, 'zero ET epond', failures)

    forcing%reference_et_mm_per_day = 5.2_real64
    parameters%pond_evaporation_factor = 0.0_real64
    call evaluate_restricted_reference_et_demand(parameters, forcing, canopy, result, diagnostics)
    call assert_true(diagnostics%status == REF_ET_DEMAND_OK, 'zero pond factor status', failures)
    call assert_close(result%potential_pond_evaporation_cm_per_day, 0.0_real64, 'zero pond factor epond', failures)
  end subroutine test_boundary_cases

  subroutine test_invalid_inputs_fail_closed(failures)
    integer, intent(inout) :: failures
    type(reference_et_demand_parameters_t) :: parameters
    type(reference_et_demand_forcing_t) :: forcing
    type(reference_et_demand_canopy_view_t) :: canopy
    type(reference_et_demand_result_t) :: result
    type(reference_et_demand_diagnostics_t) :: diagnostics

    parameters%pond_evaporation_factor = 1.0_real64
    forcing%reference_et_mm_per_day = -1.0_real64
    canopy%crop_emerged = .true.
    canopy%vegetation_cover_fraction = 0.5_real64
    canopy%crop_factor = 1.0_real64
    canopy%co2_transpiration_factor = 1.0_real64
    call evaluate_restricted_reference_et_demand(parameters, forcing, canopy, result, diagnostics)
    call assert_true(diagnostics%status == REF_ET_DEMAND_INVALID_REFERENCE_ET, 'negative ET rejected', failures)
    call assert_zero_result(result, 'negative ET zero result', failures)

    forcing%reference_et_mm_per_day = 5.0_real64
    canopy%vegetation_cover_fraction = 1.01_real64
    call evaluate_restricted_reference_et_demand(parameters, forcing, canopy, result, diagnostics)
    call assert_true(diagnostics%status == REF_ET_DEMAND_INVALID_COVER, 'cover >1 rejected', failures)
    call assert_zero_result(result, 'invalid cover zero result', failures)

    canopy%vegetation_cover_fraction = 0.5_real64
    parameters%pond_evaporation_factor = -0.1_real64
    call evaluate_restricted_reference_et_demand(parameters, forcing, canopy, result, diagnostics)
    call assert_true(diagnostics%status == REF_ET_DEMAND_INVALID_POND_FACTOR, 'negative pond factor rejected', failures)
    call assert_zero_result(result, 'invalid pond factor zero result', failures)

    parameters%pond_evaporation_factor = 1.0_real64
    canopy%crop_factor = ieee_value(0.0_real64, ieee_quiet_nan)
    call evaluate_restricted_reference_et_demand(parameters, forcing, canopy, result, diagnostics)
    call assert_true(diagnostics%status == REF_ET_DEMAND_INVALID_CROP_FACTOR, 'NaN crop factor rejected', failures)
    call assert_zero_result(result, 'invalid crop factor zero result', failures)

    canopy%crop_factor = 1.0_real64
    canopy%co2_transpiration_factor = -0.1_real64
    call evaluate_restricted_reference_et_demand(parameters, forcing, canopy, result, diagnostics)
    call assert_true(diagnostics%status == REF_ET_DEMAND_INVALID_CO2_FACTOR, 'negative CO2 factor rejected', failures)
    call assert_zero_result(result, 'invalid CO2 factor zero result', failures)
  end subroutine test_invalid_inputs_fail_closed

  subroutine test_stateless_replay(failures)
    integer, intent(inout) :: failures
    type(reference_et_demand_parameters_t) :: parameters_a, parameters_b
    type(reference_et_demand_forcing_t) :: forcing_a, forcing_b
    type(reference_et_demand_canopy_view_t) :: canopy_a, canopy_b
    type(reference_et_demand_result_t) :: result_a1, result_b, result_a2
    type(reference_et_demand_diagnostics_t) :: diagnostics

    parameters_a%pond_evaporation_factor = 1.2_real64
    forcing_a%reference_et_mm_per_day = 5.2_real64
    canopy_a%crop_emerged = .true.
    canopy_a%vegetation_cover_fraction = 0.65_real64
    canopy_a%crop_factor = 1.1_real64
    canopy_a%co2_transpiration_factor = 0.9_real64

    parameters_b%pond_evaporation_factor = 0.7_real64
    forcing_b%reference_et_mm_per_day = 2.3_real64
    canopy_b%crop_emerged = .false.
    canopy_b%vegetation_cover_fraction = 0.1_real64
    canopy_b%crop_factor = 3.0_real64
    canopy_b%co2_transpiration_factor = 4.0_real64

    call evaluate_restricted_reference_et_demand(parameters_a, forcing_a, canopy_a, result_a1, diagnostics)
    call evaluate_restricted_reference_et_demand(parameters_b, forcing_b, canopy_b, result_b, diagnostics)
    call evaluate_restricted_reference_et_demand(parameters_a, forcing_a, canopy_a, result_a2, diagnostics)

    call assert_true(same_bits(result_a1%potential_transpiration_cm_per_day, result_a2%potential_transpiration_cm_per_day), &
                     'A-B-A ptra bits', failures)
    call assert_true(same_bits(result_a1%potential_soil_evaporation_cm_per_day, result_a2%potential_soil_evaporation_cm_per_day), &
                     'A-B-A peva bits', failures)
    call assert_true(same_bits(result_a1%potential_pond_evaporation_cm_per_day, result_a2%potential_pond_evaporation_cm_per_day), &
                     'A-B-A epond bits', failures)
  end subroutine test_stateless_replay

  subroutine assert_zero_result(result, label, failures)
    type(reference_et_demand_result_t), intent(in) :: result
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures

    call assert_close(result%potential_transpiration_cm_per_day, 0.0_real64, trim(label)//' ptra', failures)
    call assert_close(result%potential_soil_evaporation_cm_per_day, 0.0_real64, trim(label)//' peva', failures)
    call assert_close(result%potential_pond_evaporation_cm_per_day, 0.0_real64, trim(label)//' epond', failures)
  end subroutine assert_zero_result

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

end program test_fpm06a_reference_et_demand
