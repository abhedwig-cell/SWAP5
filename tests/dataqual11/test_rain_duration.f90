program test_rain_duration
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_daily_rain_duration
 implicit none
 real(real64)::duration,rate,nan
 integer::status
 call resolve_daily_rain_duration(10d0,.25d0,duration,rate,status)
 if(status/=0.or.duration/=.25d0.or.rate/=4d0)error stop 'source wet event'
 call resolve_daily_rain_duration(0d0,0d0,duration,rate,status)
 if(status/=0.or.duration/=0d0.or.rate/=0d0)error stop 'source dry event'
 call resolve_daily_rain_duration(1d-8,1d-4,duration,rate,status)
 if(status/=0.or.duration/=0d0.or.rate/=0d0)error stop 'original event threshold'
 call rejected(1d0,0d0);call rejected(0d0,.1d0)
 call rejected(1001d0,.1d0);call rejected(-1d0,.1d0);call rejected(1d0,1.1d0)
 nan=ieee_value(0d0,ieee_quiet_nan)
 call rejected(nan,0d0);call rejected(1d0,nan)
 print '(a)','DAILY_RAIN_DURATION_CONTRACT_PASS'
contains
 subroutine rejected(r,w)
  real(real64),intent(in)::r,w
  call resolve_daily_rain_duration(r,w,duration,rate,status)
  if(status==0.or.duration/=0d0.or.rate/=0d0)error stop 'invalid input admitted or nonzero output'
 end subroutine
end program
