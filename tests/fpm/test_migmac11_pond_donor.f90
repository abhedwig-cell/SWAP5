program test_migmac11_pond_donor
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_macropore_top_input, only: fmr_macropore_pond_donor_request_t, evaluate_fmr_macropore_pond_donor
  implicit none
  type(fmr_macropore_pond_donor_request_t) :: r
  real(real64) :: q, rsro, p2, p2mp, expected
  logical :: ok

  r%threshold_cm=0.2_real64
  r%surface_conductance_step=0.4_real64
  r%macropore_surface_conductivity_cm_per_day=3.0_real64
  r%step_duration_day=0.25_real64

  call evaluate_fmr_macropore_pond_donor(r,q,ok)
  if(.not.ok .or. q/=0.0_real64) error stop 'dry'

  r%no_macro_ponding_depth_cm=0.2_real64
  call evaluate_fmr_macropore_pond_donor(r,q,ok)
  if(.not.ok .or. q/=0.0_real64) error stop 'threshold'

  r%no_macro_ponding_depth_cm=0.5_real64
  r%direct_macro_input_cm=0.1_real64
  rsro=(0.5_real64+0.1_real64)/3.0_real64
  p2=1.0_real64/(0.4_real64+1.0_real64)
  p2mp=1.0_real64/(0.4_real64+1.0_real64+0.25_real64/rsro)
  expected=min((0.5_real64-0.2_real64)*p2mp/p2*0.25_real64/rsro,0.5_real64)
  call evaluate_fmr_macropore_pond_donor(r,q,ok)
  if(.not.ok .or. abs(q-expected)>1.0e-14_real64) error stop 'wet exact'

  r%no_macro_ponding_depth_cm=1.0e-8_real64
  r%threshold_cm=0.0_real64
  r%direct_macro_input_cm=0.0_real64
  call evaluate_fmr_macropore_pond_donor(r,q,ok)
  if(.not.ok .or. q/=0.0_real64) error stop 'source cutoff'

  r%no_macro_ponding_depth_cm=0.5_real64
  r%macropore_surface_conductivity_cm_per_day=0.0_real64
  call evaluate_fmr_macropore_pond_donor(r,q,ok)
  if(ok) error stop 'zero conductivity must fail closed'

  print '(a)', 'MIGMAC11_POND_DONOR_B111=PASS'
end program test_migmac11_pond_donor
