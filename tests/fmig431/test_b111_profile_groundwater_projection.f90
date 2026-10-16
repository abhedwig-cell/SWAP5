program test_b111_profile_groundwater_projection
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b111_profile_groundwater_projection
  implicit none
  real(real64) :: z(4),d(4),h(4)
  type(b111_profile_groundwater_projection_t) :: r
  z=[-0.25_real64,-0.75_real64,-1.50_real64,-2.50_real64]
  d=1.0_real64

  h=[-1.25_real64,-0.75_real64,0.0_real64,1.0_real64]
  call evaluate_b111_profile_groundwater_projection(z,d,h,0.0_real64,r)
  if(.not.r%valid.or..not.r%level_present.or.r%status/=B111_PROFILE_GWL_INTERIOR)error stop 1
  if(r%crossing_lower_node/=2.or.abs(r%level_cm+1.5_real64)>1.0e-14_real64)error stop 2

  h=-1.0_real64
  call evaluate_b111_profile_groundwater_projection(z,d,h,0.0_real64,r)
  if(.not.r%valid.or.r%level_present.or.r%status/=B111_PROFILE_GWL_BELOW_PROFILE)error stop 3

  h=[0.0_real64,0.5_real64,1.0_real64,2.0_real64]
  call evaluate_b111_profile_groundwater_projection(z,d,h,0.0_real64,r)
  if(.not.r%valid.or..not.r%level_present.or.r%status/=B111_PROFILE_GWL_FULLY_SATURATED)error stop 4
  if(abs(r%level_cm)>1.0e-14_real64)error stop 5

  h=[1.0_real64,1.5_real64,2.0_real64,3.0_real64]
  call evaluate_b111_profile_groundwater_projection(z,d,h,0.3_real64,r)
  if(.not.r%valid.or.r%status/=B111_PROFILE_GWL_FULLY_SATURATED)error stop 6
  if(abs(r%level_cm-0.3_real64)>1.0e-14_real64)error stop 7

  print '(a)','SW431-LOW3-PROFILE-GWL=PASS'
end program
