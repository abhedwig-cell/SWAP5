program test_ppa_low02_time_independent
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_legacy_swbotb2_application_control, only: b110_legacy_swbotb2_application_control_t, &
       B110_SWBOTB2_OK, B110_SWBOTB2_INVALID_CONTROL, B110_SWBOTB2_TIME_NOT_COVERED, &
       B110_SWBOTB2_DRY_HEAD_CM
  implicit none

  type(b110_legacy_swbotb2_application_control_t) :: control
  real(real64) :: starts(3), times(4), values(4), q, expected, q_a, q_b, q_a2
  integer :: status, mode
  real(real64) :: pi

  pi = 4.0_real64 * atan(1.0_real64)

  ! Independent SW2=1 oracle from B1.11 BoundBottom:
  ! qbot = sinave + sinamp*cos((2*pi/365)*(t-sinmax)).
  starts = [10000.0_real64, 10365.0_real64, 10731.0_real64]
  call control%initialize_sine(400.0_real64, 10090.0_real64, starts, &
       -0.2_real64, 0.6_real64, 90.0_real64, status)
  call require(status == B110_SWBOTB2_OK, 'sine initialize')
  call control%evaluate(400.0_real64, 400.125_real64, -50.0_real64, mode, q, status)
  call require(status == B110_SWBOTB2_OK .and. mode == 2, 'sine selector')
  expected = -0.2_real64 + 0.6_real64
  call require(bits_equal(q, expected), 'sine maximum')

  call control%evaluate(491.25_real64, 491.5_real64, -50.0_real64, mode, q, status)
  expected = -0.2_real64 + 0.6_real64 * cos((2.0_real64*pi/365.0_real64) * (181.25_real64 - 90.0_real64))
  call require(bits_equal(q, expected), 'sine substep-start time')

  call control%evaluate(675.0_real64, 675.25_real64, -50.0_real64, mode, q, status)
  expected = -0.2_real64 + 0.6_real64 * cos((2.0_real64*pi/365.0_real64) * (0.0_real64 - 90.0_real64))
  call require(bits_equal(q, expected), 'sine calendar reset')

  ! Exact strict dry guard and stateless re-entry.
  call control%evaluate(400.0_real64, 400.125_real64, B110_SWBOTB2_DRY_HEAD_CM, mode, q, status)
  call require(status == B110_SWBOTB2_OK .and. mode == 2, 'strict dry threshold equality')
  call control%evaluate(400.0_real64, 400.125_real64, B110_SWBOTB2_DRY_HEAD_CM - 0.5_real64, mode, q, status)
  call require(status == B110_SWBOTB2_OK .and. mode == -2, 'dry selector -2')
  call control%evaluate(400.0_real64, 400.125_real64, -50.0_real64, mode, q, status)
  call require(status == B110_SWBOTB2_OK .and. mode == 2, 're-entry without selector memory')

  ! Independent AFGEN oracle at substep end.
  times = [20000.0_real64, 20001.0_real64, 20003.0_real64, 20006.0_real64]
  values = [-2.0_real64, 2.0_real64, 6.0_real64, -4.0_real64]
  call control%initialize_table(700.0_real64, 20000.0_real64, times, values, status)
  call require(status == B110_SWBOTB2_OK, 'table initialize')
  call control%evaluate(700.0_real64, 700.25_real64, -50.0_real64, mode, q, status)
  call require(bits_equal(q, -1.0_real64), 'first segment interpolation at t1')
  call control%evaluate(700.5_real64, 702.0_real64, -50.0_real64, mode, q, status)
  call require(bits_equal(q, 4.0_real64), 'second segment interpolation at t1')
  call control%evaluate(690.0_real64, 691.0_real64, -50.0_real64, mode, q, status)
  call require(bits_equal(q, -2.0_real64), 'AFGEN lower clamp')
  call control%evaluate(710.0_real64, 711.0_real64, -50.0_real64, mode, q, status)
  call require(bits_equal(q, -4.0_real64), 'AFGEN upper clamp')

  ! A-B-A purity: no continuation state may be retained by the time law.
  call control%evaluate(700.0_real64, 700.25_real64, -50.0_real64, mode, q_a, status)
  call control%evaluate(701.0_real64, 702.0_real64, -50.0_real64, mode, q_b, status)
  call control%evaluate(700.0_real64, 700.25_real64, -50.0_real64, mode, q_a2, status)
  call require(bits_equal(q_a, q_a2) .and. .not. bits_equal(q_a, q_b), 'A-B-A purity')

  ! Fail closed when a sine request leaves the explicitly supplied calendar.
  starts = [10000.0_real64, 10365.0_real64, 10731.0_real64]
  call control%initialize_sine(0.0_real64, 10000.0_real64, starts, 0.0_real64, 1.0_real64, 0.0_real64, status)
  call require(status == B110_SWBOTB2_OK, 'bounded sine initialize')
  call control%evaluate(731.0_real64, 731.1_real64, -50.0_real64, mode, q, status)
  call require(status == B110_SWBOTB2_TIME_NOT_COVERED .and. mode == 0, 'calendar coverage fail closed')

  times = [1.0_real64, 1.0_real64, 2.0_real64, 3.0_real64]
  call control%initialize_table(0.0_real64, 0.0_real64, times, values, status)
  call require(status == B110_SWBOTB2_INVALID_CONTROL, 'non-increasing table rejected')

  print '(a)', 'PPA_LOW02_INDEPENDENT_SINE_ORACLE=PASS'
  print '(a)', 'PPA_LOW02_INDEPENDENT_TABLE_ORACLE=PASS'
  print '(a)', 'PPA_LOW02_INDEPENDENT_DRY_REENTRY=PASS'
  print '(a)', 'PPA_LOW02_INDEPENDENT_ABA_PURITY=PASS'
  print '(a)', 'PPA_LOW02_INDEPENDENT_FAIL_CLOSED=PASS'
  print '(a)', 'PPA-LOW02-TIME INDEPENDENT QUALIFICATION PASS'

contains

  logical function bits_equal(a, b) result(equal)
    use, intrinsic :: iso_fortran_env, only: int64
    real(real64), intent(in) :: a, b
    integer(int64) :: ia, ib
    ia = transfer(a, ia)
    ib = transfer(b, ib)
    equal = ia == ib
  end function bits_equal

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a,1x,a)') 'PPA_LOW02_INDEPENDENT_FAIL', trim(message)
      error stop 1
    end if
  end subroutine require

end program test_ppa_low02_time_independent
