program test_low03_explicit_provider
 use, intrinsic :: iso_fortran_env, only: real64
 use mod_fmr_legacy_explicit_cauchy_bottom_boundary_provider
 implicit none
 type(fmr_explicit_cauchy3_result_t)::r
 type(fmr_explicit_cauchy3_control_t)::c
 integer::s
 real(real64)::zb(3),zt(3),dz(3),ks(3)
 dz=[10._real64,20._real64,30._real64]
 zt=[0._real64,-10._real64,-30._real64];zb=[-10._real64,-30._real64,-60._real64]
 ks=[5._real64,10._real64,20._real64]
 c%hdrain_cm=-20._real64;c%shape_3=0.5_real64
 call fmr_evaluate_legacy_explicit_cauchy_bottom_boundary_controlled(c,-40._real64,-50._real64, &
      2._real64,0.1_real64,zb,zt,dz,ks,r,s)
 if(s/=FMR_EXPLICIT_CAUCHY3_OK.or..not.r%available)error stop 1
 ! gwlmean=-30 exactly equals ztop(3): strict B1.11 > keeps node 3.
 if(r%groundwater_node/=3)error stop 2
 if(abs(r%profile_resistance_days-1.5_real64)>1e-14_real64)error stop 3
 if(abs(r%qbot_cm_per_day-((-20._real64)/3.5_real64+0.1_real64))>1e-13_real64)error stop 4
 call fmr_evaluate_legacy_explicit_cauchy_bottom_boundary(-20._real64,-20._real64,1._real64,-40._real64, &
      1._real64,0._real64,zb,zt,dz,ks,r,s)
 if(s/=FMR_EXPLICIT_CAUCHY3_OK.or.r%groundwater_node/=2)error stop 5
 print *,'LOW03_EXPLICIT_PROVIDER_PASS'
end program
