program test_ppa_wu05a6_source_rate_replay
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_macropore_continuation_state, only: macropore_continuation_state_t
  use mod_ppa_wu05a5_multi_domain_process, only: macropore_geometry_config_t, &
       macropore_geometry_result_t, macropore_multi_domain_receipt_t, &
       evaluate_macropore_geometry, compose_macropore_candidate
  use mod_ppa_wu05a5_macropore_restart, only: macropore_restart_payload_t, &
       encode_macropore_restart, decode_macropore_restart
  use mod_ppa_wu05a6_rate_bundle, only: macropore_rate_bundle_request_t, &
       macropore_rate_bundle_result_t, evaluate_macropore_rate_bundle
  use mod_ppa_wu05a6_sorptivity_history, only: sorptivity_history_update_request_t, &
       apply_sorptivity_history_update
  use mod_ppa_wu05a6_vertical_flux_reconstruction, only: vertical_flux_reconstruction_request_t, &
       vertical_flux_reconstruction_result_t, reconstruct_vertical_flux
  implicit none

  integer,parameter::nd=1,n=3
  real(real64),parameter::dt=0.1_real64

  type(macropore_continuation_state_t)::accepted,candidate,restored,next_a,next_b
  type(macropore_restart_payload_t)::payload
  type(macropore_geometry_config_t)::geometry_config
  type(macropore_geometry_result_t)::geometry,geometry_restored
  type(macropore_rate_bundle_request_t)::rate_request_a,rate_request_b
  type(macropore_rate_bundle_result_t)::rates_a,rates_b,next_rates_a,next_rates_b
  type(macropore_multi_domain_receipt_t)::receipt_a,receipt_b,next_receipt_a,next_receipt_b
  type(sorptivity_history_update_request_t)::history_request
  type(vertical_flux_reconstruction_request_t)::vertical_request
  type(vertical_flux_reconstruction_result_t)::vertical_result
  logical::ok

  call accepted%initialize(nd,n,ok)
  if(.not.ok)error stop 'A6 replay accepted init'
  accepted%icp_bottom_domain=3
  accepted%dynamic_volume_cp=[0.05_real64,0.05_real64,0.05_real64]

  call setup_geometry(geometry_config)
  call evaluate_macropore_geometry(geometry_config,accepted%dynamic_volume_cp,geometry)
  if(.not.geometry%valid)error stop 'A6 replay geometry'
  accepted%icp_bottom_domain=geometry%bottom_domain
  accepted%volume_domain_cp=geometry%volume_domain_cp
  accepted%water_domain_cp=0.30_real64*geometry%volume_domain_cp

  call prepare_rate_request(accepted,geometry,rate_request_a)
  call evaluate_macropore_rate_bundle(rate_request_a,rates_a)
  if(.not.rates_a%valid)error stop 'A6 replay rates A'

  call compose_macropore_candidate(accepted,geometry,rates_a%top_partition,rates_a%qexc_to_matrix_rate, &
       rates_a%rapid_outflow_cp_cm,dt,candidate,receipt_a,ok)
  if(.not.ok .or. .not.receipt_a%valid)error stop 'A6 replay compose A'

  call prepare_history_request(history_request)
  call apply_sorptivity_history_update(history_request,accepted,rates_a%unsaturated,candidate,ok)
  if(.not.ok)error stop 'A6 replay history A'

  call prepare_vertical_request(accepted,candidate,rates_a,vertical_request)
  call reconstruct_vertical_flux(vertical_request,vertical_result)
  if(.not.vertical_result%valid)error stop 'A6 replay vertical A'
  if(vertical_result%max_local_residual_rate>1.0e-12_real64)error stop 'A6 replay vertical residual'

  call encode_macropore_restart(candidate,payload,ok)
  if(.not.ok)error stop 'A6 replay encode'
  call decode_macropore_restart(payload,restored,ok)
  if(.not.ok)error stop 'A6 replay decode'
  if(.not.restored%same_values(candidate))error stop 'A6 replay state identity'

  call evaluate_macropore_geometry(geometry_config,restored%dynamic_volume_cp,geometry_restored)
  if(.not.geometry_restored%valid)error stop 'A6 replay geometry restored'
  if(maxval(abs(geometry_restored%volume_domain_cp-geometry%volume_domain_cp))>1.0e-15_real64) &
       error stop 'A6 replay geometry identity'

  ! Generate the next source-rate step from uninterrupted and restored accepted states.
  call prepare_rate_request(candidate,geometry,rate_request_a)
  call prepare_rate_request(restored,geometry_restored,rate_request_b)
  call evaluate_macropore_rate_bundle(rate_request_a,next_rates_a)
  call evaluate_macropore_rate_bundle(rate_request_b,next_rates_b)
  if(.not.next_rates_a%valid .or. .not.next_rates_b%valid)error stop 'A6 replay next rates'
  if(maxval(abs(next_rates_a%qexc_to_matrix_rate-next_rates_b%qexc_to_matrix_rate))>1.0e-15_real64) &
       error stop 'A6 replay qexc identity'
  if(maxval(abs(next_rates_a%rapid_outflow_cp_cm-next_rates_b%rapid_outflow_cp_cm))>1.0e-15_real64) &
       error stop 'A6 replay rapid identity'
  if(abs(next_rates_a%top_partition%accepted_total_cm-next_rates_b%top_partition%accepted_total_cm)>1.0e-15_real64) &
       error stop 'A6 replay top identity'

  call compose_macropore_candidate(candidate,geometry,next_rates_a%top_partition,next_rates_a%qexc_to_matrix_rate, &
       next_rates_a%rapid_outflow_cp_cm,dt,next_a,next_receipt_a,ok)
  if(.not.ok)error stop 'A6 replay next candidate A'
  call apply_sorptivity_history_update(history_request,candidate,next_rates_a%unsaturated,next_a,ok)
  if(.not.ok)error stop 'A6 replay next history A'

  call compose_macropore_candidate(restored,geometry_restored,next_rates_b%top_partition,next_rates_b%qexc_to_matrix_rate, &
       next_rates_b%rapid_outflow_cp_cm,dt,next_b,next_receipt_b,ok)
  if(.not.ok)error stop 'A6 replay next candidate B'
  call apply_sorptivity_history_update(history_request,restored,next_rates_b%unsaturated,next_b,ok)
  if(.not.ok)error stop 'A6 replay next history B'

  if(.not.next_a%same_values(next_b))error stop 'A6 replay next state identity'
  if(abs(next_receipt_a%macro_balance_residual_cm-next_receipt_b%macro_balance_residual_cm)>1.0e-15_real64) &
       error stop 'A6 replay receipt identity'

  print '(a)', 'PPA_WU05A6_SOURCE_RATE_REPLAY=PASS'

contains

  subroutine setup_geometry(config)
    type(macropore_geometry_config_t),intent(out)::config
    config%num_domains=nd
    config%num_nodes=n
    config%top_node=1
    allocate(config%static_volume_cp(n),config%domain_fraction(nd,n), &
         config%potential_bottom_domain(nd),config%dz(n),config%characteristic_diameter(n))
    config%static_volume_cp=0.50_real64
    config%domain_fraction=1.0_real64
    config%potential_bottom_domain=3
    config%dz=10.0_real64
    config%characteristic_diameter=4.0_real64
  end subroutine setup_geometry

  subroutine prepare_rate_request(state,geom,request)
    type(macropore_continuation_state_t),intent(in)::state
    type(macropore_geometry_result_t),intent(in)::geom
    type(macropore_rate_bundle_request_t),intent(out)::request

    call setup_unsat(state,request)
    call setup_sat(request%interflow_sat,2,2,-15.0_real64,10.0_real64)
    call setup_sat(request%matrix_sat,3,3,-25.0_real64,2.0_real64)

    request%rapid%num_nodes=n
    request%rapid%top_water_node=1
    request%rapid%bottom_domain_node=geom%bottom_domain(1)
    request%rapid%drain_type=2
    request%rapid%enabled=.true.
    request%rapid%saturated_top_fraction=1.0_real64
    request%rapid%water_level_cm=-15.0_real64
    request%rapid%domain_bottom_cm=-30.0_real64
    request%rapid%drain_level_cm=-25.0_real64
    request%rapid%ponding_cm=0.0_real64
    request%rapid%step_duration=dt
    request%rapid%area_exponent=3.0_real64
    request%rapid%kd_reference=0.001_real64
    request%rapid%resistance_reference_day=1000.0_real64
    request%rapid%flow_reduction=1.0_real64
    request%rapid%water_storage_cm=sum(state%water_domain_cp)
    request%rapid%volume_under_drain_cm=0.0_real64
    allocate(request%rapid%diameter(n),request%rapid%dz(n),request%rapid%volume_main_domain_cp(n))
    request%rapid%diameter=4.0_real64
    request%rapid%dz=10.0_real64
    request%rapid%volume_main_domain_cp=geom%volume_domain_cp(1,:)

    request%limiter%num_domains=nd
    allocate(request%limiter%accepted_storage_cm(nd),request%limiter%maximum_storage_cm(nd), &
         request%limiter%minimum_storage_cm(nd),request%limiter%potential_top_vertical_cm(nd), &
         request%limiter%potential_top_lateral_cm(nd),request%limiter%potential_interflow_sat_cm(nd), &
         request%limiter%potential_matrix_sat_cm(nd),request%limiter%potential_outflow_cm(nd), &
         request%limiter%redistribution_capacity_cm(nd),request%limiter%top_domain_fraction(nd))
    request%limiter%accepted_storage_cm=sum(state%water_domain_cp,dim=2)
    request%limiter%maximum_storage_cm=sum(geom%volume_domain_cp,dim=2)
    request%limiter%minimum_storage_cm=0.0_real64
    request%limiter%potential_top_vertical_cm=0.004_real64
    request%limiter%potential_top_lateral_cm=0.002_real64
    request%limiter%potential_interflow_sat_cm=0.0_real64
    request%limiter%potential_matrix_sat_cm=0.0_real64
    request%limiter%potential_outflow_cm=0.0_real64
    request%limiter%redistribution_capacity_cm=max(0.0_real64, &
         request%limiter%maximum_storage_cm-request%limiter%accepted_storage_cm)
    request%limiter%top_domain_fraction=1.0_real64
    request%top_node=1
  end subroutine prepare_rate_request

  subroutine setup_unsat(state,bundle)
    type(macropore_continuation_state_t),intent(in)::state
    type(macropore_rate_bundle_request_t),intent(inout)::bundle

    allocate(bundle%unsaturated%sorptivity%bottom_domain(nd),bundle%unsaturated%sorptivity%top_water_node(nd), &
         bundle%unsaturated%sorptivity%theta(n),bundle%unsaturated%sorptivity%theta_s(n), &
         bundle%unsaturated%sorptivity%theta_r(n),bundle%unsaturated%sorptivity%dz(n), &
         bundle%unsaturated%sorptivity%diameter(n),bundle%unsaturated%sorptivity%wall_correction(n), &
         bundle%unsaturated%sorptivity%sorptivity_max(n),bundle%unsaturated%sorptivity%sorptivity_alpha(n), &
         bundle%unsaturated%sorptivity%domain_fraction(nd,n),bundle%unsaturated%sorptivity%wet_fraction(nd,n), &
         bundle%unsaturated%sorptivity%history_sorptivity(nd,n), &
         bundle%unsaturated%sorptivity%history_theta_ref(nd,n), &
         bundle%unsaturated%sorptivity%history_absorption_time(nd,n),bundle%unsaturated%pressure_head(n), &
         bundle%unsaturated%elevation(n),bundle%unsaturated%conductivity(n),bundle%unsaturated%entry_head(n), &
         bundle%unsaturated%groundwater_level_domain(nd),bundle%unsaturated%sorp_fac_parallel(n))

    bundle%unsaturated%sorptivity%num_domains=nd
    bundle%unsaturated%sorptivity%num_nodes=n
    bundle%unsaturated%sorptivity%top_node=1
    bundle%unsaturated%sorptivity%swmbf=1
    bundle%unsaturated%sorptivity%matrix_top_saturated_node=3
    bundle%unsaturated%sorptivity%step_duration=dt
    bundle%unsaturated%sorptivity%flow_reduction=1.0_real64
    bundle%unsaturated%sorptivity%bottom_domain=state%icp_bottom_domain
    bundle%unsaturated%sorptivity%top_water_node=1
    bundle%unsaturated%sorptivity%theta=0.20_real64
    bundle%unsaturated%sorptivity%theta_s=0.45_real64
    bundle%unsaturated%sorptivity%theta_r=0.05_real64
    bundle%unsaturated%sorptivity%dz=10.0_real64
    bundle%unsaturated%sorptivity%diameter=4.0_real64
    bundle%unsaturated%sorptivity%wall_correction=0.95_real64
    bundle%unsaturated%sorptivity%sorptivity_max=0.001_real64
    bundle%unsaturated%sorptivity%sorptivity_alpha=0.5_real64
    bundle%unsaturated%sorptivity%domain_fraction=1.0_real64
    bundle%unsaturated%sorptivity%wet_fraction=1.0_real64
    bundle%unsaturated%sorptivity%history_sorptivity=state%sorptivity
    bundle%unsaturated%sorptivity%history_theta_ref=state%theta_sorption_ref
    bundle%unsaturated%sorptivity%history_absorption_time=state%absorption_time
    bundle%unsaturated%shape_factor=1.0_real64
    bundle%unsaturated%pressure_head=-100.0_real64
    bundle%unsaturated%elevation=[-10.0_real64,-20.0_real64,-30.0_real64]
    bundle%unsaturated%conductivity=0.001_real64
    bundle%unsaturated%entry_head=-1.0_real64
    bundle%unsaturated%groundwater_level_domain=-15.0_real64
    bundle%unsaturated%sorp_fac_parallel=0.5_real64
  end subroutine setup_unsat

  subroutine setup_sat(request,top_sat,bottom_sat,ref_level,active_head)
    use mod_ppa_wu05a6_saturated_exchange_rate, only: saturated_exchange_request_t
    type(saturated_exchange_request_t),intent(out)::request
    integer,intent(in)::top_sat,bottom_sat
    real(real64),intent(in)::ref_level,active_head

    request%num_domains=nd
    request%num_nodes=n
    request%matrix_top_saturated_node=top_sat
    request%matrix_bottom_saturated_node=bottom_sat
    request%swsep=0
    request%matrix_level=-15.0_real64
    request%step_duration=dt
    request%flow_reduction=1.0_real64
    request%shape_factor=1.0_real64
    allocate(request%bottom_domain(nd),request%top_macro_saturated_node(nd), &
         request%macro_saturated_fraction(nd),request%macro_reference_level(nd),request%z(n),request%dz(n), &
         request%matrix_head(n),request%ksat_horizontal(n),request%diameter(n),request%domain_fraction(nd,n), &
         request%cdarcy(nd,n))
    request%bottom_domain=3
    request%top_macro_saturated_node=top_sat
    request%macro_saturated_fraction=1.0_real64
    request%macro_reference_level=ref_level
    request%z=[-10.0_real64,-20.0_real64,-30.0_real64]
    request%dz=10.0_real64
    request%matrix_head=active_head
    request%ksat_horizontal=0.01_real64
    request%diameter=4.0_real64
    request%domain_fraction=1.0_real64
    request%cdarcy=0.0001_real64
  end subroutine setup_sat

  subroutine prepare_history_request(request)
    type(sorptivity_history_update_request_t),intent(out)::request
    request%num_domains=nd
    request%num_nodes=n
    request%top_node=1
    request%matrix_top_saturated_node=3
    request%step_duration=dt
    allocate(request%bottom_domain(nd),request%top_water_node(nd),request%wall_correction(n), &
         request%wet_fraction(nd,n),request%domain_fraction(nd,n),request%diameter(n))
    request%bottom_domain=3
    request%top_water_node=1
    request%wall_correction=0.95_real64
    request%wet_fraction=1.0_real64
    request%domain_fraction=1.0_real64
    request%diameter=4.0_real64
  end subroutine prepare_history_request

  subroutine prepare_vertical_request(previous,current,rates,request)
    type(macropore_continuation_state_t),intent(in)::previous,current
    type(macropore_rate_bundle_result_t),intent(in)::rates
    type(vertical_flux_reconstruction_request_t),intent(out)::request
    request%num_domains=nd
    request%num_nodes=n
    request%top_node=1
    request%step_duration=dt
    allocate(request%bottom_domain(nd),request%top_inflow_rate(nd),request%previous_water_cm(nd,n), &
         request%current_water_cm(nd,n),request%exchange_to_matrix_rate(nd,n),request%external_outflow_rate(nd,n))
    request%bottom_domain=current%icp_bottom_domain
    request%top_inflow_rate=(rates%top_partition%accepted_vertical_cm+rates%top_partition%accepted_lateral_cm)/dt
    request%previous_water_cm=previous%water_domain_cp
    request%current_water_cm=current%water_domain_cp
    request%exchange_to_matrix_rate=rates%qexc_to_matrix_rate
    request%external_outflow_rate=0.0_real64
    request%external_outflow_rate(1,:)=rates%rapid_outflow_cp_cm/dt
  end subroutine prepare_vertical_request

end program test_ppa_wu05a6_source_rate_replay
