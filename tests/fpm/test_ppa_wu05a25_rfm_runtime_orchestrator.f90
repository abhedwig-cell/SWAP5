program test_ppa_wu05a25_rfm_runtime_orchestrator
 use, intrinsic::iso_fortran_env,only:real64
 use mod_rfm_physical_state
 use mod_rfm_preferential_router
 use mod_rfm_runtime_orchestrator
 use mod_rfm_runtime_configuration,only:rfm_runtime_configuration_t
 implicit none
 real(real64),parameter::T=1e-12_real64
 type(rfm_physical_state_t)::accepted,snapshot
 type(rfm_preferential_routing_result_t)::routing
 type(rfm_runtime_orchestrator_request_t)::q
 type(rfm_runtime_orchestrator_result_t)::r,r2
 type(rfm_runtime_configuration_t)::cfg
 logical::ok
 cfg%enabled=.true.;cfg%sigma_b=.65_real64;cfg%f_mb=.2_real64;cfg%connectivity_p=.25_real64
 cfg%z_ah_cm=20.0_real64;cfg%z_ic_cm=100.0_real64;cfg%chi_wall=1.0_real64
 cfg%exchange_length_cm=20.0_real64;cfg%mb_contact_length_cm=80.0_real64;cfg%sorptivity_panels=32
 cfg%mb_wall_node_index=1;cfg%endpoint_depth_cm=[40.0_real64,100.0_real64]
 cfg%endpoint_contact_thickness_cm=[20.0_real64,60.0_real64];cfg%endpoint_node_index=[2,3]
 if(.not.cfg%valid())error stop 'runtime config'
 call accepted%initialize(2,ok);if(.not.ok)error stop 'init'
 accepted%endpoint_water_cm=[0.10_real64,0.05_real64];accepted%tau_surface_day=0.2_real64
 call copy_rfm_physical_state(accepted,snapshot,ok)
 routing%status=RFM_PREF_ROUTER_AVAILABLE;routing%mb_amount=1.5_real64
 allocate(routing%endpoint_amount(2),routing%endpoint_weight(2))
 routing%endpoint_amount=[2.0_real64,1.5_real64];routing%endpoint_weight=[2.0_real64/3.5_real64,1.5_real64/3.5_real64]
 q%step_duration_day=0.1_real64
 q%effective_supply_rate_cm_per_day=8.0_real64;q%matrix_supply_rate_cm_per_day=3.0_real64
 q%endpoint_node_index=[2,3];q%mb_wall_node_index=1;q%node_thickness_cm=[10.0_real64,10.0_real64,20.0_real64]
 q%endpoint_release%contact_thickness_cm=[20.0_real64,20.0_real64]
 q%endpoint_release%exchange_length_cm=[20.0_real64,20.0_real64]
 q%endpoint_release%chi_wall=[1.0_real64,1.0_real64]
 q%endpoint_release%wall_sorptivity_cm_sqrt_day=[0.01_real64,0.01_real64]
 q%endpoint_release%matrix_conductivity_cm_per_day=[0.001_real64,0.001_real64]
 q%endpoint_release%macro_to_matrix_head_difference_cm=[10.0_real64,10.0_real64]
 q%endpoint_release%accepted_wall_age_day=[0.1_real64,0.1_real64]
 q%mb_fate%contact_length_cm=80.0_real64;q%mb_fate%exchange_length_cm=20.0_real64
 q%mb_fate%chi_wall=1.0_real64;q%mb_fate%wall_sorptivity_cm_sqrt_day=0.01_real64
 q%mb_fate%matrix_conductivity_cm_per_day=0.001_real64;q%mb_fate%macro_to_matrix_head_difference_cm=10.0_real64
 q%mb_fate%wall_age_day=0.1_real64
 call compose_rfm_runtime_candidate(accepted,routing,q,T,r)
 if(.not.r%valid)error stop 'compose'
 if(.not.accepted%same_values(snapshot))error stop 'accepted mutated'
 if(abs(r%ledger%whole_column_residual_cm)>T)error stop 'ledger'
 if(abs(r%candidate_rfm%mb_water_cm)>T)error stop 'MB storage'
 if(abs(sum(r%matrix_source_rate_per_day*q%node_thickness_cm)*q%step_duration_day- &
   (r%endpoint_release%release_total_cm+r%mb_fate%wall_to_matrix_cm))>T)error stop 'source map'
 call compose_rfm_runtime_candidate(accepted,routing,q,T,r2)
 if(.not.r2%valid.or..not.r%candidate_rfm%same_values(r2%candidate_rfm))error stop 'replay state'
 if(any(r%matrix_source_rate_per_day/=r2%matrix_source_rate_per_day))error stop 'replay source'
 q%mb_wall_node_index=0
 call compose_rfm_runtime_candidate(accepted,routing,q,T,r2)
 if(r2%valid)error stop 'invalid MB node'
 print '(a)','PPA_WU05A25_RFM_RUNTIME_ORCHESTRATOR=PASS'
end program
