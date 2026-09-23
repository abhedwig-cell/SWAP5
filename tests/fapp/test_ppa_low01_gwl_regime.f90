program test_ppa_low01_gwl_regime
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_low01_gwl_regime
  implicit none
  real(real64), parameter :: z(6) = [0.0_real64, -25.0_real64, -50.0_real64, &
      -75.0_real64, -100.0_real64, -125.0_real64]
  real(real64), parameter :: dz(5) = [25.0_real64, 25.0_real64, 25.0_real64, 25.0_real64, 25.0_real64]
  real(real64) :: gwl, snapped, hbot, expected_snap, expected_hbot, saved, replay
  integer :: i, regime, nn, status, expected_regime, expected_nn

  call check(-0.00005_real64, PPA_LOW01_REGIME_FIXED_TOP, 0, -0.00005_real64, 0.0_real64, 'fixed top')
  call check(-25.00005_real64, PPA_LOW01_REGIME_WITHIN_PROFILE, 1, -25.0_real64, 0.0_real64, 'near-node snap')
  call check(-62.5_real64, PPA_LOW01_REGIME_WITHIN_PROFILE, 3, -62.5_real64, 0.0_real64, 'within profile')
  call check(-130.0_real64, PPA_LOW01_REGIME_BELOW_PROFILE, 5, -130.0_real64, -17.5_real64, 'below profile')

  do i = 1, 100000
    gwl = -150.0_real64 + real(mod(i*7919, 1500001), real64) / 10000.0_real64
    call source_regime(z, dz, 1.0e-8_real64, gwl, expected_regime, expected_nn, expected_snap, expected_hbot)
    call classify_ppa_low01_gwl_regime(z, dz, 1.0e-8_real64, gwl, regime, nn, snapped, hbot, status)
    if (status /= expected_regime .or. regime /= expected_regime .or. nn /= expected_nn .or. &
        transfer(snapped, 0_int64) /= transfer(expected_snap, 0_int64) .or. &
        transfer(hbot, 0_int64) /= transfer(expected_hbot, 0_int64)) &
      error stop '100000-vector SWBOTB=1 regime source oracle mismatch'
  end do

  call classify_ppa_low01_gwl_regime(z, dz, 1.0e-8_real64, -62.5_real64, &
      regime, nn, saved, hbot, status)
  call classify_ppa_low01_gwl_regime(z, dz, 1.0e-8_real64, -87.5_real64, &
      regime, nn, replay, hbot, status)
  call classify_ppa_low01_gwl_regime(z, dz, 1.0e-8_real64, -62.5_real64, &
      regime, nn, snapped, hbot, status)
  if (transfer(saved, 0_int64) /= transfer(snapped, 0_int64) .or. &
      transfer(saved, 0_int64) == transfer(replay, 0_int64)) error stop 'A/B/A replay mismatch'

  call classify_ppa_low01_gwl_regime(z, dz, ieee_value(0.0_real64, ieee_quiet_nan), &
      -20.0_real64, regime, nn, snapped, hbot, status)
  if (status == PPA_LOW01_REGIME_WITHIN_PROFILE) error stop 'nonfinite threshold accepted'
  call classify_ppa_low01_gwl_regime(z, [25.0_real64, 25.0_real64], 1.0e-8_real64, &
      -20.0_real64, regime, nn, snapped, hbot, status)
  if (status == PPA_LOW01_REGIME_WITHIN_PROFILE) error stop 'mismatched grid accepted'

  write(*,'(a)') 'PPA_LOW01_HEADCALC_GWL_REGIME_SOURCE_ORACLE_100000=PASS'
  write(*,'(a)') 'PPA_LOW01_GWL_FIXED_TOP_PROFILE_AND_BELOW=PASS'
  write(*,'(a)') 'PPA_LOW01_GWL_NEAR_NODE_SNAP_AND_HBOT=PASS'
  write(*,'(a)') 'PPA_LOW01_GWL_STATELESS_A_B_A_AND_INVALID_GRID=PASS'

contains

  subroutine check(water_level, want_regime, want_nn, want_snap, want_hbot, label)
    real(real64), intent(in) :: water_level, want_snap, want_hbot
    integer, intent(in) :: want_regime, want_nn
    character(len=*), intent(in) :: label
    call classify_ppa_low01_gwl_regime(z, dz, 1.0e-8_real64, water_level, regime, nn, snapped, hbot, status)
    if (status /= want_regime .or. regime /= want_regime .or. nn /= want_nn .or. &
        abs(snapped-want_snap) > 16.0_real64*epsilon(want_snap) .or. &
        abs(hbot-want_hbot) > 16.0_real64*epsilon(want_hbot)) then
      write(*,'(a)') 'failed: '//label
      error stop 1
    end if
  end subroutine check

  pure subroutine source_regime(z_nodes, widths, zero_tol, water_level, kind, count, snapped_level, bottom_head)
    real(real64), intent(in) :: z_nodes(:), widths(:), zero_tol, water_level
    integer, intent(out) :: kind, count
    real(real64), intent(out) :: snapped_level, bottom_head
    integer :: n
    n = size(z_nodes)-1
    count = 0
    snapped_level = water_level
    bottom_head = 0.0_real64
    if (water_level >= z_nodes(1)-1.0e-4_real64) then
      kind = PPA_LOW01_REGIME_FIXED_TOP
      return
    end if
    do while (z_nodes(count+1) > water_level .and. count < n)
      count = count+1
    end do
    if (z_nodes(count+1) < water_level + zero_tol) then
      kind = PPA_LOW01_REGIME_WITHIN_PROFILE
      if ((z_nodes(count)-water_level) < 1.0e-4_real64 .and. count > 0) then
        snapped_level = z_nodes(count)
        count = count-1
      end if
    else
      kind = PPA_LOW01_REGIME_BELOW_PROFILE
      bottom_head = water_level-z_nodes(n)+0.5_real64*widths(n)
    end if
  end subroutine source_regime

end program test_ppa_low01_gwl_regime
