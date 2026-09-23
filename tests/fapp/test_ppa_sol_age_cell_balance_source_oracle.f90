program test_ppa_sol_age_cell_balance_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_sol_age_cell_balance
  implicit none

  integer, parameter :: vector_count = 100000
  integer(int64) :: state
  integer :: i, status
  real(real64) :: old_storage, bottom, top, dz, theta, theta_old, root_rate, lateral_rate, dt
  real(real64) :: expected_storage, expected_concentration, actual_storage, actual_concentration, nan_value

  state = 20260923_int64
  do i = 1, vector_count
    old_storage = 8.0_real64 * next_unit(state)
    bottom = -0.08_real64 + 0.16_real64 * next_unit(state)
    top = -0.08_real64 + 0.16_real64 * next_unit(state)
    dz = 0.05_real64 + 5.0_real64 * next_unit(state)
    theta = 0.05_real64 + 0.55_real64 * next_unit(state)
    theta_old = 0.05_real64 + 0.55_real64 * next_unit(state)
    root_rate = 0.15_real64 * next_unit(state)
    lateral_rate = 0.15_real64 * next_unit(state)
    dt = 0.001_real64 + 0.25_real64 * next_unit(state)
    if (mod(i, 4) == 0) top = bottom
    if (mod(i, 4) == 1) root_rate = 0.0_real64

    call source_age_cell_update(old_storage, bottom, top, dz, theta, theta_old, root_rate, lateral_rate, dt, &
         expected_storage, expected_concentration)
    call ppa_sol_age_cell_candidate(old_storage, bottom, top, dz, theta, theta_old, root_rate, lateral_rate, dt, &
         actual_storage, actual_concentration, status)
    call require(status == PPA_SOL_AGE_CELL_OK, 1)
    call compare_real(expected_storage, actual_storage, 2)
    call compare_real(expected_concentration, actual_concentration, 3)
  end do

  write(*,'(a)') 'PPA_SOL_AGE_CELL_B1_11_SOURCE_ORACLE_100000=PASS'
  write(*,'(a)') 'PPA_SOL_AGE_CELL_ZERO_ORDER_PRODUCTION_AND_FACE_SINK_BALANCE=PASS'

  nan_value = ieee_value(0.0_real64, ieee_quiet_nan)
  call ppa_sol_age_cell_candidate(1.0_real64, 0.1_real64, 0.0_real64, 0.0_real64, theta, theta_old, &
       root_rate, lateral_rate, dt, actual_storage, actual_concentration, status)
  call require(status == PPA_SOL_AGE_CELL_INVALID_INPUT, 4)
  call ppa_sol_age_cell_candidate(1.0_real64, 0.1_real64, 0.0_real64, 1.0_real64, nan_value, theta_old, &
       root_rate, lateral_rate, dt, actual_storage, actual_concentration, status)
  call require(status == PPA_SOL_AGE_CELL_INVALID_INPUT, 5)
  call ppa_sol_age_cell_candidate(1.0_real64, 0.1_real64, 0.0_real64, 1.0_real64, 0.2_real64, theta_old, &
       root_rate, lateral_rate, 0.0_real64, actual_storage, actual_concentration, status)
  call require(status == PPA_SOL_AGE_CELL_INVALID_INPUT, 6)
  write(*,'(a)') 'PPA_SOL_AGE_CELL_INVALID_INPUT_FAIL_CLOSED=PASS'

contains

  real(real64) function next_unit(random_state) result(value)
    integer(int64), intent(inout) :: random_state
    random_state = modulo(random_state * 48271_int64, 2147483647_int64)
    value = real(modulo(random_state, 1000000_int64), real64) / 1000000.0_real64
  end function next_unit

  subroutine source_age_cell_update(previous, age_flux_bottom, age_flux_top, thickness, theta_now, theta_previous, &
       root, lateral, step, new_storage, new_concentration)
    real(real64), intent(in) :: previous, age_flux_bottom, age_flux_top, thickness, theta_now, theta_previous
    real(real64), intent(in) :: root, lateral, step
    real(real64), intent(out) :: new_storage, new_concentration
    real(real64) :: age_prod

    age_prod = 1.0_real64 * 0.5_real64 * (theta_now + theta_previous)
    new_storage = previous + (age_flux_bottom - age_flux_top) / thickness + &
         (-root - lateral + age_prod) * step
    new_concentration = new_storage / theta_now
  end subroutine source_age_cell_update

  subroutine compare_real(expected, actual, code)
    real(real64), intent(in) :: expected, actual
    integer, intent(in) :: code
    integer(int64) :: expected_bits, actual_bits
    expected_bits = transfer(expected, expected_bits)
    actual_bits = transfer(actual, actual_bits)
    call require(expected_bits == actual_bits, code)
  end subroutine compare_real

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (condition) return
    write(*,'(a,i0)') 'PPA_SOL_AGE_CELL_FAIL=', code
    error stop 1
  end subroutine require

end program test_ppa_sol_age_cell_balance_source_oracle
