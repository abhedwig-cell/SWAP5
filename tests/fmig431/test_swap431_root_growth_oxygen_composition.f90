program test_swap431_root_growth_oxygen_composition
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_crop_root_depth_rate_owner
  implicit none
  type(crop_root_depth_rate_parameters_t)::p
  type(crop_root_depth_rate_state_t)::s,c
  type(crop_root_depth_rate_daily_forcing_t)::f
  type(crop_root_depth_rate_diagnostics_t)::d
  integer::status
  real(real64),parameter::tol=1e-12_real64

  p%initial_root_depth_cm=10._real64
  p%maximum_root_depth_cm=30._real64
  p%maximum_daily_extension_cm=5._real64
  p%require_root_growth=.true.
  p%negligible_transpiration=1e-10_real64
  p%negligible_root_growth=1e-10_real64
  p%negligible_extension=1e-12_real64
  p%anaerobic_extension_gate_enabled=.true.
  p%aeration_critical_factor=.4_real64
  call initialize_crop_root_depth_rate_state(p,s,status)
  if(status/=CROP_ROOT_RATE_OK)error stop 1

  f%potential_transpiration=1._real64
  f%actual_root_uptake=1._real64
  f%actual_root_growth=1._real64
  f%potential_root_growth=1._real64
  f%deepest_root_oxygen_factor_available=.true.

  ! Below AERATECRIT: potential extension proceeds, actual extension is stopped.
  f%deepest_root_oxygen_factor_integral=.399_real64
  call evaluate_crop_root_depth_rate_candidate(p,s,f,c,d,status)
  if(status/=CROP_ROOT_RATE_OK.or..not.d%candidate_built)error stop 2
  if(abs(c%potential_root_depth_cm-15._real64)>tol)error stop 3
  if(abs(c%actual_root_depth_cm-10._real64)>tol)error stop 4
  if(.not.d%potential_extension_allowed.or.d%actual_extension_allowed)error stop 5

  ! Equality is allowed because pinned B1.11 uses strict '<'.
  f%deepest_root_oxygen_factor_integral=.4_real64
  call evaluate_crop_root_depth_rate_candidate(p,s,f,c,d,status)
  if(status/=CROP_ROOT_RATE_OK)error stop 6
  if(abs(c%potential_root_depth_cm-15._real64)>tol.or.abs(c%actual_root_depth_cm-15._real64)>tol)error stop 7

  ! Gate enabled requires the accepted daily carrier.
  f%deepest_root_oxygen_factor_available=.false.
  f%deepest_root_oxygen_factor_integral=0._real64
  call evaluate_crop_root_depth_rate_candidate(p,s,f,c,d,status)
  if(status/=CROP_ROOT_RATE_INVALID_FORCING)error stop 8

  ! Gate disabled restores the pre-existing SWRD2 route without dependency.
  p%anaerobic_extension_gate_enabled=.false.
  call evaluate_crop_root_depth_rate_candidate(p,s,f,c,d,status)
  if(status/=CROP_ROOT_RATE_OK.or.abs(c%actual_root_depth_cm-15._real64)>tol)error stop 9

  print '(a)','SW431_ROOT_GROWTH_OXYGEN_COMPOSITION=PASS'
end program
