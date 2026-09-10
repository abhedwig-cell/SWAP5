program test_fpm06c_restricted_surface_evaporation
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_restricted_surface_evaporation, only: surface_evaporation_demand_t, &
       surface_evaporation_hydraulic_input_t, surface_evaporation_result_t, &
       SURFACE_EVAP_AVAILABLE, SURFACE_EVAP_INVALID_INPUT, &
       evaluate_restricted_surface_evaporation
  implicit none

  type(surface_evaporation_demand_t) :: d
  type(surface_evaporation_hydraulic_input_t) :: h
  type(surface_evaporation_result_t) :: a, b, a2
  real(real64) :: nanv

  nanv = ieee_value(0.0_real64, ieee_quiet_nan)

  d%bare_soil_demand = 0.40_real64
  d%ponded_water_demand = 0.31_real64
  h%surface_is_ponded = .false.
  h%evaporation_capacity = 0.25_real64
  call evaluate_restricted_surface_evaporation(d, h, a)
  call assert_available(a, 0.25_real64, 0.0_real64, 'dry-capacity-limited')

  h%evaporation_capacity = 0.70_real64
  call evaluate_restricted_surface_evaporation(d, h, b)
  call assert_available(b, 0.40_real64, 0.0_real64, 'dry-demand-limited')

  h%evaporation_capacity = -0.20_real64
  call evaluate_restricted_surface_evaporation(d, h, b)
  call assert_available(b, 0.0_real64, 0.0_real64, 'negative-capacity-clamped')

  h%surface_is_ponded = .true.
  h%evaporation_capacity = 0.01_real64
  call evaluate_restricted_surface_evaporation(d, h, b)
  call assert_available(b, 0.0_real64, 0.31_real64, 'ponded-demand')

  d = surface_evaporation_demand_t()
  h = surface_evaporation_hydraulic_input_t()
  call evaluate_restricted_surface_evaporation(d, h, b)
  call assert_available(b, 0.0_real64, 0.0_real64, 'zero-demand')

  d%bare_soil_demand = 0.40_real64
  d%ponded_water_demand = 0.31_real64
  h%surface_is_ponded = .false.
  h%evaporation_capacity = 0.25_real64
  call evaluate_restricted_surface_evaporation(d, h, a)
  h%surface_is_ponded = .true.
  h%evaporation_capacity = 9.0_real64
  call evaluate_restricted_surface_evaporation(d, h, b)
  h%surface_is_ponded = .false.
  h%evaporation_capacity = 0.25_real64
  call evaluate_restricted_surface_evaporation(d, h, a2)
  call assert_same(a, a2, 'aba-stateless')

  d%bare_soil_demand = nanv
  call evaluate_restricted_surface_evaporation(d, h, b)
  call assert_invalid(b, 'nan-bare-demand')
  d%bare_soil_demand = 0.40_real64
  d%ponded_water_demand = nanv
  call evaluate_restricted_surface_evaporation(d, h, b)
  call assert_invalid(b, 'nan-ponded-demand')
  d%ponded_water_demand = 0.31_real64
  h%evaporation_capacity = nanv
  call evaluate_restricted_surface_evaporation(d, h, b)
  call assert_invalid(b, 'nan-capacity')
  h%evaporation_capacity = 0.25_real64
  d%bare_soil_demand = -0.01_real64
  call evaluate_restricted_surface_evaporation(d, h, b)
  call assert_invalid(b, 'negative-bare-demand')
  d%bare_soil_demand = 0.40_real64
  d%ponded_water_demand = -0.01_real64
  call evaluate_restricted_surface_evaporation(d, h, b)
  call assert_invalid(b, 'negative-ponded-demand')

  write(*,'(a)') 'FPM06C_RESTRICTED_SURFACE_EVAPORATION=PASS'
  write(*,'(a)') 'FPM06C_ABA_STATELESS=PASS'
  write(*,'(a)') 'FPM06C_FAIL_CLOSED_INVALID_INPUT=PASS'

contains

  subroutine fail(label)
    character(len=*), intent(in) :: label
    write(*,'(a)') 'FPM06C_FAIL=' // trim(label)
    error stop 1
  end subroutine fail

  subroutine assert_available(r, expected_reva, expected_epd, label)
    type(surface_evaporation_result_t), intent(in) :: r
    real(real64), intent(in) :: expected_reva, expected_epd
    character(len=*), intent(in) :: label
    if (r%status /= SURFACE_EVAP_AVAILABLE) call fail(label)
    if (transfer(r%bare_soil_evaporation, 0_int64) /= transfer(expected_reva, 0_int64)) call fail(label)
    if (transfer(r%ponded_water_evaporation, 0_int64) /= transfer(expected_epd, 0_int64)) call fail(label)
  end subroutine assert_available

  subroutine assert_invalid(r, label)
    type(surface_evaporation_result_t), intent(in) :: r
    character(len=*), intent(in) :: label
    if (r%status /= SURFACE_EVAP_INVALID_INPUT) call fail(label)
    if (transfer(r%bare_soil_evaporation, 0_int64) /= transfer(0.0_real64, 0_int64)) call fail(label)
    if (transfer(r%ponded_water_evaporation, 0_int64) /= transfer(0.0_real64, 0_int64)) call fail(label)
  end subroutine assert_invalid

  subroutine assert_same(x, y, label)
    type(surface_evaporation_result_t), intent(in) :: x, y
    character(len=*), intent(in) :: label
    if (x%status /= y%status) call fail(label)
    if (x%route /= y%route) call fail(label)
    if (transfer(x%bare_soil_evaporation, 0_int64) /= transfer(y%bare_soil_evaporation, 0_int64)) call fail(label)
    if (transfer(x%ponded_water_evaporation, 0_int64) /= transfer(y%ponded_water_evaporation, 0_int64)) call fail(label)
  end subroutine assert_same

end program test_fpm06c_restricted_surface_evaporation
