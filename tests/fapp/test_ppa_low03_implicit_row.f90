program test_ppa_low03_implicit_row
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_low03_implicit_row
  implicit none
  integer :: i, status, sw_res_vert, sw_extra
  real(real64) :: head, elevation, deepgw, spacing, conductivity, rimlay, extra
  real(real64) :: resistance, actual_q, actual_f, actual_j, expected_q, expected_f, expected_j
  real(real64) :: saved, replay, alternate

  call check(0, 0, -20.0_real64, -10.0_real64, 5.0_real64, 1.0_real64, &
      2.0_real64, 3.0_real64, 0.0_real64, 10.0_real64, 1.0_real64/3.5_real64, 'vertical resistance enabled')
  call check(1, 1, -20.0_real64, -10.0_real64, 5.0_real64, 1.0_real64, &
      2.0_real64, 3.0_real64, 1.5_real64, 35.0_real64/3.0_real64+1.5_real64, &
      1.0_real64/3.0_real64, 'vertical resistance suppressed with extra flux')

  do i = 1, 100000
    head = real(mod(i*37, 200001)-100000, real64) / 100.0_real64
    elevation = real(mod(i*17, 20001)-10000, real64) / 100.0_real64
    deepgw = real(mod(i*101, 110001)-100000, real64) / 10.0_real64
    spacing = real(mod(i*43, 100001)+1, real64) / 1000.0_real64
    conductivity = real(mod(i*29, 100001)+1, real64) / 100.0_real64
    rimlay = real(mod(i*23, 100001)+1, real64) / 10.0_real64
    extra = real(mod(i*13, 20001)-10000, real64) / 100.0_real64
    sw_res_vert = mod(i, 2)
    sw_extra = mod(i+1, 2)
    resistance = rimlay
    if (sw_res_vert == 0) resistance = spacing/conductivity + rimlay
    expected_q = -(head+elevation-deepgw)/resistance
    if (sw_extra == 1) expected_q = expected_q + extra
    expected_f = -expected_q
    expected_j = 1.0_real64/resistance
    call evaluate_ppa_low03_implicit_row(sw_res_vert, sw_extra, head, elevation, deepgw, &
        spacing, conductivity, rimlay, extra, actual_q, actual_f, actual_j, status)
    if (status /= PPA_LOW03_ROW_OK .or. transfer(actual_q, 0_int64) /= transfer(expected_q, 0_int64) .or. &
        transfer(actual_f, 0_int64) /= transfer(expected_f, 0_int64) .or. &
        transfer(actual_j, 0_int64) /= transfer(expected_j, 0_int64)) &
      error stop '100000-vector implicit Cauchy row oracle mismatch'
  end do

  call evaluate_ppa_low03_implicit_row(0, 1, -20.0_real64, -10.0_real64, 5.0_real64, &
      1.0_real64, 2.0_real64, 3.0_real64, 1.5_real64, saved, actual_f, actual_j, status)
  call evaluate_ppa_low03_implicit_row(1, 1, -20.0_real64, -10.0_real64, 5.0_real64, &
      1.0_real64, 2.0_real64, 3.0_real64, 1.5_real64, alternate, actual_f, actual_j, status)
  call evaluate_ppa_low03_implicit_row(0, 1, -20.0_real64, -10.0_real64, 5.0_real64, &
      1.0_real64, 2.0_real64, 3.0_real64, 1.5_real64, replay, actual_f, actual_j, status)
  if (transfer(saved, 0_int64) /= transfer(replay, 0_int64) .or. &
      transfer(saved, 0_int64) == transfer(alternate, 0_int64)) error stop 'A/B/A replay mismatch'

  call evaluate_ppa_low03_implicit_row(1, 0, 0.0_real64, 0.0_real64, 0.0_real64, &
      1.0_real64, 1.0_real64, 0.0_real64, 0.0_real64, actual_q, actual_f, actual_j, status)
  if (status /= PPA_LOW03_ROW_INVALID_INPUT) error stop 'zero head-boundary resistance accepted'
  call evaluate_ppa_low03_implicit_row(0, 0, ieee_value(0.0_real64, ieee_quiet_nan), &
      0.0_real64, 0.0_real64, 1.0_real64, 1.0_real64, 1.0_real64, 0.0_real64, &
      actual_q, actual_f, actual_j, status)
  if (status /= PPA_LOW03_ROW_INVALID_INPUT) error stop 'nonfinite solver-row input accepted'

  write(*,'(a)') 'PPA_LOW03_IMPLICIT_CAUCHY_QBOT_F_JACOBIAN_ORACLE_100000=PASS'
  write(*,'(a)') 'PPA_LOW03_IMPLICIT_CAUCHY_RESVERT_AND_SW4=PASS'
  write(*,'(a)') 'PPA_LOW03_IMPLICIT_CAUCHY_STATELESS_A_B_A=PASS'
  write(*,'(a)') 'PPA_LOW03_IMPLICIT_CAUCHY_INVALID_RESISTANCE_FAIL_CLOSED=PASS'

contains

  subroutine check(sw_res, sw_add, h, z, aquifer, dist, kbot, resistance_layer, qextra, &
                   want_q, want_j, label)
    integer, intent(in) :: sw_res, sw_add
    real(real64), intent(in) :: h, z, aquifer, dist, kbot, resistance_layer, qextra, want_q, want_j
    character(len=*), intent(in) :: label
    call evaluate_ppa_low03_implicit_row(sw_res, sw_add, h, z, aquifer, dist, kbot, &
        resistance_layer, qextra, actual_q, actual_f, actual_j, status)
    if (status /= PPA_LOW03_ROW_OK .or. abs(actual_q-want_q) > 16.0_real64*epsilon(want_q) .or. &
        abs(actual_j-want_j) > 16.0_real64*epsilon(want_j) .or. &
        abs(actual_f+want_q) > 16.0_real64*epsilon(want_q)) then
      write(*,'(a)') 'failed: '//label
      error stop 1
    end if
  end subroutine check

end program test_ppa_low03_implicit_row
