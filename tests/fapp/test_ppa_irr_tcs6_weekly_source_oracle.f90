program test_ppa_irr_tcs6_weekly_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_ppa_irr_tcs6_weekly_timing
  implicit none

  integer, parameter :: vector_count = 100000
  integer(int64) :: random_state
  integer :: i, dayfix, expected_dayfix, actual_dayfix, status
  real(real64) :: deficit_cm, threshold_mm
  logical :: expected_trigger, triggered

  ! B1.11 crop-rotation initialization uses dayfix=366; first eligible
  ! TCS6 evaluation increments it, resets to zero, then applies the gate.
  call evaluate_tcs6_weekly_timing(366, 0.25_real64, 2.5_real64, actual_dayfix, triggered, status)
  call require(status == IRR_TCS6_OK .and. actual_dayfix == 0 .and. .not. triggered, 1)
  call evaluate_tcs6_weekly_timing(366, nearest(0.25_real64, 1.0_real64), 2.5_real64, &
                                  actual_dayfix, triggered, status)
  call require(status == IRR_TCS6_OK .and. actual_dayfix == 0 .and. triggered, 2)
  call evaluate_tcs6_weekly_timing(366, nearest(0.25_real64, -1.0_real64), 2.5_real64, &
                                  actual_dayfix, triggered, status)
  call require(status == IRR_TCS6_OK .and. actual_dayfix == 0 .and. .not. triggered, 3)

  ! Before day seven there is no event test; day seven resets regardless
  ! of the threshold result, matching the exact source statement order.
  call evaluate_tcs6_weekly_timing(5, 1.0_real64, 0.0_real64, actual_dayfix, triggered, status)
  call require(status == IRR_TCS6_OK .and. actual_dayfix == 6 .and. .not. triggered, 4)
  call evaluate_tcs6_weekly_timing(6, 1.0_real64, 20.0_real64, actual_dayfix, triggered, status)
  call require(status == IRR_TCS6_OK .and. actual_dayfix == 0 .and. .not. triggered, 5)

  random_state = 20260923_int64
  do i = 1, vector_count
    random_state = modulo(random_state*48271_int64, 2147483647_int64)
    select case (modulo(i, 8))
    case (0)
      dayfix = 366
    case default
      dayfix = modulo(i+int(modulo(random_state, 17_int64)), 7)
    end select
    random_state = modulo(random_state*48271_int64, 2147483647_int64)
    deficit_cm = 20.0_real64*real(modulo(random_state, 1000001_int64), real64)/1000000.0_real64
    random_state = modulo(random_state*48271_int64, 2147483647_int64)
    threshold_mm = 20.0_real64*real(modulo(random_state, 1000001_int64), real64)/1000000.0_real64

    call source_tcs6(dayfix, deficit_cm, threshold_mm, expected_dayfix, expected_trigger)
    call evaluate_tcs6_weekly_timing(dayfix, deficit_cm, threshold_mm, actual_dayfix, triggered, status)
    call require(status == IRR_TCS6_OK, 10)
    call require(actual_dayfix == expected_dayfix, 11)
    call require(triggered .eqv. expected_trigger, 12)
  end do

  call evaluate_tcs6_weekly_timing(367, 1.0_real64, 1.0_real64, actual_dayfix, triggered, status)
  call require(status == IRR_TCS6_INVALID_INPUT .and. actual_dayfix == 367 .and. .not. triggered, 13)
  call evaluate_tcs6_weekly_timing(6, 1.0_real64, 20.01_real64, actual_dayfix, triggered, status)
  call require(status == IRR_TCS6_INVALID_INPUT .and. actual_dayfix == 6 .and. .not. triggered, 14)

  print '(A)', 'PPA_IRR_TCS6_WEEKLY_SOURCE_ORACLE_100000=PASS'
  print '(A)', 'PPA_IRR_TCS6_DAYFIX_366_STARTUP_AND_SEVENTH_DAY_RESET=PASS'
  print '(A)', 'PPA_IRR_TCS6_STRICT_DEFICIT_THRESHOLD=PASS'
  print '(A)', 'PPA_IRR_TCS6_WEEKLY_SOURCE_ORACLE=PASS'

contains

  subroutine source_tcs6(source_dayfix, source_deficit_cm, source_threshold_mm, out_dayfix, out_triggered)
    integer, intent(in) :: source_dayfix
    real(real64), intent(in) :: source_deficit_cm, source_threshold_mm
    integer, intent(out) :: out_dayfix
    logical, intent(out) :: out_triggered
    out_dayfix = source_dayfix
    out_triggered = .false.
    out_dayfix = out_dayfix + 1
    if (out_dayfix >= 7) then
      out_dayfix = 0
      if (10.0_real64*source_deficit_cm > source_threshold_mm) out_triggered = .true.
    end if
  end subroutine source_tcs6

  subroutine require(ok, code)
    logical, intent(in) :: ok
    integer, intent(in) :: code
    if (.not. ok) then
      write(*,'(A,I0)') 'PPA_IRR_TCS6_FAIL=', code
      error stop 1
    end if
  end subroutine require

end program test_ppa_irr_tcs6_weekly_source_oracle
