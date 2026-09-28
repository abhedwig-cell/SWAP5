program test_ppa_low03_cauchy_flux
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_low03_cauchy_flux
  implicit none
  integer :: i, status, use_extra
  real(real64) :: gwl, hdrain, shape, deepgw, rimlay, cval, extra
  real(real64) :: actual, expected, gwl_mean, saved, replay, alternate

  call check(0, 2.0_real64, -100.0_real64, 1.0_real64, 10.0_real64, &
      5.0_real64, 5.0_real64, 0.0_real64, 0.8_real64, 'shape one')
  call check(1, 2.0_real64, -100.0_real64, 0.0_real64, 10.0_real64, &
      5.0_real64, 5.0_real64, -2.0_real64, 9.0_real64, 'shape zero and extra flux')

  do i = 1, 100000
    gwl = real(mod(i*7919, 20001)-10000, real64) / 10.0_real64
    hdrain = -real(mod(i*17, 100001), real64) / 10.0_real64
    shape = real(mod(i*37, 1001), real64) / 1000.0_real64
    deepgw = real(mod(i*101, 110001)-100000, real64) / 10.0_real64
    rimlay = real(mod(i*43, 1000000), real64) / 10.0_real64
    cval = real(mod(i*29, 100000), real64) / 100.0_real64
    extra = real(mod(i*23, 20001)-10000, real64) / 100.0_real64
    use_extra = mod(i, 2)
    gwl_mean = hdrain + shape * (gwl - hdrain)
    expected = (deepgw - gwl_mean) / (rimlay + cval)
    if (use_extra == 1) expected = expected + extra
    call evaluate_ppa_low03_cauchy_flux(use_extra, gwl, hdrain, shape, deepgw, &
        rimlay, cval, extra, actual, status)
    if (status /= PPA_LOW03_CAUCHY_OK .or. transfer(actual, 0_int64) /= transfer(expected, 0_int64)) &
      error stop '100000-vector explicit Cauchy source oracle mismatch'
  end do

  call evaluate_ppa_low03_cauchy_flux(0, 2.0_real64, -100.0_real64, 1.0_real64, &
      10.0_real64, 5.0_real64, 5.0_real64, 0.0_real64, saved, status)
  call evaluate_ppa_low03_cauchy_flux(0, 3.0_real64, -100.0_real64, 1.0_real64, &
      10.0_real64, 5.0_real64, 5.0_real64, 0.0_real64, alternate, status)
  call evaluate_ppa_low03_cauchy_flux(0, 2.0_real64, -100.0_real64, 1.0_real64, &
      10.0_real64, 5.0_real64, 5.0_real64, 0.0_real64, replay, status)
  if (transfer(saved, 0_int64) /= transfer(replay, 0_int64) .or. &
      transfer(saved, 0_int64) == transfer(alternate, 0_int64)) error stop 'A/B/A replay mismatch'

  call evaluate_ppa_low03_cauchy_flux(0, ieee_value(0.0_real64, ieee_quiet_nan), &
      -10.0_real64, 0.5_real64, 0.0_real64, 1.0_real64, 1.0_real64, 0.0_real64, actual, status)
  if (status /= PPA_LOW03_CAUCHY_INVALID_INPUT) error stop 'nonfinite input accepted'
  call evaluate_ppa_low03_cauchy_flux(0, 0.0_real64, 0.0_real64, 0.0_real64, &
      1.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, actual, status)
  if (status /= PPA_LOW03_CAUCHY_INVALID_INPUT) error stop 'zero total resistance accepted'
  call evaluate_ppa_low03_cauchy_flux(0, 0.0_real64, 0.0_real64, 0.5_real64, &
      1.0_real64, 1.0_real64, 0.0_real64, 101.0_real64, actual, status)
  if (status /= PPA_LOW03_CAUCHY_OK) error stop 'unused optional flux should not constrain result'

  write(*,'(a)') 'PPA_LOW03_EXPLICIT_CAUCHY_SOURCE_ORACLE_100000=PASS'
  write(*,'(a)') 'PPA_LOW03_CAUCHY_SHAPE_RESISTANCE_AND_EXTRA_FLUX=PASS'
  write(*,'(a)') 'PPA_LOW03_CAUCHY_STATELESS_A_B_A=PASS'
  write(*,'(a)') 'PPA_LOW03_CAUCHY_NONFINITE_AND_ZERO_RESISTANCE_FAIL_CLOSED=PASS'

contains

  subroutine check(sw, water_level, drainage_head, profile_shape, aquifer_head, &
                   layer_resistance, vertical_resistance, extra_q, want, label)
    integer, intent(in) :: sw
    real(real64), intent(in) :: water_level, drainage_head, profile_shape, aquifer_head
    real(real64), intent(in) :: layer_resistance, vertical_resistance, extra_q, want
    character(len=*), intent(in) :: label
    call evaluate_ppa_low03_cauchy_flux(sw, water_level, drainage_head, profile_shape, &
        aquifer_head, layer_resistance, vertical_resistance, extra_q, actual, status)
    if (status /= PPA_LOW03_CAUCHY_OK .or. abs(actual-want) > 16.0_real64*epsilon(want)) then
      write(*,'(a)') 'failed: '//label
      error stop 1
    end if
  end subroutine check

end program test_ppa_low03_cauchy_flux
