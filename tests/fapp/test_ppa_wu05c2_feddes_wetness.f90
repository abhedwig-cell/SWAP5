program test_ppa_wu05c2_feddes_wetness
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_wu05c2_feddes_wetness
  implicit none

  integer, parameter :: ncase = 100000
  integer :: i, status
  integer(int64) :: state
  real(real64) :: h, hlim1, hlim2, actual, expected, a_value

  state = 19349663_int64
  do i = 1, ncase
    h = -2000.0_real64 + 4000.0_real64 * next_unit(state)
    hlim1 = -1500.0_real64 + 3000.0_real64 * next_unit(state)
    hlim2 = -1500.0_real64 + 3000.0_real64 * next_unit(state)
    call evaluate_ppa_wu05c2_feddes_wetness(h, hlim1, hlim2, actual, status)
    call require(status == PPA_WU05C2_OK, 'finite source-domain input rejected')
    expected = source_oracle(h, hlim1, hlim2)
    call require(same_bits(actual, expected), 'factor differs from source branch oracle')
  end do

  call check_point(-10.0_real64, -10.0_real64, -30.0_real64, 0.0_real64, 'hlim1 equality')
  call check_point(-30.0_real64, -10.0_real64, -30.0_real64, 1.0_real64, 'hlim2 equality')
  call check_point(0.0_real64, -10.0_real64, -30.0_real64, 0.0_real64, 'wet-end zero')
  call check_point(-20.0_real64, -10.0_real64, -30.0_real64, 0.5_real64, 'linear interior')
  call check_point(-30.0_real64, -10.0_real64, -10.0_real64, 1.0_real64, 'equal-threshold lower equality')
  call check_point(0.0_real64, -10.0_real64, -10.0_real64, 0.0_real64, 'equal-threshold wet-end')
  call check_point(-20.0_real64, -10.0_real64, -30.0_real64, 0.5_real64, 'normal threshold ordering')
  call check_point(-20.0_real64, -30.0_real64, -10.0_real64, 0.0_real64, 'reversed threshold source branch')

  h = -20.0_real64
  hlim1 = -10.0_real64
  hlim2 = -30.0_real64
  call evaluate_ppa_wu05c2_feddes_wetness(h, hlim1, hlim2, a_value, status)
  call require(status == PPA_WU05C2_OK, 'A replay rejected')
  call evaluate_ppa_wu05c2_feddes_wetness(-100.0_real64, -50.0_real64, -150.0_real64, actual, status)
  call require(status == PPA_WU05C2_OK, 'B replay rejected')
  call evaluate_ppa_wu05c2_feddes_wetness(h, hlim1, hlim2, expected, status)
  call require(status == PPA_WU05C2_OK .and. same_bits(a_value, expected), 'A/B/A replay differs')

  call evaluate_ppa_wu05c2_feddes_wetness(ieee_value(0.0_real64, ieee_quiet_nan), &
      hlim1, hlim2, actual, status)
  call require(status == PPA_WU05C2_INVALID_INPUT .and. same_bits(actual, 0.0_real64), 'NaN did not fail closed')

  write(*, '(a)') 'PPA_WU05C2_EXACT_SOURCE_BRANCH_ORACLE_100000=PASS'
  write(*, '(a)') 'PPA_WU05C2_THRESHOLD_EQUALITY_ORDER_AND_ENDPOINTS=PASS'
  write(*, '(a)') 'PPA_WU05C2_STATELESS_A_B_A_REPLAY=PASS'
  write(*, '(a)') 'PPA_WU05C2_NONFINITE_FAIL_CLOSED=PASS'

contains

  real(real64) function next_unit(value)
    integer(int64), intent(inout) :: value
    value = modulo(48271_int64 * value, 2147483647_int64)
    next_unit = real(value, real64) / 2147483647.0_real64
  end function next_unit

  real(real64) function source_oracle(head, upper, lower)
    real(real64), intent(in) :: head, upper, lower
    source_oracle = 1.0_real64
    if (head <= upper .and. head > lower) source_oracle = (upper-head)/(upper-lower)
    if (head > upper) source_oracle = 0.0_real64
  end function source_oracle

  subroutine check_point(head, upper, lower, wanted, label)
    real(real64), intent(in) :: head, upper, lower, wanted
    character(len=*), intent(in) :: label
    call evaluate_ppa_wu05c2_feddes_wetness(head, upper, lower, actual, status)
    call require(status == PPA_WU05C2_OK, label//' rejected')
    call require(abs(actual-wanted) <= 1.0e-14_real64, label//' mismatch')
  end subroutine check_point

  logical function same_bits(left, right)
    real(real64), intent(in) :: left, right
    same_bits = transfer(left, 0_int64) == transfer(right, 0_int64)
  end function same_bits

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*, '(a)') 'PPA_WU05C2_FAIL='//trim(message)
      error stop 1
    end if
  end subroutine require

end program test_ppa_wu05c2_feddes_wetness
