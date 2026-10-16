program test_crop_tav_detailed_period_candidate
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_crop_tav_detailed_period_candidate
 implicit none
 real(real64)::v,nan,x(24),period,expect,old,actual
 integer::st,i,j,n
 nan=ieee_value(0.0_real64,ieee_quiet_nan)
 do n=1,96
   block
     real(real64)::t(n)
     period=1.0_real64/real(n,real64)
     do j=1,n
       t(j)=sin(real(j,real64))*100.0_real64
     end do
     expect=0.0_real64
     do j=1,n
       expect=expect+t(j)
     end do
     expect=expect*period
     call crop_tav_from_detailed_period_candidate(t,period,v,st)
     if(st/=CROP_TAV_PERIOD_OK) error stop 1
     if(transfer(v,0_int64)/=transfer(expect,0_int64)) error stop 2
   end block
 end do
 x=0.0_real64
 x(1)=nan
 call crop_tav_from_detailed_period_candidate(x,1.0_real64/24.0_real64,v,st)
 if(st/=CROP_TAV_PERIOD_INVALID) error stop 3
 x=1.0_real64
 call crop_tav_from_detailed_period_candidate(x,1.0_real64/23.0_real64,v,st)
 if(st/=CROP_TAV_PERIOD_INVALID) error stop 4
 call crop_tav_from_detailed_period_candidate(x,-1.0_real64,v,st)
 if(st/=CROP_TAV_PERIOD_INVALID) error stop 5
 call crop_tav_from_detailed_period_candidate(x,nan,v,st)
 if(st/=CROP_TAV_PERIOD_INVALID) error stop 6
 call crop_tav_from_detailed_period_candidate(x,tiny(1.0_real64),v,st)
 if(st/=CROP_TAV_PERIOD_INVALID) error stop 9
 call crop_tav_from_detailed_period_candidate([real(real64)::],1.0_real64,v,st)
 if(st/=CROP_TAV_PERIOD_INVALID) error stop 7
 x=0.0_real64
 x(1)=1.0_real64
 x(2)=100.0_real64
 call crop_tav_from_detailed_period_candidate(x,1.0_real64/24.0_real64,v,st)
 if(st/=CROP_TAV_PERIOD_OK) error stop 8
 print '(a)','CROP_TAV_DETAILED_PERIOD_CANDIDATE=PASS'
end program
