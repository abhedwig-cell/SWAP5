program test_ppa_wu05c1_oxygen_reproduction
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_wu05c1_oxygen_reproduction
  implicit none

  integer, parameter :: ncase = 100000
  integer :: seed_size, i, n, node, status, j
  integer, allocatable :: seed(:)
  real(real64) :: slope(6), intercept(6), theta(12), theta_s(12), tsoil(12), z(12), dz(12), zbot(12)
  real(real64) :: actual, expected, again, randoms(42), saved_slope(6), saved_intercept(6)
  real(real64) :: saved_theta(12), saved_theta_s(12), saved_tsoil(12), saved_z(12), saved_dz(12), saved_zbot(12)

  call random_seed(size=seed_size)
  allocate(seed(seed_size))
  seed = [(104729 + 7919*i, i=1, seed_size)]
  call random_seed(put=seed)

  do i = 1, ncase
    call random_number(randoms)
    n = 1 + int(randoms(1)*12.0_real64)
    node = 1 + int(randoms(2)*real(n, real64))
    slope = (randoms(3:8) - 0.5_real64) * 0.08_real64
    intercept = (randoms(9:14) - 0.5_real64) * 0.08_real64
    theta = randoms(15:26) * 0.55_real64
    theta_s = 0.2_real64 + randoms(27:38) * 0.5_real64
    call random_number(randoms(1:12))
    tsoil = -5.0_real64 + randoms(1:12) * 40.0_real64
    dz = 2.0_real64 + randoms(15:26) * 28.0_real64
    z = -dz
    do j = 2, 12
      z(j) = z(j-1) - dz(j)
    end do
    zbot = z - 0.5_real64*dz

    call evaluate_ppa_wu05c1_oxygen_reproduction(slope, intercept, theta(1:n), theta_s(1:n), &
        tsoil(1:n), z(1:n), dz(1:n), zbot(1:n), node, actual, status)
    expected = legacy_oxygen_repro(slope, intercept, theta, theta_s, tsoil, z, dz, zbot, node)
    call require(status == PPA_WU05C1_OK, 'valid legacy-domain input rejected')
    call require(same_bits(actual, expected), 'factor differs bitwise from exact-source equation oracle')

    ! A/B/A replay catches hidden call-history dependence in this stateless slice.
    saved_slope = slope; saved_intercept = intercept; saved_theta = theta; saved_theta_s = theta_s
    saved_tsoil = tsoil; saved_z = z; saved_dz = dz; saved_zbot = zbot
    slope = -slope
    call evaluate_ppa_wu05c1_oxygen_reproduction(slope, intercept, theta(1:n), theta_s(1:n), &
        tsoil(1:n), z(1:n), dz(1:n), zbot(1:n), node, again, status)
    call require(status == PPA_WU05C1_OK, 'B replay call failed')
    slope = saved_slope; intercept = saved_intercept; theta = saved_theta; theta_s = saved_theta_s
    tsoil = saved_tsoil; z = saved_z; dz = saved_dz; zbot = saved_zbot
    call evaluate_ppa_wu05c1_oxygen_reproduction(slope, intercept, theta(1:n), theta_s(1:n), &
        tsoil(1:n), z(1:n), dz(1:n), zbot(1:n), node, again, status)
    call require(status == PPA_WU05C1_OK .and. same_bits(actual, again), 'A/B/A replay is not deterministic')
  end do

  theta_s(1) = theta(1)
  theta(1) = 0.3_real64
  theta_s(1) = theta(1) + 0.5e-10_real64
  call evaluate_ppa_wu05c1_oxygen_reproduction(slope, intercept, theta(1:1), theta_s(1:1), &
      tsoil(1:1), z(1:1), dz(1:1), zbot(1:1), 1, actual, status)
  call require(status == PPA_WU05C1_OK .and. same_bits(actual, 0.0_real64), 'near-saturated local gas branch')

  theta(1) = 0.2_real64
  theta_s(1) = 0.4_real64
  call evaluate_ppa_wu05c1_oxygen_reproduction(slope, intercept, theta(1:1), theta_s(1:1), &
      tsoil(1:1), z(1:1), dz(1:1), zbot(1:1), 0, actual, status)
  call require(status == PPA_WU05C1_INVALID_INPUT, 'invalid node did not fail closed')
  theta(1) = ieee_value(0.0_real64, ieee_quiet_nan)
  call evaluate_ppa_wu05c1_oxygen_reproduction(slope, intercept, theta(1:1), theta_s(1:1), &
      tsoil(1:1), z(1:1), dz(1:1), zbot(1:1), 1, actual, status)
  call require(status == PPA_WU05C1_INVALID_INPUT, 'nonfinite hydraulic view did not fail closed')
  theta(1) = 0.2_real64
  call evaluate_ppa_wu05c1_oxygen_reproduction(slope, intercept, theta(1:1), theta_s(1:2), &
      tsoil(1:1), z(1:1), dz(1:1), zbot(1:1), 1, actual, status)
  call require(status == PPA_WU05C1_INVALID_INPUT, 'shape mismatch did not fail closed')
  zbot(1) = 0.0_real64
  call evaluate_ppa_wu05c1_oxygen_reproduction(slope, intercept, theta(1:1), theta_s(1:1), &
      tsoil(1:1), z(1:1), dz(1:1), zbot(1:1), 1, actual, status)
  call require(status == PPA_WU05C1_INVALID_INPUT, 'nonnegative bottom geometry did not fail closed')

  print '(a)', 'PPA_WU05C1_EXACT_SOURCE_FACTOR_ORACLE_100000=PASS'
  print '(a)', 'PPA_WU05C1_STATELESS_A_B_A_REPLAY=PASS'
  print '(a)', 'PPA_WU05C1_SHAPE_NUMERIC_GEOMETRY_GUARDS=PASS'
  print '(a)', 'PPA_WU05C1_SATURATION_BRANCH=PASS'

contains

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write (*, '(a)') 'PPA-WU05-C1 TEST FAILURE: '//message
      error stop 1
    end if
  end subroutine require

  logical function same_bits(left, right) result(equal)
    real(real64), intent(in) :: left, right
    equal = transfer(left, 0_int64) == transfer(right, 0_int64)
  end function same_bits

  real(real64) function legacy_oxygen_repro(oslope, ointercept, water, sat, temp, depth, thickness, bottom, k) result(factor)
    ! Line-for-line equation oracle from the hashed B1.11 OxygenReproFunction.
    real(real64), intent(in) :: oslope(6), ointercept(6), water(:), sat(:), temp(:), depth(:), thickness(:), bottom(:)
    integer, intent(in) :: k
    real(real64) :: intercept_local, slope_local, sum_porosity, gas_filled_porosity
    real(real64) :: soil_temp, depth_ss, mean_gas_filled_porosity
    integer :: j

    gas_filled_porosity = dmax1(0.0_real64, sat(k) - water(k))
    soil_temp = temp(k) + 273.0_real64
    depth_ss = -depth(k) * 0.01_real64
    if (gas_filled_porosity < 1.0e-10_real64) then
      factor = 0.0_real64
      return
    end if
    sum_porosity = 0.0_real64
    do j = 1, k
      sum_porosity = sum_porosity + (sat(j) - water(j)) * thickness(j)
    end do
    mean_gas_filled_porosity = sum_porosity / (-bottom(k))
    intercept_local = ointercept(1)*soil_temp**2 + ointercept(2)*depth_ss**2 + &
        ointercept(3)*soil_temp + ointercept(4)*depth_ss + ointercept(5)*soil_temp*depth_ss + ointercept(6)
    slope_local = oslope(1)*soil_temp**2 + oslope(2)*depth_ss**2 + &
        oslope(3)*soil_temp + oslope(4)*depth_ss + oslope(5)*soil_temp*depth_ss + oslope(6)
    factor = intercept_local + slope_local*mean_gas_filled_porosity
    if (factor > 1.0_real64) factor = 1.0_real64
    if (factor < 0.0_real64) factor = 0.0_real64
  end function legacy_oxygen_repro

end program test_ppa_wu05c1_oxygen_reproduction
