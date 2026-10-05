program test_fmr_base_salt_temporal_policy
  use iso_fortran_env,only:real64
  use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
  use mod_fmr_base_salt_temporal_policy
  implicit none
  type(fmr_base_salt_temporal_policy_t)::p,bad
  real(real64)::h(2),w(2),m(2),t(2),hh(2),ww(2),mm(2),tt(2),err,nan
  h=-10;w=.25_real64;m=1;t=20
  nan=ieee_value(0._real64,ieee_quiet_nan)
  call require(.not.p%valid(),'disabled policy')
  p%enabled=.true.;p%head_tolerance_cm=2;p%water_tolerance_cm=.5_real64
  p%salt_tolerance_mg_cm2=.25_real64;p%temperature_tolerance_c=4
  call require(p%valid(),'explicit finite positive units')
  hh=h;ww=w;mm=m;tt=t
  call require(metric()==0._real64,'identical states')
  hh(1)=h(1)+1;call require(metric()==.5_real64,'head component')
  hh=h;ww(2)=w(2)+.0625_real64
  call require(metric()==1._real64,'node water storage uses dz')
  ww=w;mm(1)=m(1)+.5_real64
  call require(metric()==2._real64,'salt component rejects')
  mm=m;tt(1)=t(1)+3
  call require(metric()==.75_real64,'temperature component')
  tt=t;mm(1)=-1;call require(metric()==huge(0._real64),'negative inventory invalid')
  mm=m;hh(1)=nan;call require(metric()==huge(0._real64),'nonfinite state invalid')
  hh=h;bad=p;bad%salt_tolerance_mg_cm2=0
  err=fmr_base_salt_normalized_error(bad,[4._real64,8._real64],h,hh,w,ww,m,mm,0._real64,0._real64, &
       -2._real64,-2._real64)
  call require(err==huge(0._real64),'zero budget invalid')
  err=fmr_base_salt_normalized_error(p,[4._real64,8._real64],h,hh,w,ww,m,mm,0._real64,0._real64, &
       -2._real64,-2._real64,full_temperature=t)
  call require(err==huge(0._real64),'unpaired thermal state invalid')
  err=fmr_base_salt_normalized_error(p,[4._real64,8._real64],h,hh,w,ww,m,mm,0._real64,0._real64, &
       -2._real64,1._real64)
  call require(err==1.5_real64,'groundwater component')
  bad=p;bad%salt_tolerance_mg_cm2=tiny(0._real64)
  mm=huge(0._real64)
  err=fmr_base_salt_normalized_error(bad,[4._real64,8._real64],h,hh,w,ww,m,mm,0._real64,0._real64, &
       -2._real64,-2._real64)
  call require(err==huge(0._real64),'extreme finite salt error saturates without overflow')
  print '(a)','PPA_WU05E_BASE_SALT_METRIC=PASS_TEST_ONLY'
contains
  real(real64) function metric()
    metric=fmr_base_salt_normalized_error(p,[4._real64,8._real64],h,hh,w,ww,m,mm,0._real64,0._real64, &
         -2._real64,-2._real64,t,tt)
  end function
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(*),intent(in)::label
    if(.not.ok)then
      print *,label
      error stop 1
    end if
  end subroutine
end program
