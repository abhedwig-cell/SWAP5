program test_ppa_irr_tcsfix_filter_source_oracle
  use, intrinsic :: iso_fortran_env, only: int64
  use mod_ppa_irr_tcsfix_filter
  implicit none

  integer, parameter :: vector_count = 100000
  integer :: dayfix, interval_days, expected_dayfix, actual_dayfix, status, i
  integer(int64) :: random_state
  logical :: candidate_event, expected_allowed, event_allowed

  ! The first crop-rotation value is 366. Above-threshold counters are held
  ! when no event is selected, then reset to one when an event is accepted.
  call check_case(366, 7, .false., 366, .false., 1)
  call check_case(366, 7, .true., 1, .true., 2)
  call check_case(6, 7, .true., 7, .false., 3)
  call check_case(7, 7, .false., 7, .false., 4)
  call check_case(7, 7, .true., 1, .true., 5)
  call check_case(0, 1, .true., 1, .false., 6)

  random_state = 20260923_int64
  do i = 1, vector_count
    random_state = modulo(random_state*48271_int64, 2147483647_int64)
    dayfix = int(modulo(random_state, 367_int64))
    random_state = modulo(random_state*48271_int64, 2147483647_int64)
    interval_days = 1 + int(modulo(random_state, 366_int64))
    random_state = modulo(random_state*48271_int64, 2147483647_int64)
    candidate_event = modulo(random_state, 2_int64) == 0

    call source_tcsfix(dayfix, interval_days, candidate_event, expected_dayfix, expected_allowed)
    call evaluate_tcsfix_filter(dayfix, interval_days, candidate_event, actual_dayfix, event_allowed, status)
    call require(status == IRR_TCSFIX_OK, 10)
    call require(actual_dayfix == expected_dayfix, 11)
    call require(event_allowed .eqv. expected_allowed, 12)
  end do

  call evaluate_tcsfix_filter(367, 7, .true., actual_dayfix, event_allowed, status)
  call require(status == IRR_TCSFIX_INVALID_INPUT .and. actual_dayfix == 367 .and. .not. event_allowed, 13)
  call evaluate_tcsfix_filter(0, 0, .true., actual_dayfix, event_allowed, status)
  call require(status == IRR_TCSFIX_INVALID_INPUT .and. actual_dayfix == 0 .and. .not. event_allowed, 14)

  print '(A)', 'PPA_IRR_TCSFIX_SOURCE_ORACLE_100000=PASS'
  print '(A)', 'PPA_IRR_TCSFIX_INTERVAL_EQUALITY_AND_EVENT_RESET=PASS'
  print '(A)', 'PPA_IRR_TCSFIX_NO_EVENT_COUNTER_HOLD_AND_INCREMENT=PASS'
  print '(A)', 'PPA_IRR_TCSFIX_SOURCE_ORACLE=PASS'

contains

  subroutine source_tcsfix(source_dayfix, source_interval, source_candidate, out_dayfix, out_allowed)
    integer, intent(in) :: source_dayfix, source_interval
    logical, intent(in) :: source_candidate
    integer, intent(out) :: out_dayfix
    logical, intent(out) :: out_allowed
    out_dayfix = source_dayfix
    out_allowed = .false.
    if (source_candidate .and. out_dayfix >= source_interval) then
      out_allowed = .true.
      out_dayfix = 1
    else
      if (out_dayfix < source_interval) out_dayfix = out_dayfix + 1
    end if
  end subroutine source_tcsfix

  subroutine check_case(source_dayfix, source_interval, source_candidate, expected_count, expected_event, code)
    integer, intent(in) :: source_dayfix, source_interval, expected_count, code
    logical, intent(in) :: source_candidate, expected_event
    integer :: actual_count, result_status
    logical :: actual_event
    call evaluate_tcsfix_filter(source_dayfix, source_interval, source_candidate, &
                                actual_count, actual_event, result_status)
    call require(result_status == IRR_TCSFIX_OK, 20+code)
    call require(actual_count == expected_count, 30+code)
    call require(actual_event .eqv. expected_event, 40+code)
  end subroutine check_case

  subroutine require(ok, code)
    logical, intent(in) :: ok
    integer, intent(in) :: code
    if (.not. ok) then
      write(*,'(A,I0)') 'PPA_IRR_TCSFIX_FAIL=', code
      error stop 1
    end if
  end subroutine require

end program test_ppa_irr_tcsfix_filter_source_oracle
