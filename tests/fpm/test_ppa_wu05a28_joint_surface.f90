program test_joint_surface
 use,intrinsic::iso_fortran_env,only:real64
 use,intrinsic::ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_soil_water_solver_contract
 use mod_rfm_unponded_activation
 use mod_rfm_unponded_surface_composition
 use mod_fpe_a28_joint_surface_receipt
 implicit none
 type(soil_water_top_boundary_result_t)::p
 type(rfm_unponded_activation_result_t)::a
 type(rfm_unponded_surface_composition_result_t)::r
 real(real64)::i,o,e
 logical::ok
 p%status=SW_TOP_BOUNDARY_AVAILABLE;p%carries_surface_mass_terms=.true.;p%runoff_resolved=.true.
 p%regime=SW_TOP_BOUNDARY_REGIME_HEAD;p%candidate_ponding_depth=.13_real64;p%net_potential_surface_flux=10.
 a%status=RFM_ACTIVATION_AVAILABLE;a%matrix_rate_cm_per_day=8.;a%preferential_rate_cm_per_day=2.;a%preferential_fraction=.2
 call compose_external_supply_partition(p,a,1e-12_real64,r)
 if(r%status/=RFM_SURFACE_COMPOSITION_AVAILABLE)error stop 'joint partition'
 call compose_rfm_unponded_surface_receipt(p,a,1e-12_real64,r)
 if(r%status/=RFM_SURFACE_COMPOSITION_REFERENCE_REQUIRED)error stop 'A15 changed'
 call materialize_joint_surface_receipt(10._real64,2._real64,.01_real64,.1_real64,.13_real64,-5._real64,0._real64, &
     1e-12_real64,i,o,e,ok)
 if(.not.ok.or.i/=.1_real64.or.o/=0.)error stop 'joint pond ledger'
 ! Runoff removes .02 from candidate ponding, not preferential input.
 call materialize_joint_surface_receipt(10._real64,2._real64,.01_real64,.1_real64,.11_real64,-5._real64,.02_real64, &
     1e-12_real64,i,o,e,ok)
 if(.not.ok.or.o/=.02_real64)error stop 'joint runoff ledger'
 ! Upward matrix flow is internal supply to surface, not external output.
 call materialize_joint_surface_receipt(0._real64,0._real64,.01_real64,.1_real64,.12_real64,2._real64,0._real64, &
     1e-12_real64,i,o,e,ok)
 if(.not.ok.or.i/=0..or.o/=0.)error stop 'joint exfiltration ledger'
 call materialize_joint_surface_receipt(10._real64,2._real64,.01_real64,.1_real64,.14_real64,-5._real64,0._real64, &
     1e-12_real64,i,o,e,ok)
 if(ok)error stop 'joint bad closure accepted'
 call materialize_joint_surface_receipt(ieee_value(0._real64,ieee_quiet_nan),2._real64,.01_real64, &
     .1_real64,.13_real64,-5._real64,0._real64,1e-12_real64,i,o,e,ok)
 if(ok)error stop 'joint nonfinite accepted'
 call materialize_joint_surface_receipt(1._real64,2._real64,.01_real64,.1_real64,.13_real64,-5._real64,0._real64, &
     1e-12_real64,i,o,e,ok)
 if(ok)error stop 'joint overdraw accepted'
 if(p%candidate_ponding_depth/=.13_real64.or.a%preferential_rate_cm_per_day/=2.)error stop 'mutated origin'
 print '(a)','A28_JOINT_SURFACE_RECEIPT=PASS'
end program
