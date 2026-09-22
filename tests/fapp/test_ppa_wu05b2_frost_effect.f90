program test_ppa_wu05b2_frost_effect
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_wu05b2_frost_effect
  implicit none

  integer, parameter :: ncase = 100000
  integer :: seed_size, i, status, block
  integer, allocatable :: seed(:)
  real(real64) :: randoms(4), temperature(5), factor(5), factor_again(5)
  real(real64) :: conductivity_base(5), derivative_base(5), conductivity_floor, conductivity(5), derivative(5)
  real(real64) :: expected, expected_k, expected_dk, a_temperature(5), a_factor(5)
  real(real64) :: threshold_expected(5)

  call random_seed(size=seed_size)
  allocate(seed(seed_size))
  seed = [(65537 + 3571*i, i=1, seed_size)]
  call random_seed(put=seed)

  do i = 1, ncase
    call random_number(randoms)
    temperature = -15.0_real64 + randoms(1) * 25.0_real64
    conductivity_base = randoms(2) * 0.1_real64
    derivative_base = (randoms(3)-0.5_real64) * 0.01_real64
    conductivity_floor = randoms(4) * 1.0e-10_real64
    call random_number(randoms)
    call evaluate_ppa_wu05b2_frost_factor(1, -1.0_real64, -5.0_real64, temperature, factor, status)
    call require(status == PPA_WU05B2_OK, 'valid active frost factor rejected')
    call assert_factor_oracle(temperature, -1.0_real64, -5.0_real64, factor)
    call apply_ppa_wu05b2_hydraulic_frost_effect(1, factor, conductivity_base, conductivity_floor, &
        derivative_base, conductivity, derivative, status)
    call require(status == PPA_WU05B2_OK, 'valid hydraulic frost effect rejected')
    do block = 1, 5
      expected_k = conductivity_base(block) * factor(block) + conductivity_floor * (1.0_real64-factor(block))
      expected_dk = derivative_base(block) * factor(block)
      call require(same_bits(conductivity(block), expected_k), 'K frost algebra differs bitwise from B1.11')
      call require(same_bits(derivative(block), expected_dk), 'dK/dh frost algebra differs bitwise from B1.11')
    end do

    if (i == 1) then
      a_temperature = temperature
      a_factor = factor
    else if (i == 2) then
      call evaluate_ppa_wu05b2_frost_factor(1, -1.0_real64, -5.0_real64, a_temperature, factor_again, status)
      call require(status == PPA_WU05B2_OK .and. same_bits_vector(a_factor, factor_again), &
          'A/B/A thermal-factor replay changed')
    end if
  end do

  call evaluate_ppa_wu05b2_frost_factor(0, -1.0_real64, -5.0_real64, [-100.0_real64, 0.0_real64, 10.0_real64], &
      factor(1:3), status)
  call require(status == PPA_WU05B2_OK .and. all_same_value_bits(factor(1:3), 1.0_real64), 'SWFROST=0 identity route')
  call evaluate_ppa_wu05b2_frost_factor(1, -1.0_real64, -5.0_real64, &
      [-1.0_real64, -5.0_real64, -3.0_real64, -1.01_real64, -4.99_real64], factor, status)
  call require(status == PPA_WU05B2_OK, 'threshold regression case rejected')
  threshold_expected = [1.0_real64, 0.0_real64, 0.5_real64, 0.9975_real64, 0.0025_real64]
  call require(same_bits(factor(1), threshold_expected(1)) .and. same_bits(factor(2), threshold_expected(2)) .and. &
      maxval(abs(factor(3:)-threshold_expected(3:))) <= 2.0_real64*epsilon(1.0_real64), &
      'threshold/equality/interior frost factor cases')
  call evaluate_ppa_wu05b2_frost_factor(1, -5.0_real64, -1.0_real64, [-3.0_real64], factor(1:1), status)
  call require(status == PPA_WU05B2_OK .and. same_bits(factor(1), 1.0_real64), &
      'source ordered reversed-threshold fallback changed')

  call apply_ppa_wu05b2_hydraulic_frost_effect(0, [0.0_real64, 1.0_real64], [0.03_real64, 0.04_real64], &
      1.0e-12_real64, [-0.002_real64, 0.003_real64], conductivity(1:2), derivative(1:2), status)
  call require(status == PPA_WU05B2_OK .and. same_bits_vector(conductivity(1:2), [0.03_real64,0.04_real64]) .and. &
      same_bits_vector(derivative(1:2), [-0.002_real64,0.003_real64]), 'non-frost conductivity identity')
  temperature(1) = ieee_value(0.0_real64, ieee_quiet_nan)
  call evaluate_ppa_wu05b2_frost_factor(1, -1.0_real64, -5.0_real64, temperature, factor, status)
  call require(status == PPA_WU05B2_INVALID_INPUT, 'non-finite thermal input did not fail closed')

  print '(a)', 'PPA_WU05B2_EXACT_SOURCE_FACTOR_ORACLE_100000=PASS'
  print '(a)', 'PPA_WU05B2_K_AND_DKDH_SOURCE_ALGEBRA=PASS'
  print '(a)', 'PPA_WU05B2_STATELESS_A_B_A_AND_SWFROST_OFF=PASS'
  print '(a)', 'PPA_WU05B2_THRESHOLD_NONFINITE_AND_SOURCE_ORDER_GUARDS=PASS'

contains

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write (*, '(a)') 'PPA-WU05-B2 TEST FAILURE: '//message
      error stop 1
    end if
  end subroutine require

  subroutine assert_factor_oracle(t, tstart, tend, actual_factor)
    real(real64), intent(in) :: t(:), tstart, tend, actual_factor(:)
    integer :: node
    do node = 1, size(t)
      expected = legacy_rfcp(t(node), tstart, tend)
      call require(same_bits(actual_factor(node), expected), 'factor differs bitwise from B1.11 FrozenCond')
    end do
  end subroutine assert_factor_oracle

  pure real(real64) function legacy_rfcp(t, tstart, tend) result(rf)
    real(real64), intent(in) :: t, tstart, tend
    rf = 1.0_real64
    if (t >= tstart) then
      rf = 1.0_real64
    else if (t <= tend) then
      rf = 0.0_real64
    else if (t < tstart .and. t > tend) then
      rf = (t-tend)/(tstart-tend)
    end if
  end function legacy_rfcp

  pure logical function same_bits(left, right) result(equal)
    real(real64), intent(in) :: left, right
    equal = transfer(left, 0_int64) == transfer(right, 0_int64)
  end function same_bits

  pure logical function same_bits_vector(left, right) result(equal)
    real(real64), intent(in) :: left(:), right(:)
    integer :: k
    equal = .false.
    if (size(left) /= size(right)) return
    do k = 1, size(left)
      if (.not. same_bits(left(k), right(k))) return
    end do
    equal = .true.
  end function same_bits_vector

  pure logical function all_same_value_bits(values, target) result(equal)
    real(real64), intent(in) :: values(:), target
    integer :: k
    equal = .false.
    do k = 1, size(values)
      if (.not. same_bits(values(k), target)) return
    end do
    equal = .true.
  end function all_same_value_bits

end program test_ppa_wu05b2_frost_effect
