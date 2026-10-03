program characterize_bartholomeus_e2e03
 use iso_fortran_env,only:real64,int64
 use MOD_grid,only:numnod,z,dz,disnod
 use mod_transaction_reference,only:transaction_state_t,TX_TEMPORAL_MODEL_CERTIFICATE
 use mod_kernel_transactions
 use mod_fixed_flux_top_boundary_provider
 use mod_fmr_runtime_core
 use mod_fmr_serialized_reference_backend
 use mod_fmr_production_application_bootstrap
 use mod_fmr_serialized_multiswap_runtime,only:fmr_serialized_column_result_t
 use mod_b110_default_mvg_provider
 use mod_restricted_soil_temperature
 use mod_bartholomeus_parameter_contract
 use mod_crop_bartholomeus_input
 use mod_root_water_uptake_process
 use mod_bartholomeus_runtime_input,only:bartholomeus_runtime_view_t,build_bartholomeus_runtime_view,BARTHOLOMEUS_INPUT_OK
 use mod_bartholomeus_no_stress_gate,only:bartholomeus_macro_supply_bound_no_stress
 use mod_process_hydraulic_view,only:process_hydraulic_view_t,build_process_hydraulic_view
 use mod_soil_temperature_contract,only:soil_temperature_field_view_t,build_soil_temperature_field_view,SOIL_TEMP_OK
 implicit none
 integer,parameter::NSTEPS=80
 real(real64),parameter::TSTART=5100.1875_real64,DT=1.e-5_real64,T0=TSTART,T1=TSTART+DT,HARD_MASS_GATE=1.e-12_real64
 type(fmr_production_application_config_t)::cfg
 type(fmr_serialized_reference_backend_t)::backend
 type(fixed_flux_top_boundary_provider_t),target::top
 type(fmr_logical_column_t)::column
 type(kernel_committed_state_t)::state
 type(kernel_checkpoint_t)::cp
 type(kernel_candidate_state_t)::candidate
 type(kernel_result_t)::trial
 type(kernel_diagnostics_t)::diag
 type(fmr_serialized_physical_observation_t)::obs
 class(transaction_state_t),allocatable::snap
 type(process_hydraulic_view_t)::hv
 type(soil_temperature_field_view_t)::tv
 type(bartholomeus_runtime_view_t)::bv
 real(real64),allocatable::wr(:)
 real(real64)::k,t0s,t1s,ctop
 integer::i,status,phase,input_status,thermal_status
 logical::ok,viewok,skip
 call initialize_application_config(cfg,-300._real64,k);call add_root_thermal_oxygen(cfg)
 column%column_id=cfg%tiles(1)%tile_id;column%template_id=cfg%tiles(1)%template%template_id
 column%parameter_ref=1_int64;column%state_handle=1_int64;column%forcing_handle=1_int64
 column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
 call backend%initialize(top)
 call fmr_new_b110_temporal_indicator_committed_state(state,column%column_id,cfg%tiles(1)%initial_state,TSTART,ok,cfg%tiles(1)%initial_right_derivative)
 if(.not.ok)error stop 'e2e03 committed init'
 do i=1,NSTEPS
   if(i<=20)then;phase=1;cfg%tiles(1)%base_forcing%top_flux=-k
   else if(i<=40)then;phase=2;cfg%tiles(1)%base_forcing%top_flux=0.25_real64*k
   else if(i<=60)then;phase=3;cfg%tiles(1)%base_forcing%top_flux=0.0_real64
   else;phase=4;cfg%tiles(1)%base_forcing%top_flux=-0.5_real64*k
   endif
   t0s=TSTART+real(i-1,real64)*DT;t1s=t0s+DT
   call state%capture_checkpoint(cp,ok);if(.not.ok)error stop 'e2e03 checkpoint'
   call backend%run_trial(column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,state,cfg%tiles(1)%base_forcing,cfg%numerical,t0s,t1s,cp,trial,candidate,diag)
   if(.not.trial%completed.or..not.candidate%ready())then;print '(a,i0)','E2E03_REJECT_STEP=',i;exit;endif
   obs=backend%observation()
   call backend%commit_trial_candidate(state,candidate,diag,ok,status);if(.not.ok)error stop 'e2e03 commit'
   call state%snapshot(snap,ok);if(.not.ok)error stop 'e2e03 snapshot'
   skip=.false.
   select type(p=>snap)
   class is(fmr_b110_physical_state_t)
     hv=process_hydraulic_view_t()
     hv%active_nodes=p%active_nodes
     allocate(hv%pressure_head(p%active_nodes),hv%water_content(p%active_nodes))
     hv%pressure_head=p%pressure_head;hv%water_content=p%water_content
     viewok=.true.
     if(viewok.and.allocated(p%soil_temperature))then
       call build_soil_temperature_field_view(p%soil_temperature,tv,thermal_status)
       if(thermal_status==SOIL_TEMP_OK)then
         allocate(wr(size(cfg%tiles(1)%base_forcing%crop_oxygen%root_density_kg_m3)))
         wr=1._real64/cfg%tiles(1)%parameters%bartholomeus%specific_root_length_m_kg
         call build_bartholomeus_runtime_view(hv,tv,size(wr),bv,input_status)
         ctop=672._real64/(8.314472_real64*(cfg%tiles(1)%base_forcing%crop_oxygen%air_temperature_c+273._real64))
         if(input_status==BARTHOLOMEUS_INPUT_OK) skip=bartholomeus_macro_supply_bound_no_stress(bv,cfg%tiles(1)%parameters%bartholomeus%soil,cfg%tiles(1)%parameters%bartholomeus%crop,wr,cfg%tiles(1)%base_forcing%crop_oxygen%root_density_kg_m3,ctop)
         deallocate(wr)
       endif
     endif
     print '(a,i0,a,i0,a,l1,a,es13.5,a,es13.5,a,es13.5)','E2E03_STATE_STEP=',i,' PHASE=',phase,' SKIP=',skip, &
          ' H1=',p%pressure_head(1),' THETA1=',p%water_content(1),' OXY_UPTAKE=',obs%root_oxygen_final_uptake
   class default
     error stop 'e2e03 unexpected snapshot type'
   end select
   deallocate(snap)
 enddo
 print '(a)','PPA_WU05C3A_E2E03_TRAJECTORY=PASS'
contains
  subroutine initialize_application_config(value, initial_head, conductivity0)
    type(fmr_production_application_config_t), intent(out) :: value
    real(real64), intent(in) :: initial_head
    real(real64), intent(out) :: conductivity0

    value%initial_time = TSTART
    value%numerical%transaction%temporal_tolerance = 0.0_real64
    value%numerical%transaction%mass_tolerance = HARD_MASS_GATE
    value%numerical%transaction%retry_scale = 0.5_real64
    value%numerical%transaction%max_retries = 2
    value%numerical%max_committed_substeps = 8
    value%numerical%progress_tolerance = 0.0_real64

    allocate(value%tiles(1))
    value%tiles(1)%tile_id = 660101_int64
    value%tiles(1)%ledger_id = 760101_int64
    value%tiles(1)%template%template_id = 660201_int64
    value%tiles(1)%template%physics_topology_id = 660210_int64
    value%tiles(1)%template%vertical_layout_id = 660220_int64
    value%tiles(1)%template%state_layout_id = 660230_int64
    value%tiles(1)%template%solver_interface_id = 660240_int64
    value%tiles(1)%template%optional_state_layout_id = 0_int64
    value%tiles(1)%template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    value%tiles(1)%template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    call initialize_parameters(value%tiles(1)%parameters, 670001_int64)
    call initialize_state_and_forcing(value%tiles(1)%parameters, value%tiles(1)%initial_state, &
         value%tiles(1)%base_forcing, initial_head, conductivity0)
  end subroutine initialize_application_config

  subroutine initialize_parameters(p, parameter_id)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer(int64), intent(in) :: parameter_id
    integer :: k

    p%parameter_set_id = parameter_id
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod), p%cofgen(24, numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)
    p%cofgen = 0.0_real64
    do k = 1, numnod
      p%cofgen(1,k) = 0.032_real64
      p%cofgen(2,k) = 0.423_real64
      p%cofgen(3,k) = 4.75_real64
      p%cofgen(4,k) = 0.0135_real64
      p%cofgen(5,k) = 0.365_real64
      p%cofgen(6,k) = 1.455_real64
      p%cofgen(7,k) = 1.0_real64 - 1.0_real64 / p%cofgen(6,k)
      p%cofgen(8,k) = p%cofgen(4,k)
      p%cofgen(10,k) = p%cofgen(3,k)
      p%cofgen(11,k) = 0.999_real64
      p%cofgen(12,k) = 0.99_real64 * p%cofgen(3,k)
      p%cofgen(22,k) = -1.0e6_real64
      p%cofgen(23,k) = 1.0e-12_real64
    end do
    p%bottom_mode = 2
    p%swkimpl = 0
    p%swkmean = 1
    p%swsophy = 0
    p%max_iterations = 8
    p%max_backtracking = 4
    p%root_extraction_active = .false.
    p%macropore_active = .false.
    p%snow_active = .false.
    p%hysteresis_active = .false.
    p%tabulated_hydraulics_active = .false.
    p%elasticity_active = .false.
    p%frost_active = .false.
    p%soil_temperature_active = .false.
    p%drainage_response_active = .false.
  end subroutine initialize_parameters

  subroutine initialize_state_and_forcing(p, state, forcing, initial_head, conductivity0)
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(in) :: initial_head
    real(real64), intent(out) :: conductivity0

    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)

    heads = initial_head
    call initialize_b110_default_mvg_parameters(hp, p%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, TSTART+DT - TSTART)
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    conductivity0 = conductivity(1)

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
    forcing%top_flux=-conductivity0;forcing%top_head=initial_head;forcing%bottom_flux=-conductivity0;forcing%bottom_head=-100._real64
    allocate(forcing%drainage_flux_by_level(1,numnod),forcing%subsurface_irrigation_source(numnod),forcing%root_extraction_sink(numnod))
    forcing%drainage_flux_by_level=0;forcing%subsurface_irrigation_source=0;forcing%root_extraction_sink=0
  end subroutine initialize_state_and_forcing

 subroutine add_root_thermal_oxygen(value)
  type(fmr_production_application_config_t),intent(inout)::value
  type(b110_default_mvg_parameters_t),target::hp
  type(b110_default_mvg_provider_t)::hydraulic
  type(root_water_uptake_parameters_t)::rp
  type(root_water_uptake_request_t)::rq
  type(root_water_uptake_flux_result_t)::rf
  type(root_water_uptake_diagnostics_t)::rd
  type(process_hydraulic_view_t)::view
  real(real64)::heads(numnod),w100(numnod),w500(numnod),conductivity(numnod),capacity(numnod),dk(numnod)
  integer::s;logical::valid
  value%tiles(1)%ledger_id=0
  value%tiles(1)%parameters%root_extraction_active=.true.;value%tiles(1)%parameters%soil_temperature_active=.true.
  value%tiles(1)%template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE
  allocate(value%tiles(1)%parameters%soil_temperature,value%tiles(1)%initial_state%soil_temperature,value%tiles(1)%base_forcing%soil_temperature,value%tiles(1)%parameters%bartholomeus,value%tiles(1)%base_forcing%crop_oxygen)
  call initialize_soil_temperature_parameters(dz,disnod(1:numnod),value%tiles(1)%parameters%cofgen(2,:),spread(.3_real64,1,numnod),spread(.2_real64,1,numnod),spread(.04_real64,1,numnod),value%tiles(1)%parameters%soil_temperature,s)
  call initialize_soil_temperature_state(spread(20._real64,1,numnod),value%tiles(1)%initial_state%soil_temperature,s)
  value%tiles(1)%base_forcing%soil_temperature%prescribed_surface_temperature_c=20
  call initialize_b110_default_mvg_parameters(hp,value%tiles(1)%parameters%cofgen);call bind_b110_default_mvg_provider(hydraulic,hp,TSTART+DT-TSTART)
  heads=-100;call hydraulic%evaluate(heads,w100,conductivity,capacity,dk);heads=-500;call hydraulic%evaluate(heads,w500,conductivity,capacity,dk)
  associate(p=>value%tiles(1)%parameters%bartholomeus)
   p%selection%oxygen_mode=2;p%selection%oxygen_type=1;p%specific_root_length_m_kg=1
   call construct_bartholomeus_dataset(value%tiles(1)%parameters%cofgen,dz,spread(.02_real64,1,numnod),spread(.6_real64,1,numnod),spread(1300._real64,1,numnod),w100,w500,w100,-100._real64,-500._real64,0,p%soil,valid)
   if(.not.valid) error stop 'oxygen dataset'
   p%crop%c_mroot=1e-5;p%crop%f_senes=1;p%crop%q10_root=2;p%crop%specific_resp_humus=1e-6;p%crop%q10_microbial=2;p%crop%microbial_shape_m=.9;p%crop%root_shape_m=.9;p%crop%root_radius_m=.0002;p%crop%max_resp_factor=2
  end associate
  call publish_crop_bartholomeus_input([1._real64,.8_real64,.6_real64],20._real64,value%tiles(1)%base_forcing%crop_oxygen,valid);if(.not.valid) error stop 'crop oxygen'
  rp%active_nodes=numnod;rp%hlim3l=-500;rp%hlim3h=-300;rp%hlim4=-16000;rp%adcrl=.1_real64;rp%adcrh=.5_real64
  rq%rooted_nodes=3;rq%potential_transpiration=.03_real64;rq%cumulative_root_fraction=[0._real64,.4_real64,.8_real64,1._real64]
  view%active_nodes=numnod;view%pressure_head=value%tiles(1)%initial_state%pressure_head;view%water_content=value%tiles(1)%initial_state%water_content
  call evaluate_macro_feddes_drought_uptake(rp,view,rq,rf,rd);if(rd%status/=ROOT_UPTAKE_OK) error stop 'drought owner';value%tiles(1)%base_forcing%root_extraction_sink=rf%root_extraction_sink
  value%tiles(1)%base_forcing%root_extraction_sink(4)=.005_real64
  value%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  value%tiles(1)%initial_right_derivative=spread(0._real64,1,numnod)
  value%numerical%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
  value%numerical%transaction%temporal_tolerance=1._real64
  value%numerical%model_temporal_indicator_budget_available=.true.
  value%numerical%model_temporal_indicator_budget=.01_real64
 end subroutine
end program characterize_bartholomeus_e2e03
