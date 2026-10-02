module mod_rfm_live_trial_preparer
 use,intrinsic::iso_fortran_env,only:real64
 use mod_soil_water_solver_contract,only:soil_water_top_boundary_result_t,constitutive_hydraulics_provider_t
 use mod_process_hydraulic_view,only:process_hydraulic_view_t
 use mod_rfm_runtime_configuration,only:rfm_runtime_configuration_t
 use mod_rfm_surface_forcing,only:rfm_surface_forcing_t
 use mod_rfm_physical_state,only:rfm_physical_state_t
 use mod_rfm_surface_event_age,only:rfm_surface_event_age_request_t,rfm_surface_event_age_result_t, &
      evaluate_rfm_surface_event_age,RFM_SURFACE_EVENT_AGE_AVAILABLE
 use mod_fmr_rfm_activation_binding,only:fmr_rfm_hydraulic_activation_result_t,evaluate_fmr_rfm_activation_from_view
 use mod_rfm_unponded_activation,only:RFM_ACTIVATION_AVAILABLE
 use mod_rfm_unponded_surface_composition,only:rfm_unponded_surface_composition_result_t, &
      compose_rfm_unponded_surface_receipt,RFM_SURFACE_COMPOSITION_AVAILABLE
 use mod_rfm_preferential_router,only:rfm_preferential_routing_request_t,rfm_preferential_routing_result_t, &
      route_rfm_preferential_supply,RFM_PREF_ROUTER_AVAILABLE
 use mod_rfm_wall_hydraulic_history_binding,only:rfm_wall_hydraulic_binding_result_t, &
      bind_rfm_wall_hydraulics_from_accepted
 use mod_rfm_production_candidate_composer,only:rfm_production_candidate_request_t,rfm_production_candidate_result_t, &
      compose_rfm_production_candidate
 implicit none
 private
 type,public::rfm_live_trial_prepare_result_t
  logical::valid=.false.
  type(rfm_surface_event_age_result_t)::event_age
  type(fmr_rfm_hydraulic_activation_result_t)::activation
  type(rfm_unponded_surface_composition_result_t)::surface
  type(rfm_preferential_routing_result_t)::routing
  type(rfm_wall_hydraulic_binding_result_t)::wall
  type(rfm_production_candidate_result_t)::candidate
 end type
 public::prepare_rfm_live_trial
contains
 subroutine prepare_rfm_live_trial(accepted,config,forcing,view,constitutive,preflight,node_depth_cm,node_thickness_cm, &
      step_duration_day,tolerance,result)
  type(rfm_physical_state_t),intent(in)::accepted
  type(rfm_runtime_configuration_t),intent(in)::config
  type(rfm_surface_forcing_t),intent(in)::forcing
  type(process_hydraulic_view_t),intent(in)::view
  class(constitutive_hydraulics_provider_t),intent(in)::constitutive
  type(soil_water_top_boundary_result_t),intent(in)::preflight
  real(real64),intent(in)::node_depth_cm(:),node_thickness_cm(:),step_duration_day,tolerance
  type(rfm_live_trial_prepare_result_t),intent(out)::result
  type(rfm_surface_event_age_request_t)::ageq
  type(rfm_preferential_routing_request_t)::routeq
  type(rfm_production_candidate_request_t)::cq
  real(real64),allocatable::endpoint_input_cm(:)
  logical::ok
  result=rfm_live_trial_prepare_result_t()
  if(.not.config%valid().or..not.forcing%valid().or..not.accepted%ready())return
  if(size(node_depth_cm)/=view%active_nodes.or.size(node_thickness_cm)/=view%active_nodes)return
  ageq%accepted_age_day=accepted%tau_surface_day;ageq%step_duration_day=step_duration_day
  ageq%event_active=forcing%event_active
  call evaluate_rfm_surface_event_age(ageq,result%event_age)
  if(result%event_age%status/=RFM_SURFACE_EVENT_AGE_AVAILABLE)return
  if(preflight%net_potential_surface_flux==0.0_real64)then
    result%activation=fmr_rfm_hydraulic_activation_result_t()
    result%activation%activation%status=RFM_ACTIVATION_AVAILABLE
  else
    call evaluate_fmr_rfm_activation_from_view(view,constitutive,config%sorptivity_panels,config%sigma_b, &
         preflight%net_potential_surface_flux,result%event_age%evaluation_age_day,result%activation,ok)
    if(.not.ok)return
  end if
  call compose_rfm_unponded_surface_receipt(preflight,result%activation%activation,tolerance,result%surface)
  if(result%surface%status/=RFM_SURFACE_COMPOSITION_AVAILABLE)return
  routeq%f_mb=config%f_mb;routeq%connectivity_p=config%connectivity_p;routeq%z_ah_cm=config%z_ah_cm;routeq%z_ic_cm=config%z_ic_cm
  allocate(routeq%endpoint_depth_cm(size(config%endpoint_depth_cm)));routeq%endpoint_depth_cm=config%endpoint_depth_cm
  call route_rfm_preferential_supply(result%surface,routeq,tolerance,result%routing)
  if(result%routing%status/=RFM_PREF_ROUTER_AVAILABLE)return
  allocate(endpoint_input_cm(size(result%routing%endpoint_amount)))
  endpoint_input_cm=result%routing%endpoint_amount*step_duration_day
  call bind_rfm_wall_hydraulics_from_accepted(accepted,endpoint_input_cm,config%endpoint_node_index,config%mb_wall_node_index, &
       view,constitutive,config%sorptivity_panels,result%wall,skip_unused_mb_hydraulics=.true.)
  if(.not.result%wall%valid)return
  cq%step_duration_day=step_duration_day;cq%effective_supply_rate_cm_per_day=result%surface%effective_supply_cm_per_day
  cq%matrix_supply_rate_cm_per_day=result%surface%matrix_supply_cm_per_day
  cq%candidate_tau_surface_day=result%event_age%candidate_age_day
  cq%exchange_length_cm=config%exchange_length_cm;cq%chi_wall=config%chi_wall
  allocate(cq%endpoint_area_fraction(size(config%endpoint_area_fraction)));cq%endpoint_area_fraction=config%endpoint_area_fraction
  allocate(cq%endpoint_bottom_depth_cm(size(config%endpoint_depth_cm)));cq%endpoint_bottom_depth_cm=config%endpoint_depth_cm
  allocate(cq%endpoint_contact_thickness_cm(size(config%endpoint_contact_thickness_cm)))
  cq%endpoint_contact_thickness_cm=config%endpoint_contact_thickness_cm
  allocate(cq%endpoint_node_index(size(config%endpoint_node_index)));cq%endpoint_node_index=config%endpoint_node_index
  allocate(cq%endpoint_sorptivity_cm_sqrt_day(size(result%wall%endpoint_sorptivity_cm_sqrt_day)))
  cq%endpoint_sorptivity_cm_sqrt_day=result%wall%endpoint_sorptivity_cm_sqrt_day
  allocate(cq%endpoint_conductivity_cm_per_day(size(result%wall%endpoint_conductivity_cm_per_day)))
  cq%endpoint_conductivity_cm_per_day=result%wall%endpoint_conductivity_cm_per_day
  allocate(cq%node_depth_cm(size(node_depth_cm)),cq%node_thickness_cm(size(node_thickness_cm)), &
       cq%matrix_pressure_head_cm(view%active_nodes))
  cq%node_depth_cm=node_depth_cm;cq%node_thickness_cm=node_thickness_cm;cq%matrix_pressure_head_cm=view%pressure_head
  call compose_rfm_production_candidate(accepted,result%routing,cq,tolerance,result%candidate)
  if(.not.result%candidate%valid)return
  result%valid=.true.
 end subroutine
end module
