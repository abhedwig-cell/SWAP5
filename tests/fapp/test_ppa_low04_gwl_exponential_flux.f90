program test_ppa_low04_gwl_exponential_flux
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_low04_gwl_exponential_flux
  implicit none
  integer :: i, status, use_offset
  real(real64) :: a, b, c, gwl, actual, expected, saved, replay, alternate

  call check(0, 0.5_real64, 0.1_real64, 4.0_real64, -10.0_real64, &
      0.5_real64*exp(1.0_real64), 'offset switch off')
  call check(1, 0.5_real64, 0.1_real64, 4.0_real64, 10.0_real64, &
      0.5_real64*exp(1.0_real64)+4.0_real64, 'absolute groundwater level and offset')
  call check(0, -2.0_real64, 0.0_real64, 0.0_real64, -100.0_real64, -2.0_real64, 'zero exponent')

  do i = 1, 100000
    a = real(mod(i*37, 200001)-100000, real64) / 1000.0_real64
    b = real(mod(i*17, 201)-100, real64) / 1000.0_real64
    c = real(mod(i*29, 20001)-10000, real64) / 1000.0_real64
    gwl = real(mod(i*7919, 20001)-10000, real64) / 10.0_real64
    use_offset = mod(i, 2)
    expected = a * exp(b * abs(gwl))
    if (use_offset == 1) expected = expected + c
    call evaluate_ppa_low04_gwl_exponential_flux(use_offset, a, b, c, gwl, actual, status)
    if (status /= PPA_LOW04_GWL_OK .or. transfer(actual, 0_int64) /= transfer(expected, 0_int64)) &
      error stop '100000-vector SWBOTB=4 exponential oracle mismatch'
  end do

  call evaluate_ppa_low04_gwl_exponential_flux(1, 0.4_real64, 0.05_real64, 1.0_real64, -10.0_real64, saved, status)
  call evaluate_ppa_low04_gwl_exponential_flux(1, 0.2_real64, 0.05_real64, 0.0_real64, -20.0_real64, alternate, status)
  call evaluate_ppa_low04_gwl_exponential_flux(1, 0.4_real64, 0.05_real64, 1.0_real64, -10.0_real64, replay, status)
  if (transfer(saved, 0_int64) /= transfer(replay, 0_int64) .or. &
      transfer(saved, 0_int64) == transfer(alternate, 0_int64)) error stop 'A/B/A replay mismatch'

  call evaluate_ppa_low04_gwl_exponential_flux(1, ieee_value(0.0_real64, ieee_quiet_nan), &
      0.0_real64, 0.0_real64, 0.0_real64, actual, status)
  if (status /= PPA_LOW04_GWL_INVALID_INPUT) error stop 'nonfinite coefficient accepted'
  call evaluate_ppa_low04_gwl_exponential_flux(0, 1.0_real64, 1.0_real64, 0.0_real64, &
      huge(1.0_real64), actual, status)
  if (status /= PPA_LOW04_GWL_INVALID_INPUT) error stop 'overflow-risk state accepted'
  call evaluate_ppa_low04_gwl_exponential_flux(1, 1.0_real64, 0.0_real64, 10.5_real64, &
      0.0_real64, actual, status)
  if (status /= PPA_LOW04_GWL_INVALID_INPUT) error stop 'offset range not enforced'

  write(*,'(a)') 'PPA_LOW04_GWL_EXPONENTIAL_SOURCE_ORACLE_100000=PASS'
  write(*,'(a)') 'PPA_LOW04_GWL_ABSOLUTE_LEVEL_AND_OPTIONAL_OFFSET=PASS'
  write(*,'(a)') 'PPA_LOW04_GWL_STATELESS_A_B_A=PASS'
  write(*,'(a)') 'PPA_LOW04_GWL_NONFINITE_AND_OVERFLOW_FAIL_CLOSED=PASS'

contains

  subroutine check(sw, coeff_a, coeff_b, coeff_c, water_level, want, label)
    integer, intent(in) :: sw
    real(real64), intent(in) :: coeff_a, coeff_b, coeff_c, water_level, want
    character(len=*), intent(in) :: label
    call evaluate_ppa_low04_gwl_exponential_flux(sw, coeff_a, coeff_b, coeff_c, water_level, actual, status)
    if (status /= PPA_LOW04_GWL_OK .or. abs(actual-want) > 16.0_real64*epsilon(want)) then
      write(*,'(a)') 'failed: '//label
      error stop 1
    end if
  end subroutine check

end program test_ppa_low04_gwl_exponential_flux
