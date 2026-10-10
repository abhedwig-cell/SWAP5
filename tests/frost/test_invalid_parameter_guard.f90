program test_invalid_parameter_guard
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_frost_hydraulic_effect
  implicit none
  type(frost_hydraulic_parameters_t) :: p
  p%active = .true.
  p%reduction_start_c = ieee_value(0.0_real64, ieee_quiet_nan)
  p%reduction_end_c = -2.0_real64
  if (p%valid()) error stop 'NaN threshold accepted'
  print '(a)', 'INVALID_PARAMETER_GUARD=PASS'
end program
