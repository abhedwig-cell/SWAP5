! Explicit daily prescribed soil temperature; accepted water owns moisture.
module mod_soil_n_day_environment
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 implicit none
 private
 type,public::soil_n_day_environment_t
  real(real64)::t0=0d0,t1=0d0,temperature_c=0d0
 end type
 public::soil_n_day_environment_valid
contains
 pure logical function soil_n_day_environment_valid(f,t0,t1)result(ok)
  type(soil_n_day_environment_t),intent(in)::f
  real(real64),intent(in)::t0,t1
  ok=.false.
  if(.not.all(ieee_is_finite([f%t0,f%t1,f%temperature_c,t0,t1])))return
  ! Bound subtraction before arithmetic; this is a one-day physical profile.
  if(max(abs(f%t0),abs(f%t1),abs(t0),abs(t1))>1d9)return
  if(f%t0/=t0.or.f%t1/=t1.or.t1-t0/=1d0)return
  if(f%temperature_c< -20d0.or.f%temperature_c>60d0)return
  ok=.true.
 end function
end module
