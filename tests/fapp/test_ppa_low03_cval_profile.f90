program test_ppa_low03_cval_profile
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_low03_cval_profile
  implicit none
  real(real64), parameter :: ztop(4) = [0.0_real64, -25.0_real64, -50.0_real64, -75.0_real64]
  real(real64), parameter :: zbot(4) = [-25.0_real64, -50.0_real64, -75.0_real64, -100.0_real64]
  real(real64), parameter :: thick(4) = [25.0_real64, 25.0_real64, 25.0_real64, 25.0_real64]
  real(real64), parameter :: kv(4) = [2.0_real64, 4.0_real64, 5.0_real64, 10.0_real64]
  real(real64) :: level, actual, expected, saved, replay, alternate
  integer :: i, status

  call check(0.0_real64, 25.0_real64/2.0_real64 + 25.0_real64/4.0_real64 + &
      25.0_real64/5.0_real64 + 25.0_real64/10.0_real64, 'profile surface')
  call check(-60.0_real64, 15.0_real64/5.0_real64 + 25.0_real64/10.0_real64, 'interior compartment')
  call check(-100.0_real64, 0.0_real64, 'bottom boundary')
  call evaluate_ppa_low03_cval_profile(0, ztop, zbot, thick, kv, &
      ieee_value(0.0_real64, ieee_quiet_nan), actual, status)
  if (status /= PPA_LOW03_CVAL_INVALID_INPUT) error stop 'nonfinite groundwater level accepted'
  call evaluate_ppa_low03_cval_profile(1, ztop, zbot, thick, kv, 1.0_real64, actual, status)
  if (status /= PPA_LOW03_CVAL_OK .or. transfer(actual, 0_int64) /= 0_int64) &
    error stop 'vertical resistance suppress switch failed'

  do i = 1, 100000
    level = -100.0_real64 + real(mod(i*7919, 100001), real64) / 1000.0_real64
    expected = source_cval(ztop, zbot, thick, kv, level)
    call evaluate_ppa_low03_cval_profile(0, ztop, zbot, thick, kv, level, actual, status)
    if (status /= PPA_LOW03_CVAL_OK .or. transfer(actual, 0_int64) /= transfer(expected, 0_int64)) &
      error stop '100000-vector SWBOTB3RESVERT=0 source oracle mismatch'
  end do

  call evaluate_ppa_low03_cval_profile(0, ztop, zbot, thick, kv, -60.0_real64, saved, status)
  call evaluate_ppa_low03_cval_profile(0, ztop, zbot, thick, [2.0_real64, 4.0_real64, 6.0_real64, 10.0_real64], &
      -60.0_real64, alternate, status)
  call evaluate_ppa_low03_cval_profile(0, ztop, zbot, thick, kv, -60.0_real64, replay, status)
  if (transfer(saved, 0_int64) /= transfer(replay, 0_int64) .or. &
      transfer(saved, 0_int64) == transfer(alternate, 0_int64)) error stop 'A/B/A replay mismatch'
  call evaluate_ppa_low03_cval_profile(0, ztop, zbot, thick, kv, -101.0_real64, actual, status)
  if (status /= PPA_LOW03_CVAL_INVALID_INPUT) error stop 'out-of-profile groundwater level accepted'
  call evaluate_ppa_low03_cval_profile(0, ztop, zbot, thick, [2.0_real64, 4.0_real64, 0.0_real64, 10.0_real64], &
      -60.0_real64, actual, status)
  if (status /= PPA_LOW03_CVAL_INVALID_INPUT) error stop 'nonpositive layer conductivity accepted'

  write(*,'(a)') 'PPA_LOW03_CVAL_PROFILE_SOURCE_ORACLE_100000=PASS'
  write(*,'(a)') 'PPA_LOW03_CVAL_NODE_AND_SATURATED_THICKNESS=PASS'
  write(*,'(a)') 'PPA_LOW03_CVAL_RESVERT_SWITCH_AND_A_B_A=PASS'
  write(*,'(a)') 'PPA_LOW03_CVAL_INVALID_PROFILE_FAIL_CLOSED=PASS'

contains

  subroutine check(water_level, want, label)
    real(real64), intent(in) :: water_level, want
    character(len=*), intent(in) :: label
    call evaluate_ppa_low03_cval_profile(0, ztop, zbot, thick, kv, water_level, actual, status)
    if (status /= PPA_LOW03_CVAL_OK .or. abs(actual-want) > 16.0_real64*epsilon(want)) then
      write(*,'(a)') 'failed: '//label
      error stop 1
    end if
  end subroutine check

  pure real(real64) function source_cval(top, bottom, thickness, conductivity, water_level) result(resistance)
    real(real64), intent(in) :: top(:), bottom(:), thickness(:), conductivity(:), water_level
    integer :: node, cell
    real(real64) :: saturated
    node = size(top)
    do while (water_level > top(node) .and. node > 1)
      node = node - 1
    end do
    saturated = water_level - bottom(node)
    resistance = saturated / conductivity(node)
    do cell = node + 1, size(top)
      resistance = resistance + thickness(cell) / conductivity(cell)
    end do
  end function source_cval

end program test_ppa_low03_cval_profile
