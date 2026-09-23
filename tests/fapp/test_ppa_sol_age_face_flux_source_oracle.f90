program test_ppa_sol_age_face_flux_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_sol_age_face_flux
  implicit none

  integer, parameter :: vector_count = 100000
  integer(int64) :: state
  integer :: i, status
  real(real64) :: q, mobile_age, theta, dispersion, age_right, age_left, distance, dt, expected, actual, nan_value

  state = 20260923_int64
  do i = 1, vector_count
    q = -5.0_real64 + 10.0_real64 * next_unit(state)
    mobile_age = 25.0_real64 * next_unit(state)
    theta = 0.05_real64 + 0.55_real64 * next_unit(state)
    dispersion = 3.0_real64 * next_unit(state)
    age_right = 25.0_real64 * next_unit(state)
    age_left = 25.0_real64 * next_unit(state)
    distance = 0.05_real64 + 5.0_real64 * next_unit(state)
    dt = 0.001_real64 + 0.25_real64 * next_unit(state)
    if (mod(i, 4) == 0) age_right = age_left
    if (mod(i, 4) == 1) dispersion = 0.0_real64

    call source_age_face_flux(q, mobile_age, theta, dispersion, age_right, age_left, distance, dt, expected)
    call ppa_sol_age_face_flux_amount(q, mobile_age, theta, dispersion, age_right, age_left, distance, dt, actual, status)
    call require(status == PPA_SOL_AGE_FACE_OK, 1)
    call compare_real(expected, actual, 2)
  end do

  write(*,'(a)') 'PPA_SOL_AGE_FACE_B1_11_SOURCE_ORACLE_100000=PASS'
  write(*,'(a)') 'PPA_SOL_AGE_FACE_ADVECTION_DISPERSION_AMOUNT=PASS'

  nan_value = ieee_value(0.0_real64, ieee_quiet_nan)
  call ppa_sol_age_face_flux_amount(1.0_real64, 1.0_real64, nan_value, 1.0_real64, 2.0_real64, &
       1.0_real64, 1.0_real64, 0.1_real64, actual, status)
  call require(status == PPA_SOL_AGE_FACE_INVALID_INPUT, 3)
  call ppa_sol_age_face_flux_amount(1.0_real64, 1.0_real64, 0.5_real64, -0.1_real64, 2.0_real64, &
       1.0_real64, 1.0_real64, 0.1_real64, actual, status)
  call require(status == PPA_SOL_AGE_FACE_INVALID_INPUT, 4)
  call ppa_sol_age_face_flux_amount(1.0_real64, 1.0_real64, 0.5_real64, 0.1_real64, 2.0_real64, &
       1.0_real64, 0.0_real64, 0.1_real64, actual, status)
  call require(status == PPA_SOL_AGE_FACE_INVALID_INPUT, 5)
  write(*,'(a)') 'PPA_SOL_AGE_FACE_INVALID_INPUT_FAIL_CLOSED=PASS'

contains

  real(real64) function next_unit(random_state) result(value)
    integer(int64), intent(inout) :: random_state
    random_state = modulo(random_state * 48271_int64, 2147483647_int64)
    value = real(modulo(random_state, 1000000_int64), real64) / 1000000.0_real64
  end function next_unit

  subroutine source_age_face_flux(water_flux, mobile_face_age, water_content, dispersion_coefficient, &
       age_concentration_right, age_concentration_left, distance_between_nodes, step, age_amount)
    real(real64), intent(in) :: water_flux, mobile_face_age, water_content, dispersion_coefficient
    real(real64), intent(in) :: age_concentration_right, age_concentration_left, distance_between_nodes, step
    real(real64), intent(out) :: age_amount
    age_amount = (water_flux * mobile_face_age + water_content * dispersion_coefficient * &
         (age_concentration_right - age_concentration_left) / distance_between_nodes) * step
  end subroutine source_age_face_flux

  subroutine compare_real(expected_value, actual_value, code)
    real(real64), intent(in) :: expected_value, actual_value
    integer, intent(in) :: code
    integer(int64) :: expected_bits, actual_bits
    expected_bits = transfer(expected_value, expected_bits)
    actual_bits = transfer(actual_value, actual_bits)
    call require(expected_bits == actual_bits, code)
  end subroutine compare_real

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (condition) return
    write(*,'(a,i0)') 'PPA_SOL_AGE_FACE_FAIL=', code
    error stop 1
  end subroutine require

end program test_ppa_sol_age_face_flux_source_oracle
