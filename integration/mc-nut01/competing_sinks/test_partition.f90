program partition_contract
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_n_constant_sink_partition
 implicit none
 real(real64)::r(3),a(3),u(3),dt,tau,total,scale,nan,tol
 integer::i,j,k,m,status,n
 n=0
 do i=-10,10,10
  scale=10d0**i;r=[scale,2d0*scale,0d0]
  do j=1,2
   dt=.5d0*j*j
   do k=0,2
    tau=.5d0*k*dt
    do m=0,2
     total=sum(r)*(tau+.5d0*m*(dt-tau))
     call partition_n_constant_sinks(r,dt,tau,total,a,u,status)
     tol=128d0*epsilon(1d0)*max(total,sum(r)*dt)
     if(status/=0.or.abs(sum(a)-total)>tol.or.any(a<0d0).or.any(u<0d0))error stop 1
     if(maxval(abs(a+u-r*dt))>tol.or.a(3)/=0d0)error stop 2
     if(abs(a(2)-2*a(1))>tol)error stop 3
     n=n+1
    end do
   end do
  end do
 end do
 call partition_n_constant_sinks([0d0,1d0,0d0],1d0,0d0,.123d0,a,u,status)
 if(status/=0.or.a(2)/=.123d0.or.sum(a)/=.123d0)error stop 4
 call partition_n_constant_sinks([0d0,0d0,0d0],1d0,1d0,0d0,a,u,status)
 if(status/=0.or.any(a/=0d0).or.any(u/=0d0))error stop 5
 nan=ieee_value(0d0,ieee_quiet_nan)
 do i=1,9
  r=[1d0,2d0,0d0];dt=1d0;tau=.5d0;total=2d0
  select case(i)
  case(1);r(1)=-1d0
  case(2);dt=0d0
  case(3);tau=-1d0
  case(4);tau=2d0
  case(5);total=4d0
  case(6);total=1d0
  case(7);r(1)=nan
  case(8);r=[huge(1d0),huge(1d0),0d0]
  case(9);dt=huge(1d0)
  end select
  call partition_n_constant_sinks(r,dt,tau,total,a,u,status)
  if(status==0.or.any(a/=0d0).or.any(u/=0d0))error stop 6
 end do
 print *, 'PARTITION_CONTRACT_PASS',n+2,9
end program
