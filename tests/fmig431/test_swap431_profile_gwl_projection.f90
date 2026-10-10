program test_swap431_profile_gwl_projection
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b111_profile_groundwater_projection
  implicit none
  real(real64) :: z(4), d(4), h(4)
  type(b111_profile_groundwater_projection_t) :: r
  z=[-5.0_real64,-15.0_real64,-25.0_real64,-35.0_real64]
  d=[5.0_real64,10.0_real64,10.0_real64,10.0_real64]

  h=[-20.0_real64,-5.0_real64,5.0_real64,20.0_real64]
  call evaluate_b111_profile_groundwater_projection(z,d,h,0.0_real64,r)
  if(.not.r%valid .or. .not.r%level_present .or. r%status/=B111_PROFILE_GWL_INTERIOR) error stop 1
  if(abs(r%level_cm+20.0_real64)>1.0e-12_real64 .or. r%crossing_lower_node/=2) error stop 2

  h=[1.0_real64,10.0_real64,20.0_real64,30.0_real64]
  call evaluate_b111_profile_groundwater_projection(z,d,h,0.0_real64,r)
  if(r%status/=B111_PROFILE_GWL_FULLY_SATURATED .or. abs(r%level_cm+4.0_real64)>1.0e-12_real64) error stop 3
  call evaluate_b111_profile_groundwater_projection(z,d,h,2.0_real64,r)
  if(r%status/=B111_PROFILE_GWL_FULLY_SATURATED .or. abs(r%level_cm-2.0_real64)>1.0e-12_real64) error stop 4

  h=[-20.0_real64,-20.0_real64,-10.0_real64,-1.0_real64]
  call evaluate_b111_profile_groundwater_projection(z,d,h,0.0_real64,r)
  if(.not.r%valid .or. r%level_present .or. r%status/=B111_PROFILE_GWL_BELOW_PROFILE) error stop 5

  h=[-20.0_real64,-10.0_real64,-5.0_real64,0.0_real64]
  call evaluate_b111_profile_groundwater_projection(z,d,h,0.0_real64,r)
  if(.not.r%valid .or. .not.r%level_present .or. abs(r%level_cm+35.0_real64)>1.0e-12_real64) error stop 6

  h=0.0_real64
  call evaluate_b111_profile_groundwater_projection(z,d,h,0.0_real64,r)
  if(.not.r%valid .or. .not.r%level_present .or. abs(r%level_cm)>1.0e-12_real64) error stop 7

  print '(a)', 'SW431-GW-PROJECTION-COMPONENT=PASS'
end program
