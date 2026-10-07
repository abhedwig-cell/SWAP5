program test_b111_explicit_cauchy_profile_flux
 use iso_fortran_env,only:real64
 use mod_b111_explicit_cauchy_profile_flux
 implicit none
 real(real64)::zt(4),zb(4),dz(4),k(4),q,g,c
 integer::s
 zt=[0._real64,-10._real64,-20._real64,-30._real64]
 zb=[-10._real64,-20._real64,-30._real64,-40._real64];dz=10._real64;k=[2._real64,4._real64,5._real64,10._real64]
 call evaluate_b111_explicit_cauchy_profile_flux(-15._real64,-20._real64,0.5_real64,-5._real64,3._real64,zt,zb,dz,k,0.2_real64,q,g,c,s)
 if(s/=B111_EXPLICIT_CAUCHY_OK)error stop 1
 ! gwlmean=-17.5; node2: sat=2.5; c=2.5/4+10/5+10/10=3.625
 if(abs(g+17.5_real64)>1e-12_real64.or.abs(c-3.625_real64)>1e-12_real64)error stop 2
 if(abs(q-((-5._real64+17.5_real64)/(6.625_real64)+0.2_real64))>1e-12_real64)error stop 3
 call evaluate_b111_explicit_cauchy_profile_flux(-15._real64,-20._real64,1._real64,-5._real64,2._real64,zt,zb,dz,k,-0.1_real64,q,g,c,s)
 if(s/=B111_EXPLICIT_CAUCHY_OK.or.abs(c-4.25_real64)>1e-12_real64)error stop 4
 call evaluate_b111_explicit_cauchy_profile_flux(-20._real64,-20._real64,1._real64,-20._real64,2._real64,zt,zb,dz,k,0._real64,q,g,c,s)
 ! Exact equality with ztop(3) remains in node 3 because B1.11 uses strict >.
 if(s/=B111_EXPLICIT_CAUCHY_OK.or.abs(c-3.0_real64)>1e-12_real64)error stop 5
 call evaluate_b111_explicit_cauchy_profile_flux(5._real64,-20._real64,1._real64,-5._real64,2._real64,zt,zb,dz,k,0._real64,q,g,c,s)
 if(s/=B111_EXPLICIT_CAUCHY_GWL_OUTSIDE_PROFILE)error stop 6
 print '(a)','SW431-LOW3-EXPLICIT-COMPONENT=PASS'
end program
