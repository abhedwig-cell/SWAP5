program test_ppa_wu05c3b_swap007_guard
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_wu05c3b_swap007_guard
  implicit none

  integer, parameter :: ncase = 100000
  integer :: i, status, count_sub
  integer(int64) :: state
  real(real64) :: l, fi, fi_a, actual, expected
  logical :: actual_restart, expected_restart

  state = 921233_int64
  do i = 1, ncase
    l = 100.0_real64 * next_unit(state)
    fi = 100.0_real64 * (next_unit(state)-0.5_real64)
    fi_a = 10.0_real64 * (next_unit(state)-0.5_real64)
    count_sub = modulo(i*37, 130)
    call evaluate_ppa_wu05c3b_swap007_guard(l, fi, fi_a, count_sub, actual, actual_restart, status)
    call require(status == PPA_WU05C3B_OK, 'finite oracle input rejected')
    call source_oracle(l, fi, fi_a, count_sub, expected, expected_restart)
    call require(same_bits(actual, expected) .and. (actual_restart .eqv. expected_restart), &
        'ordinary source guard oracle mismatch')
  end do

  call check_case(0.1_real64, 1.0_real64, 0.0_real64, 0, huge(1.0_real64), .true., 'zero derivative')
  call check_case(0.1_real64, 1.0_real64, tiny(1.0_real64), 0, huge(1.0_real64), .true., 'tiny derivative')
  call check_case(0.1_real64, huge(1.0_real64), 1.0_real64, 0, huge(1.0_real64), .true., 'unrepresentable quotient')
  call check_case(0.1_real64, huge(1.0_real64), 2.0_real64, 0, &
      abs(0.1_real64-(huge(1.0_real64)/2.0_real64)), .true., 'representable near-limit quotient')
  call check_case(0.1_real64, 2.0_real64, 1.0_real64, 101, 1.9_real64, .true., 'existing counter restart')
  call check_case(0.1_real64, 2000.0_real64, 1.0_real64, 0, 1999.9_real64, .true., 'existing lnew restart')
  call check_case(0.1_real64, 2.0_real64, 1.0_real64, 100, 1.9_real64, .false., 'counter boundary')

  call evaluate_ppa_wu05c3b_swap007_guard(ieee_value(0.0_real64, ieee_quiet_nan), &
      1.0_real64, 1.0_real64, 0, actual, actual_restart, status)
  call require(status == PPA_WU05C3B_INVALID_INPUT .and. same_bits(actual, 0.0_real64) .and. &
      .not. actual_restart, 'non-finite input did not fail closed')

  write(*, '(a)') 'PPA_WU05C3B_SOURCE_GUARD_ORACLE_100000=PASS'
  write(*, '(a)') 'PPA_WU05C3B_UNREPRESENTABLE_AND_TINY_DERIVATIVE=PASS'
  write(*, '(a)') 'PPA_WU05C3B_REPRESENTABLE_NEAR_LIMIT_AND_RESTART_BOUNDARIES=PASS'
  write(*, '(a)') 'PPA_WU05C3B_NONFINITE_FAIL_CLOSED=PASS'

contains

  real(real64) function next_unit(value)
    integer(int64), intent(inout) :: value
    value = modulo(48271_int64 * value, 2147483647_int64)
    next_unit = real(value, real64) / 2147483647.0_real64
  end function next_unit

  subroutine source_oracle(step, residual, derivative, counter, candidate, restart)
    real(real64), intent(in) :: step, residual, derivative
    integer, intent(in) :: counter
    real(real64), intent(out) :: candidate
    logical, intent(out) :: restart
    if (abs(derivative) > max(tiny(1.0_real64), abs(residual)/huge(1.0_real64))) then
      candidate = abs(step-(residual/derivative))
    else
      candidate = huge(1.0_real64)
    end if
    restart = candidate > 1.0e3_real64 .or. counter > 100
  end subroutine source_oracle

  subroutine check_case(step, residual, derivative, counter, wanted, wanted_restart, label)
    real(real64), intent(in) :: step, residual, derivative, wanted
    integer, intent(in) :: counter
    logical, intent(in) :: wanted_restart
    character(len=*), intent(in) :: label
    call evaluate_ppa_wu05c3b_swap007_guard(step, residual, derivative, counter, &
        actual, actual_restart, status)
    call require(status == PPA_WU05C3B_OK, label//' rejected')
    call require(same_bits(actual, wanted) .and. (actual_restart .eqv. wanted_restart), label//' mismatch')
  end subroutine check_case

  logical function same_bits(left, right)
    real(real64), intent(in) :: left, right
    same_bits = transfer(left, 0_int64) == transfer(right, 0_int64)
  end function same_bits

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*, '(a)') 'PPA_WU05C3B_FAIL='//trim(message)
      error stop 1
    end if
  end subroutine require

end program test_ppa_wu05c3b_swap007_guard
