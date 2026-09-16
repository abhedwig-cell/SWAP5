program test_fwof43a_crop_et_canopy_view_provider
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_crop_et_canopy_view_provider
  implicit none

  integer :: failures

  failures = 0
  call test_active_source_equations(failures)
  call test_nonemerged_dependency_minimality(failures)
  call test_co2_disabled_forcing_independence(failures)
  call test_afgen_endpoint_semantics(failures)
  call test_invalid_domains_fail_closed(failures)
  call test_stateless_replay(failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'FWO43A_FAILURE_COUNT=', failures
    error stop 1
  end if

  write(*,'(A)') 'FWO43A_B110_VCOVER_FORMULA=PASS'
  write(*,'(A)') 'FWO43A_B110_CF_AFGEN=PASS'
  write(*,'(A)') 'FWO43A_B110_FCO2TRA_AFGEN=PASS'
  write(*,'(A)') 'FWO43A_NONEMERGED_NONZERO_VCOVER=PASS'
  write(*,'(A)') 'FWO43A_INACTIVE_DEPENDENCIES_MINIMAL=PASS'
  write(*,'(A)') 'FWO43A_CO2_DISABLED_FORCING_INDEPENDENCE=PASS'
  write(*,'(A)') 'FWO43A_AFGEN_ENDPOINT_CLAMP=PASS'
  write(*,'(A)') 'FWO43A_FAIL_CLOSED_ACTIVE_DOMAIN=PASS'
  write(*,'(A)') 'FWO43A_STATELESS_A_B_A_IDENTITY=PASS'
  write(*,'(A)') 'FWO43A_CROP_ET_CANOPY_VIEW_TEST PASS'

contains

  subroutine test_active_source_equations(failures)
    integer, intent(inout) :: failures
    type(crop_et_canopy_parameters_t) :: parameters
    type(crop_et_canopy_state_view_t) :: state
    type(crop_et_canopy_forcing_t) :: forcing
    type(crop_et_canopy_view_t) :: view
    type(crop_et_canopy_diagnostics_t) :: diagnostics
    integer :: status
    real(real64), dimension(3) :: cfx, cfy, co2x, co2y
    real(real64) :: expected_cover, expected_cf, expected_co2

    cfx = [0.0_real64, 1.0_real64, 2.0_real64]
    cfy = [0.8_real64, 1.1_real64, 0.9_real64]
    co2x = [300.0_real64, 600.0_real64, 900.0_real64]
    co2y = [1.0_real64, 0.9_real64, 0.8_real64]
    call construct_crop_et_canopy_parameters(0.8_real64, 0.6_real64, cfx, cfy, .true., &
                                             parameters, status, co2x, co2y)
    call assert_true(status == CROP_ET_CANOPY_OK, 'active construct', failures)

    state%crop_emerged = .true.
    state%development_stage = 0.5_real64
    state%leaf_area_index = 2.0_real64
    forcing%atmospheric_co2_ppm = 450.0_real64

    call evaluate_crop_et_canopy_view(parameters, state, forcing, view, diagnostics)

    expected_cover = 1.0_real64 - exp(-0.8_real64 * 0.6_real64 * 2.0_real64)
    expected_cf = 0.8_real64 + (0.5_real64 - 0.0_real64) * &
                  ((1.1_real64 - 0.8_real64) / (1.0_real64 - 0.0_real64))
    expected_co2 = 1.0_real64 + (450.0_real64 - 300.0_real64) * &
                   ((0.9_real64 - 1.0_real64) / (600.0_real64 - 300.0_real64))

    call assert_true(diagnostics%status == CROP_ET_CANOPY_OK, 'active status', failures)
    call assert_true(diagnostics%state_consumed, 'active state consumed', failures)
    call assert_true(diagnostics%crop_factor_table_consumed, 'active CF table', failures)
    call assert_true(diagnostics%co2_forcing_consumed, 'active CO2 forcing', failures)
    call assert_true(diagnostics%co2_table_consumed, 'active CO2 table', failures)
    call assert_true(diagnostics%result_produced, 'active result', failures)
    call assert_true(view%crop_emerged, 'active emerged', failures)
    call assert_true(view%crop_specific_factors_valid, 'active factors valid', failures)
    call assert_close(view%vegetation_cover_fraction, expected_cover, 'active cover', failures)
    call assert_close(view%crop_factor, expected_cf, 'active CF', failures)
    call assert_close(view%co2_transpiration_factor, expected_co2, 'active CO2 factor', failures)
  end subroutine test_active_source_equations

  subroutine test_nonemerged_dependency_minimality(failures)
    integer, intent(inout) :: failures
    type(crop_et_canopy_parameters_t) :: parameters
    type(crop_et_canopy_state_view_t) :: state
    type(crop_et_canopy_forcing_t) :: forcing
    type(crop_et_canopy_view_t) :: view
    type(crop_et_canopy_diagnostics_t) :: diagnostics
    integer :: status
    real(real64), dimension(2) :: cfx, cfy, co2x, co2y
    real(real64) :: expected_cover, nan_value

    cfx = [0.0_real64, 2.0_real64]
    cfy = [0.7_real64, 1.2_real64]
    co2x = [300.0_real64, 900.0_real64]
    co2y = [1.0_real64, 0.8_real64]
    call construct_crop_et_canopy_parameters(0.9_real64, 0.5_real64, cfx, cfy, .true., &
                                             parameters, status, co2x, co2y)
    call assert_true(status == CROP_ET_CANOPY_OK, 'inactive construct', failures)

    nan_value = ieee_value(0.0_real64, ieee_quiet_nan)
    state%crop_emerged = .false.
    state%development_stage = nan_value
    state%leaf_area_index = 1.4_real64
    forcing%atmospheric_co2_ppm = nan_value

    call evaluate_crop_et_canopy_view(parameters, state, forcing, view, diagnostics)

    expected_cover = 1.0_real64 - exp(-0.9_real64 * 0.5_real64 * 1.4_real64)
    call assert_true(diagnostics%status == CROP_ET_CANOPY_OK, 'inactive status', failures)
    call assert_true(diagnostics%state_consumed, 'inactive LAI consumed', failures)
    call assert_true(.not. diagnostics%crop_factor_table_consumed, 'inactive CF skipped', failures)
    call assert_true(.not. diagnostics%co2_forcing_consumed, 'inactive CO2 forcing skipped', failures)
    call assert_true(.not. diagnostics%co2_table_consumed, 'inactive CO2 table skipped', failures)
    call assert_true(diagnostics%result_produced, 'inactive result', failures)
    call assert_true(.not. view%crop_specific_factors_valid, 'inactive factors invalid', failures)
    call assert_close(view%vegetation_cover_fraction, expected_cover, 'inactive nonzero cover', failures)
    call assert_close(view%crop_factor, 0.0_real64, 'inactive CF canonical', failures)
    call assert_close(view%co2_transpiration_factor, 1.0_real64, 'inactive CO2 canonical', failures)
  end subroutine test_nonemerged_dependency_minimality

  subroutine test_co2_disabled_forcing_independence(failures)
    integer, intent(inout) :: failures
    type(crop_et_canopy_parameters_t) :: parameters
    type(crop_et_canopy_state_view_t) :: state
    type(crop_et_canopy_forcing_t) :: forcing
    type(crop_et_canopy_view_t) :: view
    type(crop_et_canopy_diagnostics_t) :: diagnostics
    integer :: status
    real(real64), dimension(2) :: cfx, cfy

    cfx = [0.0_real64, 2.0_real64]
    cfy = [0.8_real64, 1.0_real64]
    call construct_crop_et_canopy_parameters(0.7_real64, 0.6_real64, cfx, cfy, .false., &
                                             parameters, status)
    call assert_true(status == CROP_ET_CANOPY_OK, 'CO2 off construct', failures)
    call assert_true(.not. parameters%co2_enabled(), 'CO2 off flag', failures)

    state%crop_emerged = .true.
    state%development_stage = 1.0_real64
    state%leaf_area_index = 2.0_real64
    forcing%atmospheric_co2_ppm = ieee_value(0.0_real64, ieee_quiet_nan)
    call evaluate_crop_et_canopy_view(parameters, state, forcing, view, diagnostics)

    call assert_true(diagnostics%status == CROP_ET_CANOPY_OK, 'CO2 off status', failures)
    call assert_true(.not. diagnostics%co2_forcing_consumed, 'CO2 off forcing skipped', failures)
    call assert_true(.not. diagnostics%co2_table_consumed, 'CO2 off table skipped', failures)
    call assert_close(view%co2_transpiration_factor, 1.0_real64, 'CO2 off factor', failures)
  end subroutine test_co2_disabled_forcing_independence

  subroutine test_afgen_endpoint_semantics(failures)
    integer, intent(inout) :: failures
    type(crop_et_canopy_parameters_t) :: parameters
    type(crop_et_canopy_state_view_t) :: state
    type(crop_et_canopy_forcing_t) :: forcing
    type(crop_et_canopy_view_t) :: view
    type(crop_et_canopy_diagnostics_t) :: diagnostics
    integer :: status
    real(real64), dimension(3) :: cfx, cfy

    cfx = [0.0_real64, 1.0_real64, 2.0_real64]
    cfy = [0.75_real64, 1.05_real64, 0.85_real64]
    call construct_crop_et_canopy_parameters(0.8_real64, 0.6_real64, cfx, cfy, .false., &
                                             parameters, status)
    call assert_true(status == CROP_ET_CANOPY_OK, 'endpoint construct', failures)

    state%crop_emerged = .true.
    state%leaf_area_index = 1.0_real64
    state%development_stage = -0.25_real64
    call evaluate_crop_et_canopy_view(parameters, state, forcing, view, diagnostics)
    call assert_true(diagnostics%status == CROP_ET_CANOPY_OK, 'low endpoint status', failures)
    call assert_close(view%crop_factor, 0.75_real64, 'low endpoint clamp', failures)

    state%development_stage = 2.5_real64
    call evaluate_crop_et_canopy_view(parameters, state, forcing, view, diagnostics)
    call assert_true(diagnostics%status == CROP_ET_CANOPY_OK, 'high endpoint status', failures)
    call assert_close(view%crop_factor, 0.85_real64, 'high endpoint clamp', failures)
  end subroutine test_afgen_endpoint_semantics

  subroutine test_invalid_domains_fail_closed(failures)
    integer, intent(inout) :: failures
    type(crop_et_canopy_parameters_t) :: parameters
    type(crop_et_canopy_state_view_t) :: state
    type(crop_et_canopy_forcing_t) :: forcing
    type(crop_et_canopy_view_t) :: view
    type(crop_et_canopy_diagnostics_t) :: diagnostics
    integer :: status
    real(real64), dimension(2) :: cfx, cfy, badx, co2x, co2y

    cfx = [0.0_real64, 2.0_real64]
    cfy = [0.8_real64, 1.0_real64]
    co2x = [300.0_real64, 900.0_real64]
    co2y = [1.0_real64, 0.8_real64]

    call construct_crop_et_canopy_parameters(2.1_real64, 0.6_real64, cfx, cfy, .false., &
                                             parameters, status)
    call assert_true(status == CROP_ET_CANOPY_INVALID_PARAMETER, 'KDIR >2 rejected', failures)

    badx = [1.0_real64, 0.0_real64]
    call construct_crop_et_canopy_parameters(0.8_real64, 0.6_real64, badx, cfy, .false., &
                                             parameters, status)
    call assert_true(status == CROP_ET_CANOPY_INVALID_TABLE, 'unordered CFTB rejected', failures)

    call construct_crop_et_canopy_parameters(0.8_real64, 0.6_real64, cfx, cfy, .true., &
                                             parameters, status)
    call assert_true(status == CROP_ET_CANOPY_INVALID_TABLE, 'missing CO2TB rejected', failures)

    call construct_crop_et_canopy_parameters(0.8_real64, 0.6_real64, cfx, cfy, .true., &
                                             parameters, status, co2x, co2y)
    call assert_true(status == CROP_ET_CANOPY_OK, 'invalid-test construct', failures)

    state%crop_emerged = .true.
    state%development_stage = 1.0_real64
    state%leaf_area_index = ieee_value(0.0_real64, ieee_quiet_nan)
    forcing%atmospheric_co2_ppm = 450.0_real64
    call evaluate_crop_et_canopy_view(parameters, state, forcing, view, diagnostics)
    call assert_true(diagnostics%status == CROP_ET_CANOPY_INVALID_STATE, 'NaN LAI rejected', failures)
    call assert_zero_failed_view(view, 'NaN LAI zero', failures)

    state%leaf_area_index = 1.0_real64
    state%development_stage = ieee_value(0.0_real64, ieee_quiet_nan)
    call evaluate_crop_et_canopy_view(parameters, state, forcing, view, diagnostics)
    call assert_true(diagnostics%status == CROP_ET_CANOPY_INVALID_STATE, 'active NaN DVS rejected', failures)
    call assert_zero_failed_view(view, 'NaN DVS zero', failures)

    state%development_stage = 1.0_real64
    forcing%atmospheric_co2_ppm = 9.0_real64
    call evaluate_crop_et_canopy_view(parameters, state, forcing, view, diagnostics)
    call assert_true(diagnostics%status == CROP_ET_CANOPY_INVALID_CO2_FORCING, 'CO2 below legacy domain rejected', failures)
    call assert_zero_failed_view(view, 'bad CO2 zero', failures)
  end subroutine test_invalid_domains_fail_closed

  subroutine test_stateless_replay(failures)
    integer, intent(inout) :: failures
    type(crop_et_canopy_parameters_t) :: parameters
    type(crop_et_canopy_state_view_t) :: state_a, state_b
    type(crop_et_canopy_forcing_t) :: forcing
    type(crop_et_canopy_view_t) :: a1, b, a2
    type(crop_et_canopy_diagnostics_t) :: diagnostics
    integer :: status
    real(real64), dimension(2) :: cfx, cfy

    cfx = [0.0_real64, 2.0_real64]
    cfy = [0.8_real64, 1.2_real64]
    call construct_crop_et_canopy_parameters(0.9_real64, 0.4_real64, cfx, cfy, .false., &
                                             parameters, status)
    call assert_true(status == CROP_ET_CANOPY_OK, 'ABA construct', failures)

    state_a%crop_emerged = .true.
    state_a%development_stage = 0.6_real64
    state_a%leaf_area_index = 1.8_real64
    state_b%crop_emerged = .false.
    state_b%development_stage = 1.8_real64
    state_b%leaf_area_index = 0.2_real64

    call evaluate_crop_et_canopy_view(parameters, state_a, forcing, a1, diagnostics)
    call evaluate_crop_et_canopy_view(parameters, state_b, forcing, b, diagnostics)
    call evaluate_crop_et_canopy_view(parameters, state_a, forcing, a2, diagnostics)

    call assert_true(a1%crop_emerged .eqv. a2%crop_emerged, 'ABA emergence', failures)
    call assert_true(a1%crop_specific_factors_valid .eqv. a2%crop_specific_factors_valid, 'ABA validity', failures)
    call assert_true(same_bits(a1%vegetation_cover_fraction, a2%vegetation_cover_fraction), 'ABA cover bits', failures)
    call assert_true(same_bits(a1%crop_factor, a2%crop_factor), 'ABA CF bits', failures)
    call assert_true(same_bits(a1%co2_transpiration_factor, a2%co2_transpiration_factor), 'ABA CO2 bits', failures)
  end subroutine test_stateless_replay

  subroutine assert_zero_failed_view(view, label, failures)
    type(crop_et_canopy_view_t), intent(in) :: view
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    call assert_true(.not. view%crop_emerged, trim(label)//' emerged', failures)
    call assert_true(.not. view%crop_specific_factors_valid, trim(label)//' valid', failures)
    call assert_close(view%vegetation_cover_fraction, 0.0_real64, trim(label)//' cover', failures)
    call assert_close(view%crop_factor, 0.0_real64, trim(label)//' CF', failures)
    call assert_close(view%co2_transpiration_factor, 0.0_real64, trim(label)//' CO2', failures)
  end subroutine assert_zero_failed_view

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

end program test_fwof43a_crop_et_canopy_view_provider
