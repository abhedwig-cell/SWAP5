program salinity
use iso_fortran_env,only:real64,int64
use ieee_arithmetic
use mod_irrigation_process,only:apply_irrigation_salinity_excess
implicit none
real(real64)::threshold,percent,cml(1),cirrthres,perirrsurp,irr_depth,actual,before,nan
integer::swsolu,swcirrthres,nodsen,it,ip,edge,n,j,id
logical::applied,ok
n=0;nodsen=1
! Literal authenticated historical block is linked separately.
do swcirrthres=0,1
do swsolu=0,1
do it=0,1
do ip=0,4
do id=1,3
do edge=-1,1
 cirrthres=real(it*100,real64);perirrsurp=real(ip*25,real64)
 cml(1)=cirrthres
 if(edge<0)cml(1)=max(0._real64,cirrthres-1.e-8_real64)
 if(edge>0)cml(1)=cirrthres+1.e-8_real64
 select case(id)
 case(1);irr_depth=.4_real64
 case(2);irr_depth=1.2_real64
 case(3);irr_depth=39.9_real64
 end select
 actual=irr_depth
 call historical_salt(swsolu,swcirrthres,nodsen,cml,cirrthres,perirrsurp,irr_depth)
 call apply_irrigation_salinity_excess(swcirrthres==1,swsolu==1,cirrthres,perirrsurp,cml(1),actual,applied,ok)
 if(.not.ok.or.transfer(irr_depth,0_int64)/=transfer(actual,0_int64))error stop 1
 if(applied.neqv.(swcirrthres==1.and.swsolu==1.and.cml(1)>cirrthres))error stop 2
 n=n+1
enddo
enddo
enddo
enddo
enddo
enddo
nan=ieee_value(0._real64,ieee_quiet_nan)
do j=1,6
 threshold=1;percent=50;cml=2
 select case(j)
 case(1);threshold=nan
 case(2);threshold=-1
 case(3);percent=101
 case(4);percent=nan
 case(5);cml=nan
 case(6);cml=-1
 end select
 actual=.4_real64;before=actual
 call apply_irrigation_salinity_excess(.true.,.true.,threshold,percent,cml(1),actual,applied,ok)
 if(ok.or.applied.or.transfer(actual,0_int64)/=transfer(before,0_int64))error stop 3
enddo
if(n/=360)error stop 4
print '(a)','SALT_COMPLETION_LITERAL360_INVALID6=PASS'
end program
