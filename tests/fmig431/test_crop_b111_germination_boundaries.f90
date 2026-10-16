program test_crop_b111_germination_boundaries
 use iso_fortran_env, only: real64
 use ieee_arithmetic, only: ieee_value, ieee_quiet_nan, ieee_positive_inf
 use mod_crop_b111_germination_sum_candidate
 implicit none
 real(real64):: x(6),res,dvs,nan,inf,old
 integer::i,st
 logical::done
 nan=ieee_value(0.0_real64,ieee_quiet_nan)
 inf=ieee_value(0.0_real64,ieee_positive_inf)
 x=[10.0_real64,2.0_real64,20.0_real64,30.0_real64,10.0_real64,7.0_real64]
 do i=1,6
    x(i)=nan
    call b111_germination_sum_candidate(x(1),x(2),x(3),x(4),x(5),x(6),res,done,dvs,st)
    if (st/=B111_SUM_INVALID.or.done.or.dvs/=0.0_real64) error stop 1
    if(i/=6) then
      if(res/=7.0_real64) error stop 2
    end if
    x=[10.0_real64,2.0_real64,20.0_real64,30.0_real64,10.0_real64,7.0_real64]
    x(i)=inf
    call b111_germination_sum_candidate(x(1),x(2),x(3),x(4),x(5),x(6),res,done,dvs,st)
    if (st/=B111_SUM_INVALID.or.done.or.dvs/=0.0_real64) error stop 3
    x=[10.0_real64,2.0_real64,20.0_real64,30.0_real64,10.0_real64,7.0_real64]
 end do
 call b111_germination_sum_candidate(2.0_real64,2.0_real64,20.0_real64,30.0_real64,10.0_real64,7.0_real64,res,done,dvs,st)
 if(st/=B111_SUM_OK.or.res/=7.0_real64.or.done) error stop 4
 call b111_germination_sum_candidate(20.0_real64,2.0_real64,20.0_real64,30.0_real64,10.0_real64,7.0_real64,res,done,dvs,st)
 if(st/=B111_SUM_OK.or.res/=61.0_real64.or..not.done) error stop 5
 call b111_germination_sum_candidate(4.0_real64,2.0_real64,20.0_real64,30.0_real64,0.1_real64,7.0_real64,res,done,dvs,st)
 if(st/=B111_SUM_OK.or.res/=607.0_real64.or..not.done) error stop 6
 call b111_germination_sum_candidate(4.0_real64,2.0_real64,20.0_real64,30.0_real64,0.0_real64,7.0_real64,res,done,dvs,st)
 if(st/=B111_SUM_OK.or.res/=9.0_real64.or.done) error stop 7
 call b111_germination_sum_candidate(4.0_real64,2.0_real64,20.0_real64,30.0_real64,10.0_real64,-1.0_real64,res,done,dvs,st)
 if(st/=B111_SUM_INVALID.or.res/=-1.0_real64) error stop 8
 old=0.0_real64
 do i=1,5
   call b111_germination_sum_candidate(12.0_real64,2.0_real64,20.0_real64,30.0_real64,30.0_real64,old,res,done,dvs,st)
   if(st/=B111_SUM_OK.or.abs(res-10.0_real64*real(i,real64))>1.e-12_real64) error stop 9
   if((i>=3).neqv.done) error stop 10
   old=res
 end do
 print '(a)','CROP_B111_GERMINATION_BOUNDARIES=PASS'
end program
