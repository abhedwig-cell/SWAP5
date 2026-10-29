! Original SWRAIN=2 daily depth/duration law, separated from file and state owners.
module mod_daily_rain_duration
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 implicit none
 private
 public::resolve_daily_rain_duration
contains
 pure subroutine resolve_daily_rain_duration(rain_mm,wet_fraction,duration_day,rate_cm_day,status)
  real(real64),intent(in)::rain_mm,wet_fraction
  real(real64),intent(out)::duration_day,rate_cm_day
  integer,intent(out)::status
  duration_day=0d0;rate_cm_day=0d0;status=1
  ! Separate finite checks: Fortran does not guarantee short circuit evaluation.
  if(.not.ieee_is_finite(rain_mm).or..not.ieee_is_finite(wet_fraction))return
  if(rain_mm<0d0.or.rain_mm>1000d0.or.wet_fraction<0d0.or.wet_fraction>1d0)return
  ! MOD_meteo LoadMeteoData source validation and event threshold are distinct.
  if((rain_mm>1d-10.and.wet_fraction<1d-10).or. &
     (rain_mm<1d-10.and.wet_fraction>1d-10))return
  if(rain_mm>1d-8)then
   if(wet_fraction<=0d0)return
   duration_day=wet_fraction
   rate_cm_day=rain_mm*0.1d0/duration_day
  end if
  status=0
 end subroutine resolve_daily_rain_duration
end module mod_daily_rain_duration
