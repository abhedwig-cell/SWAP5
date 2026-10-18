program test_conductivity_curve
use, intrinsic :: iso_fortran_env,only:real64
use mod_b110_default_mvg_provider
implicit none
type(b110_default_mvg_parameters_t),target::p
type(b110_default_mvg_provider_t)::provider
real(real64)::c(24,1),h(1),w(1),k(1),cap(1),dk(1),point
real(real64)::heads(16)=[-100.d0,-10.d0,-1.d0,-.1d0,-.02d0,-.01238605d0,-.01238604d0,-.011d0,-.01001d0,-.01d0,-.00999d0,-.005d0,-.001d0,-.000001d0,0.d0,1.d0]
integer::i
logical::ok
c=0; c(1,1)=.032d0;c(2,1)=.423d0;c(3,1)=4.75d0;c(4,1)=.0135d0;c(5,1)=.365d0
c(6,1)=1.455d0;c(7,1)=1-1/c(6,1);c(8,1)=c(4,1);c(10,1)=c(3,1)
c(11,1)=.999d0;c(12,1)=.99d0*c(3,1);c(22,1)=-1.d6;c(23,1)=1.d-12
call initialize_b110_default_mvg_parameters(p,c)
call bind_b110_default_mvg_provider(provider,p,1.d0)
do i=1,size(heads)
 h(1)=heads(i);call provider%evaluate(h,w,k,cap,dk)
 call provider%evaluate_point_conductivity(1,h(1),w(1),point,ok)
 if(.not.ok.or.point/=k(1))error stop 'point/vector K mismatch'
 if(k(1)<0.d0.or.k(1)>c(3,1))error stop 'conductivity bounds'
 write(*,'(4(ES24.16,1X))') h(1),w(1),k(1),point
end do
end program
