program test_ppa_wu05a26_production_composer
 use,intrinsic::iso_fortran_env,only:real64
 use mod_rfm_physical_state
 use mod_rfm_preferential_router
 use mod_rfm_production_candidate_composer
 implicit none
 type(rfm_physical_state_t)::a,snap
 type(rfm_preferential_routing_result_t)::routing
 type(rfm_production_candidate_request_t)::q
 type(rfm_production_candidate_result_t)::r,r2
 logical::ok
 real(real64),parameter::tol=1e-12_real64,dt=0.1_real64
 call a%initialize(1,ok);if(.not.ok)error stop 'init'
 a%endpoint_water_cm=0.1_real64;a%wall_age_day=0.2_real64;a%wall_sorptivity_cm_sqrt_day=0.2_real64
 call copy_rfm_physical_state(a,snap,ok)
 routing%status=RFM_PREF_ROUTER_AVAILABLE;routing%mb_amount=0.4_real64
 allocate(routing%endpoint_amount(1));routing%endpoint_amount=1.6_real64
 q%step_duration_day=dt;q%effective_supply_rate_cm_per_day=8.0_real64;q%matrix_supply_rate_cm_per_day=6.0_real64
 q%candidate_tau_surface_day=0.3_real64;q%exchange_length_cm=20.0_real64;q%chi_wall=1.0_real64
 allocate(q%endpoint_area_fraction(1),q%endpoint_bottom_depth_cm(1),q%endpoint_contact_thickness_cm(1), &
  q%endpoint_node_index(1),q%endpoint_sorptivity_cm_sqrt_day(1),q%endpoint_conductivity_cm_per_day(1))
 q%endpoint_area_fraction=0.02_real64;q%endpoint_bottom_depth_cm=100.0_real64
 q%endpoint_contact_thickness_cm=20.0_real64;q%endpoint_node_index=1
 q%endpoint_sorptivity_cm_sqrt_day=0.2_real64;q%endpoint_conductivity_cm_per_day=0.01_real64
 allocate(q%node_depth_cm(1),q%node_thickness_cm(1),q%matrix_pressure_head_cm(1))
 q%node_depth_cm=95.0_real64;q%node_thickness_cm=10.0_real64;q%matrix_pressure_head_cm=-30.0_real64
 call compose_rfm_production_candidate(a,routing,q,tol,r)
 if(.not.r%valid)error stop 'compose'
 if(abs(r%deep_receipt_cm-0.04_real64)>tol)error stop 'mb deep'
 if(any(r%matrix_source_rate_per_day<0.0_real64))error stop 'source'
 if(.not.a%same_values(snap))error stop 'accepted mutation'
 call compose_rfm_production_candidate(a,routing,q,tol,r2)
 if(abs(r2%deep_receipt_cm-r%deep_receipt_cm)>tol)error stop 'replay deep'
 if(any(abs(r2%matrix_source_rate_per_day-r%matrix_source_rate_per_day)>tol))error stop 'replay source'
 print '(a)','PPA_WU05A26_PRODUCTION_COMPOSER=PASS'
end program
