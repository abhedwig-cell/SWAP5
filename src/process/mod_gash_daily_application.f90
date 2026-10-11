module mod_gash_daily_application
 use, intrinsic::iso_fortran_env,only:real64
 use, intrinsic::ieee_arithmetic,only:ieee_is_finite
 implicit none; private
 integer,parameter,public::GASH_APP_OK=0,GASH_APP_INVALID=1
 type,public::gash_daily_application_input_t
  real(real64)::gross_rain_cm=0d0,surface_irrigation_cm=0d0,interception_cm=0d0
  logical::surface_irrigation_is_intercepted=.true.,snow_present=.false.
  real(real64)::wet_transpiration_capacity_mm_per_day=0d0,dry_transpiration_cm_per_day=0d0,wet_transpiration_cm_per_day=0d0
 end type
 type,public::gash_daily_application_result_t
  real(real64)::net_rain_cm=0d0,net_irrigation_cm=0d0,rain_interception_cm=0d0,wet_fraction=0d0,potential_transpiration_cm_per_day=0d0
 end type
 public::apply_gash_daily
contains
 pure subroutine apply_gash_daily(x,r,status)
  type(gash_daily_application_input_t),intent(in)::x;type(gash_daily_application_result_t),intent(out)::r;integer,intent(out)::status
  real(real64)::a,den
  r=gash_daily_application_result_t();status=GASH_APP_INVALID
  if(.not.all(ieee_is_finite([x%gross_rain_cm,x%surface_irrigation_cm,x%interception_cm,x%wet_transpiration_capacity_mm_per_day,x%dry_transpiration_cm_per_day,x%wet_transpiration_cm_per_day])))return
  if(any([x%gross_rain_cm,x%surface_irrigation_cm,x%interception_cm,x%wet_transpiration_capacity_mm_per_day,x%dry_transpiration_cm_per_day,x%wet_transpiration_cm_per_day]<0d0))return
  a=x%interception_cm;if(x%snow_present)a=0d0
  r%net_rain_cm=x%gross_rain_cm;r%net_irrigation_cm=x%surface_irrigation_cm
  if(a>=0.001d0)then
   if(x%surface_irrigation_is_intercepted)then
    den=x%gross_rain_cm+x%surface_irrigation_cm;if(den<=0d0)return
    r%net_rain_cm=x%gross_rain_cm-a*x%gross_rain_cm/den
    r%net_irrigation_cm=x%surface_irrigation_cm-a*x%surface_irrigation_cm/den
   else
    r%net_rain_cm=x%gross_rain_cm-a
   end if
  end if
  r%rain_interception_cm=x%gross_rain_cm-r%net_rain_cm
  if(x%wet_transpiration_capacity_mm_per_day>=0.0001d0)r%wet_fraction=max(min(a*10d0/x%wet_transpiration_capacity_mm_per_day,1d0),0d0)
  r%potential_transpiration_cm_per_day=r%wet_fraction*x%wet_transpiration_cm_per_day+(1d0-r%wet_fraction)*x%dry_transpiration_cm_per_day
  if(r%net_rain_cm<0d0.or.r%net_irrigation_cm<0d0)return
  status=GASH_APP_OK
 end subroutine
end module
