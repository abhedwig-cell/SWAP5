program test_ppa_wu05f1_macro_frost_factor
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_wu05f1_macro_frost_factor
  implicit none
  integer :: i, status, sw
  real(real64) :: temperature, actual, expected, a, b, replay

  call check(1, -0.001_real64, 0.0_real64)
  call check(1, 0.0_real64, 1.0_real64)
  call check(1, 1.0_real64, 1.0_real64)
  call check(0, -10.0_real64, 1.0_real64)

  do i = 1, 100000
    sw = mod(i, 2)
    temperature = real(mod(i * 7919, 40001) - 20000, real64) / 1000.0_real64
    expected = 1.0_real64
    if (sw == 1 .and. temperature < 0.0_real64) expected = 0.0_real64
    call ppa_wu05f1_macro_frost_factor(sw, temperature, actual, status)
    if (status /= PPA_WU05F1_OK .or. .not. same_bits(actual, expected)) &
      error stop '100000-vector exact-source oracle mismatch'
  end do

  call ppa_wu05f1_macro_frost_factor(1, -1.0_real64, a, status)
  call ppa_wu05f1_macro_frost_factor(1, 1.0_real64, b, status)
  call ppa_wu05f1_macro_frost_factor(1, -1.0_real64, replay, status)
  if (.not. same_bits(a, replay) .or. same_bits(a, b)) error stop 'A/B/A replay or fixture failed'
  call ppa_wu05f1_macro_frost_factor(1, ieee_value(0.0_real64, ieee_quiet_nan), actual, status)
  if (status /= PPA_WU05F1_INVALID_INPUT .or. .not. same_bits(actual, 1.0_real64)) &
    error stop 'nonfinite temperature did not fail closed'

  write(*,'(a)') 'PPA_WU05F1_MACRO_FROST_SOURCE_ORACLE_100000=PASS'
  write(*,'(a)') 'PPA_WU05F1_STRICT_ZERO_THRESHOLD_AND_DISABLED=PASS'
  write(*,'(a)') 'PPA_WU05F1_STATELESS_A_B_A=PASS'
  write(*,'(a)') 'PPA_WU05F1_NONFINITE_FAIL_CLOSED=PASS'

contains

  subroutine check(switch, temp, want)
    integer, intent(in) :: switch
    real(real64), intent(in) :: temp, want
    call ppa_wu05f1_macro_frost_factor(switch, temp, actual, status)
    if (status /= PPA_WU05F1_OK .or. .not. same_bits(actual, want)) error stop 'edge case mismatch'
  end subroutine check

  pure logical function same_bits(left, right)
    real(real64), intent(in) :: left, right
    same_bits = transfer(left, 0_int64) == transfer(right, 0_int64)
  end function same_bits

end program test_ppa_wu05f1_macro_frost_factor
