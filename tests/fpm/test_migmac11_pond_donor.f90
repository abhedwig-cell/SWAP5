program test_migmac11_pond_donor
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_macropore_top_input, only: fmr_macropore_pond_donor_request_t, evaluate_fmr_macropore_pond_donor
  implicit none
  type(fmr_macropore_pond_donor_request_t) :: r
  real(real64) :: q
  logical :: ok

  r%threshold_cm=0.2_real64; r%resistance_day=0.5_real64; r%coupled_denominator=2.0_real64
  r%available_surface_water_cm=1.0_real64
  call evaluate_fmr_macropore_pond_donor(r,q,ok)
  if(.not.ok .or. q/=0.0_real64) error stop 'dry'

  r%no_macro_ponding_depth_cm=0.2_real64
  call evaluate_fmr_macropore_pond_donor(r,q,ok)
  if(.not.ok .or. q/=0.0_real64) error stop 'threshold'

  r%no_macro_ponding_depth_cm=0.5_real64
  call evaluate_fmr_macropore_pond_donor(r,q,ok)
  if(.not.ok .or. abs(q-0.15_real64)>1.0e-14_real64) error stop 'wet'

  r%available_surface_water_cm=0.1_real64
  call evaluate_fmr_macropore_pond_donor(r,q,ok)
  if(.not.ok .or. abs(q-0.1_real64)>1.0e-14_real64) error stop 'cap'

  r%direct_macro_input_cm=0.1_real64; r%available_surface_water_cm=1.0_real64
  call evaluate_fmr_macropore_pond_donor(r,q,ok)
  if(.not.ok .or. abs(q-0.2_real64)>1.0e-14_real64) error stop 'direct'

  print '(a)', 'MIGMAC11_POND_DONOR=PASS'
end program test_migmac11_pond_donor
