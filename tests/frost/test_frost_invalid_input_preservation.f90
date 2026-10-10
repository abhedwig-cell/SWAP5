! Regression: invalid hydraulic arrays must fail closed even with floating-point traps.
program test_frost_invalid_input_preservation
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_frost_hydraulic_effect
  implicit none
  real(real64) :: factors(3), k(3), dk(3), before_k(3), before_dk(3)
  integer :: status
  factors = [1.0_real64, 0.5_real64, -0.1_real64]
  k = [2.0_real64, 3.0_real64, 4.0_real64]
  dk = [5.0_real64, 6.0_real64, 7.0_real64]
  before_k = k
  before_dk = dk
  call apply_frost_hydraulic_conductivity(factors, k, dk, status)
  call require_failure(FROST_EFFECT_INVALID_HYDRAULICS)
  factors(3) = ieee_value(0.0_real64, ieee_quiet_nan)
  call apply_frost_hydraulic_conductivity(factors, k, dk, status)
  call require_failure(FROST_EFFECT_INVALID_HYDRAULICS)
  factors(3) = 1.0_real64
  k(2) = -1.0_real64
  before_k = k
  call apply_frost_hydraulic_conductivity(factors, k, dk, status)
  call require_failure(FROST_EFFECT_INVALID_HYDRAULICS)
  call apply_frost_hydraulic_conductivity(factors(:2), k, dk, status)
  call require_failure(FROST_EFFECT_INVALID_SHAPE)
  print '(a)', 'FROST_INVALID_INPUT_PRESERVATION=PASS'
contains
  subroutine require_failure(expected)
    integer, intent(in) :: expected
    if (status /= expected) error stop 'unexpected invalid-input status'
    if (any(abs(k-before_k) > 0.0_real64)) error stop 'invalid input mutated conductivity'
    if (any(abs(dk-before_dk) > 0.0_real64)) error stop 'invalid input mutated derivative'
  end subroutine
end program
