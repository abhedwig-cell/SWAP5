program test_ppa_low01_gwl_surface_profile
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_low01_gwl_surface_profile
  implicit none
  integer, parameter :: n = 5
  real(real64) :: dz(n), macro_fraction(n), theta(n), theta_previous(n)
  real(real64) :: sink(n), source(n), qrot(n), disnod(n), kmean(n)
  real(real64) :: qv(n+1), head(n), qbot, expected_qv(n+1), expected_head(n), expected_qbot
  real(real64) :: dt, gwlinp, qv1, saved, replay, alternate
  integer :: i, j, status

  dz = [10.0_real64, 12.0_real64, 14.0_real64, 16.0_real64, 18.0_real64]
  macro_fraction = [1.0_real64, 0.8_real64, 0.6_real64, 0.4_real64, 0.2_real64]
  theta = [0.30_real64, 0.32_real64, 0.28_real64, 0.25_real64, 0.22_real64]
  theta_previous = [0.31_real64, 0.30_real64, 0.29_real64, 0.24_real64, 0.20_real64]
  sink = [0.01_real64, 0.02_real64, 0.03_real64, 0.04_real64, 0.05_real64]
  source = [0.02_real64, 0.01_real64, 0.02_real64, 0.03_real64, 0.01_real64]
  qrot = [0.0_real64, 0.01_real64, -0.01_real64, 0.02_real64, 0.0_real64]
  disnod = [5.0_real64, 11.0_real64, 13.0_real64, 15.0_real64, 17.0_real64]
  kmean = [2.0_real64, 1.5_real64, 1.2_real64, 0.9_real64, 0.7_real64]
  call check(-0.00005_real64, 0.15_real64, 0.5_real64, 'surface prescribed head seed')

  do i = 1, 100000
    do j = 1, n
      theta(j) = real(mod(i*37+j*109, 100001), real64) / 100000.0_real64
      theta_previous(j) = real(mod(i*17+j*43, 100001), real64) / 100000.0_real64
      sink(j) = real(mod(i*101+j*13, 20001)-10000, real64) / 100000.0_real64
      source(j) = real(mod(i*29+j*71, 20001)-10000, real64) / 100000.0_real64
      qrot(j) = real(mod(i*23+j*31, 20001)-10000, real64) / 100000.0_real64
    end do
    gwlinp = -real(mod(i*7919, 100000), real64) / 10000.0_real64
    qv1 = real(mod(i*11, 200001)-100000, real64) / 10000.0_real64
    dt = real(mod(i*7, 100000)+1, real64) / 10000.0_real64
    call source_profile(gwlinp, qv1, dt, expected_qv, expected_head, expected_qbot)
    call evaluate_ppa_low01_gwl_surface_profile(gwlinp, qv1, dt, dz, macro_fraction, theta, &
        theta_previous, sink, source, qrot, disnod, kmean, qv, head, qbot, status)
    if (status /= PPA_LOW01_SURFACE_OK .or. any(transfer(qv, [0_int64], n+1) /= &
        transfer(expected_qv, [0_int64], n+1)) .or. &
        any(transfer(head, [0_int64], n) /= transfer(expected_head, [0_int64], n)) .or. &
        transfer(qbot, 0_int64) /= transfer(expected_qbot, 0_int64)) &
      error stop '100000-vector surface GWL profile source oracle mismatch'
  end do

  call evaluate_ppa_low01_gwl_surface_profile(-0.00005_real64, 0.15_real64, 0.5_real64, dz, &
      macro_fraction, theta, theta_previous, sink, source, qrot, disnod, kmean, qv, head, saved, status)
  call evaluate_ppa_low01_gwl_surface_profile(-0.00005_real64, 0.25_real64, 0.5_real64, dz, &
      macro_fraction, theta, theta_previous, sink, source, qrot, disnod, kmean, qv, head, alternate, status)
  call evaluate_ppa_low01_gwl_surface_profile(-0.00005_real64, 0.15_real64, 0.5_real64, dz, &
      macro_fraction, theta, theta_previous, sink, source, qrot, disnod, kmean, qv, head, replay, status)
  if (transfer(saved, 0_int64) /= transfer(replay, 0_int64) .or. &
      transfer(saved, 0_int64) == transfer(alternate, 0_int64)) error stop 'A/B/A replay mismatch'
  call evaluate_ppa_low01_gwl_surface_profile(0.0_real64, 0.0_real64, 0.0_real64, dz, &
      macro_fraction, theta, theta_previous, sink, source, qrot, disnod, kmean, qv, head, qbot, status)
  if (status /= PPA_LOW01_SURFACE_INVALID_INPUT) error stop 'zero timestep accepted'
  call evaluate_ppa_low01_gwl_surface_profile(0.0_real64, 0.0_real64, 1.0_real64, dz, &
      macro_fraction, theta, theta_previous, sink, source, qrot, disnod, &
      [2.0_real64, 1.5_real64, 0.0_real64, 0.9_real64, 0.7_real64], qv, head, qbot, status)
  if (status /= PPA_LOW01_SURFACE_INVALID_INPUT) error stop 'zero conductivity accepted'
  call evaluate_ppa_low01_gwl_surface_profile(0.0_real64, ieee_value(0.0_real64, ieee_quiet_nan), &
      1.0_real64, dz, macro_fraction, theta, theta_previous, sink, source, qrot, disnod, kmean, &
      qv, head, qbot, status)
  if (status /= PPA_LOW01_SURFACE_INVALID_INPUT) error stop 'nonfinite top flux accepted'

  write(*,'(a)') 'PPA_LOW01_GWL_SURFACE_PROFILE_SOURCE_ORACLE_100000=PASS'
  write(*,'(a)') 'PPA_LOW01_GWL_SURFACE_HEAD_AND_QBOT=PASS'
  write(*,'(a)') 'PPA_LOW01_GWL_SURFACE_STATELESS_A_B_A=PASS'
  write(*,'(a)') 'PPA_LOW01_GWL_SURFACE_INVALID_PROFILE_FAIL_CLOSED=PASS'

contains

  subroutine check(level, boundary_flux, timestep, label)
    real(real64), intent(in) :: level, boundary_flux, timestep
    character(len=*), intent(in) :: label
    call source_profile(level, boundary_flux, timestep, expected_qv, expected_head, expected_qbot)
    call evaluate_ppa_low01_gwl_surface_profile(level, boundary_flux, timestep, dz, macro_fraction, &
        theta, theta_previous, sink, source, qrot, disnod, kmean, qv, head, qbot, status)
    if (status /= PPA_LOW01_SURFACE_OK .or. any(transfer(qv, [0_int64], n+1) /= &
        transfer(expected_qv, [0_int64], n+1)) .or. &
        any(transfer(head, [0_int64], n) /= transfer(expected_head, [0_int64], n)) .or. &
        transfer(qbot, 0_int64) /= transfer(expected_qbot, 0_int64)) then
      write(*,'(a)') 'failed: '//label
      error stop 1
    end if
  end subroutine check

  subroutine source_profile(level, boundary_flux, timestep, flux, heads, bottom_flux)
    real(real64), intent(in) :: level, boundary_flux, timestep
    real(real64), intent(out) :: flux(n+1), heads(n), bottom_flux
    integer :: cell
    flux(1) = boundary_flux
    heads(1) = level + disnod(1)*(flux(1)/kmean(1)+1.0_real64)
    do cell = 1, n
      flux(cell+1) = flux(cell) + dz(cell)*macro_fraction(cell)*(theta(cell)-theta_previous(cell))/timestep + &
          sink(cell)-source(cell)+qrot(cell)
    end do
    do cell = 2, n
      heads(cell) = heads(cell-1)+disnod(cell)*(flux(cell)/kmean(cell)+1.0_real64)
    end do
    bottom_flux = flux(n+1)
  end subroutine source_profile

end program test_ppa_low01_gwl_surface_profile
