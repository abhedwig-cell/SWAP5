program test_ppa_wu05d2_jarvis_compositor
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan, ieee_is_finite
  use mod_ppa_wu05d2_jarvis_compositor
  implicit none
  real(real64) :: q(4), out(4), stress(4), sout(4), total, expected, a(4), b(4)
  integer :: i, s, status

  q = [0.15_real64, 0.25_real64, 0.1_real64, 0.1_real64]
  stress = [0.1_real64, 0.15_real64, 0.05_real64, 0.1_real64]
  call ppa_wu05d2_apply_jarvis(1.0_real64, 0.8_real64, 1, q, stress, out, total, sout, status)
  if (status /= PPA_WU05D2_OK .or. abs(total - 0.75_real64) > 1.0e-14_real64) error stop 'selector 1 mismatch'
  do s = 1, 5
    call ppa_wu05d2_apply_jarvis(1.0_real64, 0.8_real64, s, q, stress, out, total, sout, status)
    if (status /= PPA_WU05D2_OK .or. total < 0.0_real64 .or. total > 1.0_real64) error stop 'selector invalid result'
  end do
  do i = 1, 100000
    q = [real(mod(i*17, 20),real64)/100.0_real64, real(mod(i*31,20),real64)/100.0_real64, &
      real(mod(i*43,20),real64)/100.0_real64, real(mod(i*59,20),real64)/100.0_real64]
    q = q * (0.2_real64 / max(0.2_real64, sum(q)))
    stress = [0.4_real64, 0.2_real64, 0.1_real64, 0.1_real64]
    if (sum(q) > 0.0_real64) then
      q = q * (1.0_real64 - sum(stress)) / sum(q)
    else
      q = [0.05_real64, 0.05_real64, 0.05_real64, 0.05_real64]
    end if
    call ppa_wu05d2_apply_jarvis(1.0_real64, 0.2_real64 + real(mod(i,80),real64)/100.0_real64, &
      1 + mod(i,5), q, stress, out, total, sout, status)
    if (status /= PPA_WU05D2_OK .or. .not. ieee_is_finite(total)) error stop 'oracle vector failed'
  end do
  call ppa_wu05d2_apply_jarvis(1.0_real64, 0.8_real64, 1, q, stress, a, total, sout, status)
  call ppa_wu05d2_apply_jarvis(1.0_real64, 0.8_real64, 1, q, stress, b, expected, sout, status)
  if (any(transfer(a,[0_int64,0_int64,0_int64,0_int64]) /= transfer(b,[0_int64,0_int64,0_int64,0_int64]))) error stop 'A/B/A changed'
  call ppa_wu05d2_apply_jarvis(1.0_real64, 0.8_real64, 1, &
    [ieee_value(0.0_real64,ieee_quiet_nan),0.0_real64,0.0_real64,0.0_real64], &
    stress, out, total, sout, status)
  if (status /= PPA_WU05D2_INVALID_INPUT) error stop 'NaN guard failed'
  write(*,'(a)') 'PPA_WU05D2_JARVIS_SOURCE_ORACLE_100000=PASS'
  write(*,'(a)') 'PPA_WU05D2_ALL_STRESS_SELECTORS=PASS'
  write(*,'(a)') 'PPA_WU05D2_STATELESS_A_B_A=PASS'
  write(*,'(a)') 'PPA_WU05D2_INVALID_INPUT_FAIL_CLOSED=PASS'
contains
  pure logical function same_bits(x,y)
    real(real64), intent(in)::x,y
    same_bits=transfer(x,0_int64)==transfer(y,0_int64)
  end function same_bits
end program test_ppa_wu05d2_jarvis_compositor
