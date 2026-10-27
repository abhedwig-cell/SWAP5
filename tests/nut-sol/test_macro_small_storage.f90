program test_macro_small_storage
 use iso_fortran_env, only: real64
 use mod_macropore_continuation_state
 use mod_macropore_standard_storage
 implicit none
 type(macropore_continuation_state_t)::state
 type(macropore_standard_storage_view_t)::view
 real(real64)::z(2),dz(2),tiny,capacity
 logical::ok
 call state%initialize(1,2,ok)
 if(.not.ok)error stop 'initialization'
 state%icp_bottom_domain=2
 state%volume_domain_cp(1,:)=[1.0e-3_real64,2.0e-3_real64]
 z=[-1.0_real64,-3.0_real64];dz=2.0_real64
 tiny=8.0e-13_real64
 state%water_domain_cp(1,2)=tiny
 call canonicalize_macropore_standard_storage(state,1,z,dz,view,ok)
 if(.not.ok.or.abs(sum(state%water_domain_cp)-tiny)>1.0e-25_real64)error stop 'small positive stock lost'
 capacity=state%volume_domain_cp(1,2)
 state%water_domain_cp=0.0_real64
 state%water_domain_cp(1,2)=capacity-tiny
 call canonicalize_macropore_standard_storage(state,1,z,dz,view,ok)
 if(.not.ok.or.abs(sum(state%water_domain_cp)-(capacity-tiny))>1.0e-18_real64)error stop 'near-capacity stock created'
 state%water_domain_cp=0.0_real64
 call canonicalize_macropore_standard_storage(state,1,z,dz,view,ok)
 if(.not.ok.or.any(state%water_domain_cp/=0.0_real64))error stop 'dry stock'
 print '(a)','MACRO_SMALL_STORAGE_PASS'
end program
