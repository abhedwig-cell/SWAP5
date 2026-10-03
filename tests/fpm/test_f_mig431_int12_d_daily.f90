program test_int12d_daily
 use,intrinsic::iso_fortran_env,only:real64
 use mod_gash_daily_application
 implicit none
 type(gash_daily_application_input_t)::x
 type(gash_daily_application_result_t)::r
 integer::s
 x%gross_rain_cm=0.8d0;x%surface_irrigation_cm=0.2d0;x%interception_cm=0.1d0;x%surface_irrigation_is_intercepted=.true.
 x%wet_transpiration_capacity_mm_per_day=2d0;x%dry_transpiration_cm_per_day=0.4d0;x%wet_transpiration_cm_per_day=0.1d0
 call apply_gash_daily(x,r,s);call req(s==GASH_APP_OK,'wet')
 call req(abs(r%net_rain_cm-0.72d0)<1d-14.and.abs(r%net_irrigation_cm-0.18d0)<1d-14,'split')
 call req(abs((r%net_rain_cm+r%net_irrigation_cm+x%interception_cm)-1d0)<1d-14,'mass')
 call req(abs(r%wet_fraction-0.5d0)<1d-14.and.abs(r%potential_transpiration_cm_per_day-0.25d0)<1d-14,'wet blend')
 x%snow_present=.true.;call apply_gash_daily(x,r,s);call req(s==GASH_APP_OK,'snow');call req(abs(r%net_rain_cm-0.8d0)<1d-14.and.abs(r%net_irrigation_cm-0.2d0)<1d-14.and.abs(r%wet_fraction)<tiny(1.0_real64),'snow disables')
 x%snow_present=.false.;x%interception_cm=0.0009d0;call apply_gash_daily(x,r,s);call req(abs(r%net_rain_cm-0.8d0)<1d-14.and.abs(r%net_irrigation_cm-0.2d0)<1d-14,'legacy 0.001 DivIntercep threshold')
 print *,'F-MIG431-INT12-D DAILY APPLICATION PASS'
contains
 subroutine req(q,m);logical,intent(in)::q;character(*),intent(in)::m;if(.not.q)then;print *,m;error stop 1;end if;end subroutine
end program
