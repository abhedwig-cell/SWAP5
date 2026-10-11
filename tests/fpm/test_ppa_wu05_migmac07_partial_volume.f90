program test_partial_volume
 use, intrinsic::iso_fortran_env,only:real64,int64
 use, intrinsic::ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_ppa_wu05a6_rapid_drain_rate,only:derive_rapid_volume_under_drain,rapid_drain_request_t,rapid_drain_result_t,evaluate_rapid_drain
 implicit none
 type(rapid_drain_request_t)::request
 type(rapid_drain_result_t)::result
 real(real64)::z(3)=[-5.0_real64,-20.0_real64,-45.0_real64]
 real(real64)::dz(3)=[10.0_real64,20.0_real64,30.0_real64]
 real(real64)::vol(3)=[0.1_real64,0.4_real64,0.9_real64],v,a
 logical::ok
 call evaluate(-35.0_real64,1,3,0.75_real64)
 call evaluate(-30.0_real64,1,3,0.9_real64)
 call evaluate(-10.0_real64,1,3,1.3_real64)
 call evaluate(0.0_real64,1,3,1.4_real64)
 call evaluate(-60.0_real64,1,3,0.0_real64)
 call evaluate(-35.0_real64,1,2,0.0_real64)
 call evaluate(0.0_real64,2,3,1.3_real64)
 call derive_rapid_volume_under_drain(-10.0_real64,z,dz,vol,1,3,a,ok)
 call derive_rapid_volume_under_drain(-10.0_real64+5.0e-11_real64,z,dz,vol,1,3,v,ok)
 if(.not.ok.or.transfer(v,0_int64)/=transfer(a,0_int64))error stop 'aligned tolerance exact'
 call derive_rapid_volume_under_drain(-35.0_real64,z,dz,vol,1,3,a,ok)
 call evaluate(-20.0_real64,1,3,1.1_real64)
 call derive_rapid_volume_under_drain(-35.0_real64,z,dz,vol,1,3,v,ok)
 if(.not.ok.or.transfer(v,0_int64)/=transfer(a,0_int64))error stop 'A/B/A volume'
 call derive_rapid_volume_under_drain(1.0_real64,z,dz,vol,1,3,v,ok)
 if(ok.or.v/=0.0_real64)error stop 'out of column level'
 call derive_rapid_volume_under_drain(-35.0_real64,z,dz,vol(:2),1,3,v,ok)
 if(ok)error stop 'invalid shape'
 call derive_rapid_volume_under_drain(ieee_value(v,ieee_quiet_nan),z,dz,vol,1,3,v,ok)
 if(ok)error stop 'nonfinite drain'
 call derive_rapid_volume_under_drain(-35.0_real64,z,dz,vol,1,3,v,ok)
 request%num_nodes=3;request%top_water_node=1;request%bottom_domain_node=3
 request%enabled=.true.;request%drain_type=2;request%water_level_cm=0.0_real64
 request%domain_bottom_cm=-60.0_real64;request%drain_level_cm=-35.0_real64
 request%step_duration=100.0_real64;request%kd_reference=0.001_real64
 request%resistance_reference_day=20.0_real64;request%water_storage_cm=sum(vol)
 request%volume_under_drain_cm=v;request%dz=dz;request%diameter=[4.0_real64,4.0_real64,4.0_real64]
 request%volume_main_domain_cp=vol
 call evaluate_rapid_drain(request,result)
 if(.not.result%valid.or.abs(result%total_amount_cm-0.65_real64)>1.0e-14_real64) &
      error stop 'partial drainable water storage cap'
 if(abs(sum(result%amount_cp_cm)-result%total_amount_cm)>1.0e-14_real64)error stop 'partial external receipt closure'
 vol(2)=-1.0_real64
 call derive_rapid_volume_under_drain(-35.0_real64,z,dz,vol,1,3,v,ok)
 if(ok)error stop 'negative capacity'
 print '(a)','PPA_WU05_MIGMAC07_PARTIAL_VOLUME_INDEPENDENT=PASS'
contains
 subroutine evaluate(level,top,bottom,expected)
 real(real64),intent(in)::level,expected
 integer,intent(in)::top,bottom
 call derive_rapid_volume_under_drain(level,z,dz,vol,top,bottom,v,ok)
 if(.not.ok.or.abs(v-expected)>1.0e-14_real64)error stop 'independent partial volume'
 end subroutine
end program
