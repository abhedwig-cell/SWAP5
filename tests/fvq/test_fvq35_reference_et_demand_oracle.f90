program test_fvq35_reference_et_demand_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_reference_et_demand_process
  implicit none

  real(real64), parameter :: etr_values(5) = [0.0_real64, 0.1_real64, 0.7_real64, 5.2_real64, 14.0_real64]
  real(real64), parameter :: cover_values(5) = [0.0_real64, 0.05_real64, 0.5_real64, 0.95_real64, 1.0_real64]
  real(real64), parameter :: pond_values(4) = [0.0_real64, 0.4_real64, 1.0_real64, 2.0_real64]
  real(real64), parameter :: crop_factor_values(4) = [0.0_real64, 0.3_real64, 1.0_real64, 1.7_real64]
  real(real64), parameter :: co2_values(4) = [0.0_real64, 0.6_real64, 1.0_real64, 1.4_real64]

  integer :: failures, case_count

  failures = 0
  case_count = 0

  call run_independent_grid(failures, case_count)
  call verify_unit_conversion(failures)
  call verify_nonemerged_dependency_semantics(failures)
  call verify_fail_closed_active_domain(failures)
  call verify_stateless_replay(failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'FVQ35_FAILURE_COUNT=', failures
    error stop 1
  end if

  write(*,'(A,I0)') 'FVQ35_INDEPENDENT_GRID_CASES=', case_count
  write(*,'(A)') 'FVQ35_INDEPENDENT_B110_EQUATION_ORACLE=PASS'
  write(*,'(A)') 'FVQ35_MM_TO_CM_UNIT_CONVERSION=PASS'
  write(*,'(A)') 'FVQ35_NONEMERGED_VCOVER_SEMANTICS=PASS'
  write(*,'(A)') 'FVQ35_INACTIVE_CROP_FACTOR_DEPENDENCY=PASS'
  write(*,'(A)') 'FVQ35_FAIL_CLOSED_ACTIVE_DOMAIN=PASS'
  write(*,'(A)') 'FVQ35_STATELESS_REPLAY=PASS'
  write(*,'(A)') 'FVQ35_REFERENCE_ET_SCIENTIFIC_ORACLE PASS'

contains

  subroutine run_independent_grid(failures, case_count)
    integer, intent(inout) :: failures, case_count
    type(reference_et_demand_parameters_t) :: parameters
    type(reference_et_demand_forcing_t) :: forcing
    type(reference_et_demand_canopy_view_t) :: canopy
    type(reference_et_demand_result_t) :: result
    type(reference_et_demand_diagnostics_t) :: diagnostics
    integer :: i, j, k, l, m

    do i = 1, size(etr_values)
      forcing%reference_et_mm_per_day = etr_values(i)
      do j = 1, size(cover_values)
        canopy%vegetation_cover_fraction = cover_values(j)
        do k = 1, size(pond_values)
          parameters%pond_evaporation_factor = pond_values(k)

          canopy%crop_emerged = .false.
          canopy%crop_factor = 9.0_real64
          canopy%co2_transpiration_factor = 8.0_real64
          call evaluate_restricted_reference_et_demand(parameters, forcing, canopy, result, diagnostics)
          case_count = case_count + 1
          call assert_true(diagnostics%status == REF_ET_DEMAND_OK, 'grid inactive status', failures)
          call assert_close(result%potential_soil_evaporation_cm_per_day, &
                            legacy_peva(etr_values(i), cover_values(j)), 'grid inactive peva', failures)
          call assert_close(result%potential_pond_evaporation_cm_per_day, &
                            legacy_epond(etr_values(i), cover_values(j), pond_values(k)), 'grid inactive epond', failures)
          call assert_close(result%potential_transpiration_cm_per_day, 0.0_real64, 'grid inactive ptra', failures)

          canopy%crop_emerged = .true.
          do l = 1, size(crop_factor_values)
            canopy%crop_factor = crop_factor_values(l)
            do m = 1, size(co2_values)
              canopy%co2_transpiration_factor = co2_values(m)
              call evaluate_restricted_reference_et_demand(parameters, forcing, canopy, result, diagnostics)
              case_count = case_count + 1
              call assert_true(diagnostics%status == REF_ET_DEMAND_OK, 'grid active status', failures)
              call assert_close(result%potential_soil_evaporation_cm_per_day, &
                                legacy_peva(etr_values(i), cover_values(j)), 'grid active peva', failures)
              call assert_close(result%potential_pond_evaporation_cm_per_day, &
                                legacy_epond(etr_values(i), cover_values(j), pond_values(k)), 'grid active epond', failures)
              call assert_close(result%potential_transpiration_cm_per_day, &
                                legacy_ptra(etr_values(i), cover_values(j), crop_factor_values(l), co2_values(m)), &
                                'grid active ptra', failures)
            end do
          end do
        end do
      end do
    end do
  end subroutine run_independent_grid

  subroutine verify_unit_conversion(failures)
    integer, intent(inout) :: failures
    type(reference_et_demand_parameters_t) :: parameters
    type(reference_et_demand_forcing_t) :: forcing
    type(reference_et_demand_canopy_view_t) :: canopy
    type(reference_et_demand_result_t) :: result
    type(reference_et_demand_diagnostics_t) :: diagnostics

    parameters%pond_evaporation_factor = 1.0_real64
    forcing%reference_et_mm_per_day = 10.0_real64

    canopy%crop_emerged = .false.
    canopy%vegetation_cover_fraction = 0.0_real64
    call evaluate_restricted_reference_et_demand(parameters, forcing, canopy, result, diagnostics)
    call assert_true(diagnostics%status == REF_ET_DEMAND_OK, 'unit surface status', failures)
    call assert_close(result%potential_soil_evaporation_cm_per_day, 1.0_real64, '10 mm soil to 1 cm', failures)
    call assert_close(result%potential_pond_evaporation_cm_per_day, 1.0_real64, '10 mm pond to 1 cm', failures)

    canopy%crop_emerged = .true.
    canopy%vegetation_cover_fraction = 1.0_real64
    canopy%crop_factor = 1.0_real64
    canopy%co2_transpiration_factor = 1.0_real64
    call evaluate_restricted_reference_et_demand(parameters, forcing, canopy, result, diagnostics)
    call assert_true(diagnostics%status == REF_ET_DEMAND_OK, 'unit transpiration status', failures)
    call assert_close(result%potential_transpiration_cm_per_day, 1.0_real64, '10 mm transpiration to 1 cm', failures)
  end subroutine verify_unit_conversion

  subroutine verify_nonemerged_dependency_semantics(failures)
    integer, intent(inout) :: failures
    type(reference_et_demand_parameters_t) :: parameters
    type(reference_et_demand_forcing_t) :: forcing
    type(reference_et_demand_canopy_view_t) :: canopy
    type(reference_et_demand_result_t) :: result
    type(reference_et_demand_diagnostics_t) :: diagnostics

    parameters%pond_evaporation_factor = 1.5_real64
    forcing%reference_et_mm_per_day = 6.0_real64
    canopy%crop_emerged = .false.
    canopy%vegetation_cover_fraction = 0.25_real64
    canopy%crop_factor = ieee_value(0.0_real64, ieee_quiet_nan)
    canopy%co2_transpiration_factor = ieee_value(0.0_real64, ieee_quiet_nan)

    call evaluate_restricted_reference_et_demand(parameters, forcing, canopy, result, diagnostics)

    call assert_true(diagnostics%status == REF_ET_DEMAND_OK, 'nonemerged NaN crop factors ignored', failures)
    call assert_true(.not. diagnostics%crop_specific_factors_consumed, 'nonemerged factors not consumed', failures)
    call assert_close(result%potential_transpiration_cm_per_day, 0.0_real64, 'nonemerged ptra zero', failures)
    call assert_close(result%potential_soil_evaporation_cm_per_day, 0.45_real64, 'nonemerged vcover peva', failures)
    call assert_close(result%potential_pond_evaporation_cm_per_day, 0.675_real64, 'nonemerged vcover epond', failures)
  end subroutine verify_nonemerged_dependency_semantics

  subroutine verify_fail_closed_active_domain(failures)
    integer, intent(inout) :: failures
    type(reference_et_demand_parameters_t) :: parameters
    type(reference_et_demand_forcing_t) :: forcing
    type(reference_et_demand_canopy_view_t) :: canopy
    type(reference_et_demand_result_t) :: result
    type(reference_et_demand_diagnostics_t) :: diagnostics

    parameters%pond_evaporation_factor = 1.0_real64
    forcing%reference_et_mm_per_day = 5.0_real64
    canopy%crop_emerged = .true.
    canopy%vegetation_cover_fraction = 0.5_real64
    canopy%crop_factor = ieee_value(0.0_real64, ieee_quiet_nan)
    canopy%co2_transpiration_factor = 1.0_real64

    call evaluate_restricted_reference_et_demand(parameters, forcing, canopy, result, diagnostics)

    call assert_true(diagnostics%status == REF_ET_DEMAND_INVALID_CROP_FACTOR, 'active NaN crop factor rejected', failures)
    call assert_true(.not. diagnostics%result_produced, 'active invalid result not published', failures)
    call assert_close(result%potential_transpiration_cm_per_day, 0.0_real64, 'active invalid ptra zero', failures)
    call assert_close(result%potential_soil_evaporation_cm_per_day, 0.0_real64, 'active invalid peva zero', failures)
    call assert_close(result%potential_pond_evaporation_cm_per_day, 0.0_real64, 'active invalid epond zero', failures)
  end subroutine verify_fail_closed_active_domain

  subroutine verify_stateless_replay(failures)
    integer, intent(inout) :: failures
    type(reference_et_demand_parameters_t) :: parameters_a, parameters_b
    type(reference_et_demand_forcing_t) :: forcing_a, forcing_b
    type(reference_et_demand_canopy_view_t) :: canopy_a, canopy_b
    type(reference_et_demand_result_t) :: result_a1, result_b, result_a2
    type(reference_et_demand_diagnostics_t) :: diagnostics

    parameters_a%pond_evaporation_factor = 1.35_real64
    forcing_a%reference_et_mm_per_day = 7.25_real64
    canopy_a%crop_emerged = .true.
    canopy_a%vegetation_cover_fraction = 0.61_real64
    canopy_a%crop_factor = 0.92_real64
    canopy_a%co2_transpiration_factor = 1.08_real64

    parameters_b%pond_evaporation_factor = 0.2_real64
    forcing_b%reference_et_mm_per_day = 1.75_real64
    canopy_b%crop_emerged = .false.
    canopy_b%vegetation_cover_fraction = 0.12_real64
    canopy_b%crop_factor = 4.0_real64
    canopy_b%co2_transpiration_factor = 5.0_real64

    call evaluate_restricted_reference_et_demand(parameters_a, forcing_a, canopy_a, result_a1, diagnostics)
    call evaluate_restricted_reference_et_demand(parameters_b, forcing_b, canopy_b, result_b, diagnostics)
    call evaluate_restricted_reference_et_demand(parameters_a, forcing_a, canopy_a, result_a2, diagnostics)

    call assert_true(same_bits(result_a1%potential_transpiration_cm_per_day, result_a2%potential_transpiration_cm_per_day), &
                     'replay ptra bits', failures)
    call assert_true(same_bits(result_a1%potential_soil_evaporation_cm_per_day, result_a2%potential_soil_evaporation_cm_per_day), &
                     'replay peva bits', failures)
    call assert_true(same_bits(result_a1%potential_pond_evaporation_cm_per_day, result_a2%potential_pond_evaporation_cm_per_day), &
                     'replay epond bits', failures)
  end subroutine verify_stateless_replay

  pure real(real64) function legacy_peva(etr, vcover) result(value)
    real(real64), intent(in) :: etr, vcover
    real(real64) :: es0
    es0 = etr * (1.0_real64 - vcover)
    value = max(0.0_real64, es0 * 0.1_real64)
  end function legacy_peva

  pure real(real64) function legacy_epond(etr, vcover, cfevappond) result(value)
    real(real64), intent(in) :: etr, vcover, cfevappond
    real(real64) :: ep0
    ep0 = etr * (1.0_real64 - vcover) * cfevappond
    value = max(0.0_real64, ep0 * 0.1_real64)
  end function legacy_epond

  pure real(real64) function legacy_ptra(etr, vcover, crop_factor, co2_factor) result(value)
    real(real64), intent(in) :: etr, vcover, crop_factor, co2_factor
    real(real64) :: et0, ptra_dry
    et0 = etr * vcover * crop_factor
    ptra_dry = max(et0 * 0.1_real64, 0.0_real64)
    value = co2_factor * ptra_dry
  end function legacy_ptra

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
    tolerance = 256.0_real64 * epsilon(1.0_real64) * max(1.0_real64, abs(expected))
    if (abs(actual - expected) > tolerance) then
      failures = failures + 1
      write(*,'(A,A,2(1X,ES24.16))') 'FAIL ', trim(label), actual, expected
    end if
  end subroutine assert_close

  logical function same_bits(a, b) result(equal)
    real(real64), intent(in) :: a, b
    equal = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function same_bits

end program test_fvq35_reference_et_demand_oracle
