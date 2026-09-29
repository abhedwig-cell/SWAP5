program test_ppa_low03_aquifer_sine
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_low03_aquifer_sine
  implicit none
  integer :: i, status
  real(real64) :: mean_head, amplitude, phase_day, period_day, time_day
  real(real64) :: twopi, actual, expected, saved, replay, alternate

  call check(100.0_real64, 20.0_real64, 0.0_real64, 100.0_real64, 0.0_real64, 120.0_real64, 'phase maximum')
  call check(100.0_real64, 20.0_real64, 25.0_real64, 100.0_real64, 75.0_real64, 80.0_real64, 'opposite phase')
  call check(10.0_real64, 0.0_real64, 366.0_real64, 366.0_real64, 12345.0_real64, 10.0_real64, 'zero amplitude')

  do i = 1, 100000
    mean_head = real(mod(i*101, 110001)-100000, real64) / 10.0_real64
    amplitude = real(mod(i*43, 100001), real64) / 100.0_real64
    phase_day = real(mod(i*37, 36601), real64) / 100.0_real64
    period_day = real(mod(i*7919, 36599)+1, real64) / 100.0_real64
    time_day = real(mod(i*17, 1000001)-500000, real64) / 100.0_real64
    twopi = 8.0_real64 * atan(1.0_real64)
    expected = mean_head + amplitude*cos(twopi/period_day * (time_day-phase_day))
    call evaluate_ppa_low03_aquifer_sine(mean_head, amplitude, phase_day, period_day, time_day, actual, status)
    if (status /= PPA_LOW03_AQUIFER_OK .or. transfer(actual, 0_int64) /= transfer(expected, 0_int64)) &
      error stop '100000-vector aquifer sine source oracle mismatch'
  end do

  call evaluate_ppa_low03_aquifer_sine(100.0_real64, 20.0_real64, 5.0_real64, &
      60.0_real64, 12.0_real64, saved, status)
  call evaluate_ppa_low03_aquifer_sine(200.0_real64, 20.0_real64, 5.0_real64, &
      60.0_real64, 12.0_real64, alternate, status)
  call evaluate_ppa_low03_aquifer_sine(100.0_real64, 20.0_real64, 5.0_real64, &
      60.0_real64, 12.0_real64, replay, status)
  if (transfer(saved, 0_int64) /= transfer(replay, 0_int64) .or. &
      transfer(saved, 0_int64) == transfer(alternate, 0_int64)) error stop 'A/B/A replay mismatch'

  call evaluate_ppa_low03_aquifer_sine(0.0_real64, 1.0_real64, 0.0_real64, &
      0.0_real64, 0.0_real64, actual, status)
  if (status /= PPA_LOW03_AQUIFER_INVALID_INPUT) error stop 'zero aquifer period accepted'
  call evaluate_ppa_low03_aquifer_sine(ieee_value(0.0_real64, ieee_quiet_nan), 1.0_real64, &
      1.0_real64, 10.0_real64, 0.0_real64, actual, status)
  if (status /= PPA_LOW03_AQUIFER_INVALID_INPUT) error stop 'nonfinite aquifer input accepted'

  write(*,'(a)') 'PPA_LOW03_AQUIFER_SINE_SOURCE_ORACLE_100000=PASS'
  write(*,'(a)') 'PPA_LOW03_AQUIFER_SINE_PHASE_AND_PERIOD=PASS'
  write(*,'(a)') 'PPA_LOW03_AQUIFER_SINE_STATELESS_A_B_A=PASS'
  write(*,'(a)') 'PPA_LOW03_AQUIFER_SINE_INVALID_PERIOD_FAIL_CLOSED=PASS'

contains

  subroutine check(average, amp, phase, period, at_time, want, label)
    real(real64), intent(in) :: average, amp, phase, period, at_time, want
    character(len=*), intent(in) :: label
    call evaluate_ppa_low03_aquifer_sine(average, amp, phase, period, at_time, actual, status)
    if (status /= PPA_LOW03_AQUIFER_OK .or. abs(actual-want) > 32.0_real64*epsilon(want)) then
      write(*,'(a)') 'failed: '//label
      error stop 1
    end if
  end subroutine check

end program test_ppa_low03_aquifer_sine
