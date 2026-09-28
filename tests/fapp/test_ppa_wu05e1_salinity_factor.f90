program test_ppa_wu05e1_salinity_factor
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_wu05e1_salinity_factor
  implicit none
  integer :: i, status
  real(real64) :: cml, saltmax, saltslope, actual, expected, a, b, replay

  call check(1, 10.0_real64, 10.0_real64, 0.1_real64, 1.0_real64, 'strict threshold equality')
  call check(1, 11.0_real64, 10.0_real64, 0.1_real64, 0.9_real64, 'linear decline')
  call check(1, 100.0_real64, 10.0_real64, 1.0_real64, 0.0_real64, 'lower clamp')
  call check(1, -1.0_real64, 0.0_real64, 1.0_real64, 1.0_real64, 'below threshold')
  call check(0, 50.0_real64, 10.0_real64, 1.0_real64, 1.0_real64, 'disabled switch')

  do i = 1, 100000
    cml = real(mod(i * 7919, 100000), real64) / 1000.0_real64
    saltmax = real(mod(i * 97, 10001), real64) / 100.0_real64
    saltslope = real(mod(i * 313, 1001), real64) / 1000.0_real64
    expected = 1.0_real64
    if (cml > saltmax) then
      expected = 1.0_real64 - (cml - saltmax) * saltslope
      expected = max(0.0_real64, expected)
    end if
    call ppa_wu05e1_maas_hoffman_factor(1, cml, saltmax, saltslope, actual, status)
    if (status /= PPA_WU05E1_OK .or. transfer(actual, 0_int64) /= transfer(expected, 0_int64)) &
      error stop '100000-vector exact-source oracle mismatch'
  end do

  call ppa_wu05e1_maas_hoffman_factor(1, 12.0_real64, 10.0_real64, 0.2_real64, a, status)
  call ppa_wu05e1_maas_hoffman_factor(1, 13.0_real64, 10.0_real64, 0.2_real64, b, status)
  call ppa_wu05e1_maas_hoffman_factor(1, 12.0_real64, 10.0_real64, 0.2_real64, replay, status)
  if (.not. same_bits(a, replay)) error stop 'A/B/A replay changed output'

  call ppa_wu05e1_maas_hoffman_factor(1, ieee_value(0.0_real64, ieee_quiet_nan), &
      10.0_real64, 0.2_real64, actual, status)
  if (status /= PPA_WU05E1_INVALID_INPUT .or. .not. same_bits(actual, 1.0_real64)) &
    error stop 'NaN did not fail closed'
  call ppa_wu05e1_maas_hoffman_factor(1, 20.0_real64, 10.0_real64, 1.1_real64, actual, status)
  if (status /= PPA_WU05E1_INVALID_INPUT .or. .not. same_bits(actual, 1.0_real64)) &
    error stop 'slope range not enforced'
  if (b <= 0.0_real64) error stop 'A/B/A distinct fixture collapsed'

  write(*,'(a)') 'PPA_WU05E1_MAAS_HOFFMAN_SOURCE_ORACLE_100000=PASS'
  write(*,'(a)') 'PPA_WU05E1_THRESHOLD_DISABLED_AND_CLAMP=PASS'
  write(*,'(a)') 'PPA_WU05E1_STATELESS_A_B_A=PASS'
  write(*,'(a)') 'PPA_WU05E1_INVALID_NONFINITE_FAIL_CLOSED=PASS'

contains

  subroutine check(sw, concentration, threshold, slope, want, label)
    integer, intent(in) :: sw
    real(real64), intent(in) :: concentration, threshold, slope, want
    character(len=*), intent(in) :: label
    call ppa_wu05e1_maas_hoffman_factor(sw, concentration, threshold, slope, actual, status)
    if (status /= PPA_WU05E1_OK .or. .not. same_bits(actual, want)) then
      write(*,'(a)') 'failed: '//label
      error stop 1
    end if
  end subroutine check

  pure logical function same_bits(left, right)
    real(real64), intent(in) :: left, right
    same_bits = transfer(left, 0_int64) == transfer(right, 0_int64)
  end function same_bits

end program test_ppa_wu05e1_salinity_factor
