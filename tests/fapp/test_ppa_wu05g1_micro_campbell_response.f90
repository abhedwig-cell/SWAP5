program test_ppa_wu05g1_micro_campbell_response
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_wu05g1_micro_campbell_response
  implicit none
  integer :: i, status, sw
  real(real64) :: xp, dpl, tpot, plhalf, camp_a, alpha, actual, expected, a, b, replay

  call check(-2.0_real64, 0.5_real64, 0.4_real64, 0.02_real64, 2.0_real64, 1, 0.7_real64, 0.4_real64)
  call check(20.0_real64, 1.0_real64, 0.4_real64, 0.02_real64, 2.0_real64, 2, 0.7_real64, &
      0.4_real64/(1.0_real64+(21.0_real64*0.02_real64)**2.0_real64))
  call check(20.0_real64, 1.0_real64, 0.4_real64, 0.02_real64, 2.0_real64, 3, 0.5_real64, &
      0.4_real64/(1.0_real64+(21.0_real64*(0.02_real64/0.5_real64))**2.0_real64))

  do i = 1, 100000
    xp = real(mod(i * 37, 3001), real64) / 1000.0_real64
    dpl = real(mod(i * 17, 201), real64) / 1000.0_real64
    tpot = real(mod(i * 13, 1001), real64) / 1000.0_real64
    plhalf = real(mod(i * 19, 50) + 1, real64) / 1000.0_real64
    camp_a = real(mod(i * 23, 500) + 1, real64)
    alpha = real(mod(i * 29, 801) + 200, real64) / 1000.0_real64
    sw = mod(i, 4)
    if (xp + dpl < 0.0_real64) then
      expected = tpot
    else if (sw < 3) then
      expected = tpot/(1.0_real64+((xp+dpl)*plhalf)**camp_a)
    else
      expected = tpot/(1.0_real64+((xp+dpl)*(plhalf/alpha))**camp_a)
    end if
    call ppa_wu05g1_campbell_leaf_response(xp, dpl, tpot, plhalf, camp_a, sw, alpha, actual, status)
    if (status /= PPA_WU05G1_OK .or. .not. same_bits(actual, expected)) &
      error stop '100000-vector exact-source oracle mismatch'
  end do

  call ppa_wu05g1_campbell_leaf_response(1.0_real64, 0.1_real64, 0.4_real64, 0.02_real64, &
      2.0_real64, 1, 0.7_real64, a, status)
  call ppa_wu05g1_campbell_leaf_response(4.0_real64, 0.1_real64, 0.4_real64, 0.02_real64, &
      2.0_real64, 1, 0.7_real64, b, status)
  call ppa_wu05g1_campbell_leaf_response(1.0_real64, 0.1_real64, 0.4_real64, 0.02_real64, &
      2.0_real64, 1, 0.7_real64, replay, status)
  if (.not. same_bits(a, replay) .or. same_bits(a, b)) error stop 'A/B/A replay or fixture failed'
  call ppa_wu05g1_campbell_leaf_response(ieee_value(0.0_real64, ieee_quiet_nan), 0.0_real64, &
      0.4_real64, 0.02_real64, 2.0_real64, 1, 0.7_real64, actual, status)
  if (status /= PPA_WU05G1_INVALID_INPUT) error stop 'nonfinite input did not fail closed'
  call ppa_wu05g1_campbell_leaf_response(20.0_real64, 1.0_real64, 0.4_real64, 0.02_real64, &
      2.0_real64, 3, 0.0_real64, actual, status)
  if (status /= PPA_WU05G1_INVALID_INPUT) error stop 'zero swO2ECT=3 denominator admitted'

  write(*,'(a)') 'PPA_WU05G1_CAMPBELL_SOURCE_ORACLE_100000=PASS'
  write(*,'(a)') 'PPA_WU05G1_NEGATIVE_POTENTIAL_AND_SW_O2ECT_BRANCHES=PASS'
  write(*,'(a)') 'PPA_WU05G1_STATELESS_A_B_A=PASS'
  write(*,'(a)') 'PPA_WU05G1_NONFINITE_AND_SINGULAR_FAIL_CLOSED=PASS'

contains

  subroutine check(x, delta, potential, half_leaf, exponent, selector, alpha_in, want)
    real(real64), intent(in) :: x, delta, potential, half_leaf, exponent, alpha_in, want
    integer, intent(in) :: selector
    call ppa_wu05g1_campbell_leaf_response(x, delta, potential, half_leaf, exponent, selector, alpha_in, &
        actual, status)
    if (status /= PPA_WU05G1_OK .or. abs(actual-want) > 16.0_real64*epsilon(want)) &
      error stop 'edge-case mismatch'
  end subroutine check

  pure logical function same_bits(left, right)
    real(real64), intent(in) :: left, right
    same_bits = transfer(left, 0_int64) == transfer(right, 0_int64)
  end function same_bits

end program test_ppa_wu05g1_micro_campbell_response
