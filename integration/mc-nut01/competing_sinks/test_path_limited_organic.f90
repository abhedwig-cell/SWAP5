program test_path_limited
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_path_limited_organic
 implicit none
 type(path_limited_result_t)::r,a,b
 real(real64)::kf(2),kb(3),stock(4),bio(2),span(2),f0,b0,m0,k1,k2,dt,err
 integer::i,j,k,l,n,id,half
 kf=[.1d0,10d0];kb=[0d0,5d0,10d0];stock=[0d0,1d-5,.005d0,.05d0]
 bio=[0d0,.03d0];span=[1d0,10d0];id=0
 do i=1,2
 do j=1,3
 do k=1,4
 do l=1,2
 do n=1,2
  id=id+1;f0=1d0;b0=bio(l);m0=stock(k);k1=kf(i);k2=kb(j);dt=span(n)
  call advance_path_limited_organic(f0,b0,m0,k1,k2,dt,r)
  call require(r%status==0,'whole interval')
  ! Opaque-state-free continuation tests the physical semigroup; it is not
  ! a runtime checkpoint or disk-restart test.
  call advance_path_limited_organic(f0,b0,m0,k1,k2,dt*.37d0,a)
  call require(a%status==0,'first interval')
  call advance_path_limited_organic(a%fom,a%bio,a%nh4,k1,k2,dt*.63d0,b)
  call require(b%status==0,'second interval')
  err=maxval(abs([r%fom-b%fom,r%bio-b%bio,r%nh4-b%nh4,r%carbon-a%carbon-b%carbon]))
  call require(err<2d-11,'continuation semigroup')
  call require(min(r%fom,r%bio,r%nh4,r%carbon)>=0d0,'nonnegative endpoints')
  call require(max(abs(r%n_residual),abs(r%c_residual))<1d-12,'whole C/N')
  print '(I0,17(1X,ES25.17E3))',id,f0,b0,m0,k1,k2,dt,r%fom,r%bio,r%nh4, &
   r%carbon,r%depletion,r%release,r%boundary_duration,r%n_residual,r%c_residual,err,a%nh4
 end do
 end do
 end do
 end do
 end do
 call advance_path_limited_organic(1d0,.03d0,.005d0,-1d0,5d0,1d0,r)
 call require(r%status/=0.and.r%fom==1d0.and.r%bio==.03d0.and.r%nh4==.005d0.and.r%carbon==0d0,'negative input rollback')
 call advance_path_limited_organic(1d0,.03d0,.005d0,10d0,5d0,ieee_value(0d0,ieee_quiet_nan),r)
 call require(r%status/=0.and.r%fom==1d0.and.r%bio==.03d0.and.r%nh4==.005d0.and.r%carbon==0d0,'NaN interval rollback')
 print '(A)','PATH_LIMITED_INVALID_ROLLBACK_PASS'
contains
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then;print *,id,label;error stop 1;end if
 end subroutine
end program
