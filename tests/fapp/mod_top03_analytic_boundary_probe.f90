! FALSIFIED research hypothesis: smooth MvG derivative omits actual cutoff branches.
! Its oracle intentionally rejects the route; do not reuse as a qualified derivative.
module mod_top03_analytic_boundary_probe
 use,intrinsic::iso_fortran_env,only:real64
 use mod_b110_default_mvg_provider,only:b110_default_mvg_parameters_t,evaluate_b110_default_mvg_conductivity
 implicit none
 contains
 function top03_dkdh(p,node,h)result(derivative)
 type(b110_default_mvg_parameters_t),intent(in)::p
 integer,intent(in)::node
 real(real64),intent(in)::h
 real(real64)::derivative,alpha,n,m,l,ks,v,u,s,b,ds,db
 if(p%ksatexm_extension_enabled.or.p%elastic_storage_active)error stop 'analytic probe unsupported extension'
 if(p%cofgen(9,node)/=0.0_real64.or.p%cofgen(28,node)/=1.0_real64)error stop 'analytic probe requires hentry zero'
 derivative=0.0_real64
 if(h>=0.0_real64)return
 alpha=p%cofgen(4,node);n=p%cofgen(6,node);m=p%cofgen(7,node);l=p%cofgen(5,node);ks=p%cofgen(3,node)
 v=alpha*abs(h);u=v**n;s=(1.0_real64+u)**(-m)
 b=1.0_real64-(u/(1.0_real64+u))**m
 ds=m*n*alpha*v**(n-1.0_real64)/(1.0_real64+u)**(m+1.0_real64)
 db=m*n*alpha*v**(n*m-1.0_real64)/(1.0_real64+u)**(m+1.0_real64)
 derivative=ks*(l*s**(l-1.0_real64)*ds*b*b+2.0_real64*s**l*b*db)
 end function
 subroutine top03_check_derivative(p)
 type(b110_default_mvg_parameters_t),intent(in)::p
 real(real64),parameter::heads(11)=[-123.0_real64,-10.0_real64,-1.0_real64,-0.0281421266_real64, &
 -0.001_real64,-0.0001_real64,-1e-5_real64,-1e-6_real64,-1e-7_real64,-1e-8_real64,0.02_real64]
 real(real64)::h,step,kp,km,exact,fd,err,best
 integer::i,j
 logical::okp,okm
 do i=1,size(heads)
 h=heads(i);exact=top03_dkdh(p,1,h);best=huge(1.0_real64)
 do j=2,5
 step=max(abs(h),1e-8_real64)*10.0_real64**(-j)
 call evaluate_b110_default_mvg_conductivity(p,1,h+step,kp,okp)
 call evaluate_b110_default_mvg_conductivity(p,1,h-step,km,okm)
 if(.not.okp.or..not.okm)error stop 'derivative oracle conductivity unavailable'
 fd=(kp-km)/(2.0_real64*step);err=abs(fd-exact)/max(1e-30_real64,abs(exact))
 best=min(best,err)
 write(*,'(a,5(a,es24.16))')'DK_ORACLE',',',h,',',step,',',exact,',',fd,',',err
 end do
 ! Do not claim derivative qualification at the floating-point saturation limit.
 if(h<=-0.001_real64.and.best>1e-5_real64)error stop 'moderate-head derivative mismatch'
 if(h>0.0_real64.and.best/=0.0_real64)error stop 'saturated derivative mismatch'
 end do
 end subroutine
end module
