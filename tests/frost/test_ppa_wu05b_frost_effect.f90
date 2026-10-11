program test_ppa_wu05b_frost_effect
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_frost_hydraulic_effect
  implicit none

  type(frost_hydraulic_parameters_t) :: p, off
  real(real64) :: t(7), f(7), k(7), dk(7), expected(7), cycle_f(7)
  integer :: status

  call initialize_frost_hydraulic_parameters(2.0_real64, -2.0_real64, p, status)
  call require(status == FROST_EFFECT_OK .and. p%valid(), 'valid ordered thresholds')

  t = [3.0_real64, 2.0_real64, 1.0_real64, 0.0_real64, -1.0_real64, -2.0_real64, -8.0_real64]
  call evaluate_frost_hydraulic_factor(p, t, f, status)
  call require(status == FROST_EFFECT_OK, 'evaluate bounded freezing profile')
  expected = [1.0_real64, 1.0_real64, 0.75_real64, 0.5_real64, 0.25_real64, 0.0_real64, 0.0_real64]
  call require(maxval(abs(f-expected)) <= 4.0_real64*epsilon(1.0_real64), 'independent piecewise factor oracle')

  ! Recalculation has no hidden freeze/thaw memory or mutation of configuration.
  t = [-3.0_real64, -1.0_real64, 0.0_real64, 2.0_real64, 1.0_real64, -2.0_real64, 3.0_real64]
  call evaluate_frost_hydraulic_factor(p, t, cycle_f, status)
  call require(status == FROST_EFFECT_OK, 'freeze-thaw factor evaluation')
  call require(abs(cycle_f(2)-0.25_real64) <= 4.0_real64*epsilon(1.0_real64), 'thaw transition recalculated')
  call evaluate_frost_hydraulic_factor(p, t, f, status)
  call require(status == FROST_EFFECT_OK .and. maxval(abs(f-cycle_f)) <= epsilon(1.0_real64), &
       'same committed temperature reproduces factor')
  call require(p%valid() .and. p%active, 'evaluation does not mutate parameters')

  k = 4.0_real64
  dk = 8.0_real64
  f = [1.0_real64, 1.0_real64, 0.75_real64, 0.5_real64, 0.25_real64, 0.0_real64, 0.0_real64]
  call apply_frost_hydraulic_conductivity(f, k, dk, status)
  call require(status == FROST_EFFECT_OK, 'apply conductivity modifier')
  call require(abs(k(1)-4.0_real64) < 1.0e-14_real64, 'unfrozen K is preserved')
  call require(abs(k(3)-(3.0_real64+0.25_real64*FROST_LEGACY_RESIDUAL_K_CM_PER_DAY)) < 1.0e-14_real64, &
       'partial K uses same factor and residual floor')
  call require(abs(k(6)-FROST_LEGACY_RESIDUAL_K_CM_PER_DAY) < 1.0e-25_real64, &
       'fully reduced K uses named legacy floor')
  call require(abs(dk(3)-6.0_real64) < 1.0e-14_real64 .and. abs(dk(6)) < 1.0e-30_real64, &
       'dK/dh uses same factor without differentiating temperature')

  call initialize_frost_hydraulic_parameters(-2.0_real64, -2.0_real64, p, status)
  call require(status == FROST_EFFECT_INVALID_CONFIGURATION .and. .not. p%active, 'equal thresholds fail closed')
  call initialize_frost_hydraulic_parameters(-3.0_real64, 1.0_real64, p, status)
  call require(status == FROST_EFFECT_INVALID_CONFIGURATION .and. .not. p%active, 'reversed thresholds fail closed')
  call initialize_frost_hydraulic_parameters(ieee_value(0.0_real64,ieee_quiet_nan), -2.0_real64, p, status)
  call require(status == FROST_EFFECT_INVALID_CONFIGURATION, 'nonfinite thresholds fail closed')

  call initialize_frost_hydraulic_parameters(0.0_real64, 0.0_real64, off, status)
  call require(status == FROST_EFFECT_INVALID_CONFIGURATION, 'no active config produced for equal thresholds')
  off = frost_hydraulic_parameters_t()
  t(1) = ieee_value(0.0_real64,ieee_quiet_nan)
  call evaluate_frost_hydraulic_factor(off, t, f, status)
  call require(status == FROST_EFFECT_OK .and. maxval(abs(f-1.0_real64)) <= epsilon(1.0_real64), &
       'frost-off route preserves K despite unused temperature')

  call initialize_frost_hydraulic_parameters(2.0_real64, -2.0_real64, p, status)
  t = 1.0_real64
  t(4) = ieee_value(0.0_real64,ieee_quiet_nan)
  call evaluate_frost_hydraulic_factor(p, t, f, status)
  call require(status == FROST_EFFECT_INVALID_TEMPERATURE .and. maxval(abs(f-1.0_real64)) <= epsilon(1.0_real64), &
       'invalid temperature fails closed without partial output')
  print '(a)', 'PPA-WU05B frost effect: PASS'

contains

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a)') 'FAIL: '//trim(message)
      error stop 1
    end if
  end subroutine require

end program test_ppa_wu05b_frost_effect
