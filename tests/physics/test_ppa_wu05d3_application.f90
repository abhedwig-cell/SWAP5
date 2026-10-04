program test_ppa_wu05d3_application
  use iso_fortran_env, only: int64,real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value,ieee_quiet_nan
  use MOD_grid, only: numnod,z,dz,disnod
  use mod_fmr_runtime_core
  use mod_fmr_serialized_reference_backend
  use mod_fmr_production_application_bootstrap
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t
  use mod_b110_default_mvg_provider
  use mod_restricted_soil_temperature
  use mod_bartholomeus_parameter_contract
  use mod_crop_bartholomeus_input
  use mod_root_water_uptake_process
  use mod_root_uptake_compensation
  use mod_process_hydraulic_view
  use mod_kernel_transactions
  use mod_fixed_flux_top_boundary_provider
  use mod_transaction_reference, only: TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_fmr_committed_restart
  implicit none
  real(real64),parameter::T0=5100.1875_real64,T1=T0+1.0e-5_real64,HARD_MASS_GATE=1.0e-12_real64
  type(fmr_production_application_config_t)::cfg,off,bad
  type(fmr_production_application_bootstrap_t)::app,offapp,badapp
  type(fmr_serialized_column_result_t),allocatable::a(:),b(:),rejected(:)
  type(fmr_serialized_reference_backend_t)::backend,resumed
  type(fixed_flux_top_boundary_provider_t),target::top
  type(fmr_logical_column_t)::columns(1)
  type(kernel_committed_state_t)::states(1),restored(1)
  type(kernel_checkpoint_t)::cp,cp2
  type(kernel_candidate_state_t)::candidate,other
  type(kernel_result_t)::first,replay,continuation,restart
  type(kernel_diagnostics_t)::diag,diag2
  type(fmr_serialized_physical_observation_t)::obs
  type(fmr_committed_restart_bundle_t)::bundle
  real(real64)::k
  logical::ok
  integer::status,i
  call initialize_application_config(cfg,-75.0_real64,k)
  call add_root_thermal_oxygen(cfg)
  off=cfg
  off%tiles(1)%parameters%bartholomeus%selection%oxygen_mode=0
  call app%initialize(cfg,status)
  call require(status==FMR_APP_BOOT_OK,'actual production application admission')
  call offapp%initialize(off,status)
  call require(status==FMR_APP_BOOT_OK,'OFF application admission')
  call app%run_standalone(T0,T1,a,status)
  if(status/=FMR_APP_BOOT_OK) print *, 'APP_REJECT status/kernel=',status,a(1)%kernel_status
  if(status/=FMR_APP_BOOT_OK) then
    columns(1)%column_id=cfg%tiles(1)%tile_id
    columns(1)%template_id=cfg%tiles(1)%template%template_id
    columns(1)%parameter_ref=1_int64;columns(1)%state_handle=1_int64;columns(1)%forcing_handle=1_int64
    columns(1)%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    call backend%initialize(top)
    call fmr_new_b110_temporal_indicator_committed_state(states(1),columns(1)%column_id, &
         cfg%tiles(1)%initial_state,T0,ok,cfg%tiles(1)%initial_right_derivative)
    call states(1)%capture_checkpoint(cp,ok)
    call backend%run_trial(columns(1),cfg%tiles(1)%template,cfg%tiles(1)%parameters,states(1), &
         cfg%tiles(1)%base_forcing,cfg%numerical,T0,T1,cp,first,candidate,diag)
    obs=backend%observation()
    print *, 'MIXED_DIAG ',diag%solver_rejections,diag%temporal_rejections,diag%mass_rejections
    print *, 'MIXED_COMP ',obs%root_compensation_executed,obs%root_compensation_status
    print *, 'MIXED_SINK ',obs%root_compensation_base_uptake,obs%root_compensation_final_uptake
  end if
  call require(status==FMR_APP_BOOT_OK .and. a(1)%committed,'active application commits')
  call require(abs(a(1)%mass%residual)<=HARD_MASS_GATE,'active hard unrounded water balance')
  call offapp%run_standalone(T0,T1,b,status)
  call require(status==FMR_APP_BOOT_OK .and. b(1)%committed,'OFF application commits')
  call require(abs(b(1)%mass%residual)<=HARD_MASS_GATE,'OFF hard unrounded water balance')
  call app%close(status)
  call offapp%close(status)
  print '(a)','D2_ACTUAL_APPLICATION_ACTIVE_OFF_MASS=PASS'

  columns(1)%column_id=cfg%tiles(1)%tile_id
  columns(1)%template_id=cfg%tiles(1)%template%template_id
  columns(1)%parameter_ref=1_int64;columns(1)%state_handle=1_int64;columns(1)%forcing_handle=1_int64
  columns(1)%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  call backend%initialize(top)
  call resumed%initialize(top)
  call fmr_new_b110_temporal_indicator_committed_state(states(1),columns(1)%column_id, &
       cfg%tiles(1)%initial_state,T0,ok,cfg%tiles(1)%initial_right_derivative)
  call require(ok,'thermal/history owning initial state')
  call states(1)%capture_checkpoint(cp,ok)
  call backend%run_trial(columns(1),cfg%tiles(1)%template,cfg%tiles(1)%parameters,states(1), &
       cfg%tiles(1)%base_forcing,cfg%numerical,T0,T1,cp,first,candidate,diag)
  call require(first%completed .and. candidate%ready(),'actual backend active trial')
  obs=backend%observation()
  call require(obs%bartholomeus_executed .and. obs%bartholomeus_status==0,'actual caller executed oxygen')
  print *, 'D2_OXYGEN ',obs%root_oxygen_base_uptake,obs%root_oxygen_final_uptake
  call require(obs%root_oxygen_final_uptake<obs%root_oxygen_base_uptake,'active physics reduces root sink')
  call require(cfg%tiles(1)%base_forcing%root_drought_reduction_total>0._real64,'actual drought stress')
  print *, 'D2_PUBLICATION ',a(1)%actual_transpiration_available,a(1)%actual_transpiration_amount, &
       obs%root_compensation_final_uptake*(T1-T0)
  call require(a(1)%actual_transpiration_available,'accepted actual transpiration is available')
  call require(a(1)%actual_transpiration_amount>sum(cfg%tiles(1)%base_forcing%root_extraction_sink)*(T1-T0), &
       'accepted transpiration reflects increased final sink')
  call require(obs%root_compensation_executed .and. obs%root_compensation_status==0,'actual compensation caller')
  print *, 'D2_UPTAKE ',obs%root_compensation_base_uptake,obs%root_compensation_final_uptake
  call require(obs%root_compensation_final_uptake>obs%root_compensation_base_uptake,'compensation restores uptake')
  call require(abs(sum(obs%root_compensation_final_sink)-obs%root_compensation_final_uptake)<1.e-14_real64, &
       'final nodewise total identity')
  call require(obs%root_compensation_final_uptake<=cfg%tiles(1)%base_forcing%root_potential_transpiration, &
       'potential transpiration upper bound')
  call require(same_bits(obs%root_oxygen_final_sink(4),cfg%tiles(1)%base_forcing%root_extraction_sink(4)), &
       'non-rooted extraction exactly preserved')
  call require(same_bits(first%mass%total_out,a(1)%mass%total_out),'public application equals actual backend')
  call require(states(1)%current_revision()==0_int64,'unaccepted active trial not committed')
  call backend%discard_trial_candidate(candidate,diag)
  call backend%run_trial(columns(1),cfg%tiles(1)%template,off%tiles(1)%parameters,states(1), &
       off%tiles(1)%base_forcing,off%numerical,T0,T1,cp,replay,other,diag2)
  obs=backend%observation()
  call require(replay%completed .and. .not.obs%bartholomeus_executed,'OFF after active resets')
  call require(same_bits(replay%mass%total_out,b(1)%mass%total_out),'OFF application exact preservation')
  call backend%discard_trial_candidate(other,diag2)
  bad=off
  deallocate(bad%tiles(1)%parameters%bartholomeus,bad%tiles(1)%base_forcing%crop_oxygen)
  call backend%run_trial(columns(1),bad%tiles(1)%template,bad%tiles(1)%parameters,states(1), &
       bad%tiles(1)%base_forcing,bad%numerical,T0,T1,cp,replay,other,diag2)
  call require(replay%completed .and. same_bits(replay%mass%total_out,b(1)%mass%total_out), &
       'OFF bit-identical to pre-existing backend with no oxygen carrier')
  call backend%discard_trial_candidate(other,diag2)
  call backend%run_trial(columns(1),cfg%tiles(1)%template,cfg%tiles(1)%parameters,states(1), &
       cfg%tiles(1)%base_forcing,cfg%numerical,T0,T1,cp,replay,candidate,diag)
  call require(replay%completed .and. same_bits(replay%mass%total_out,first%mass%total_out),'A/B/A exact replay')
  call backend%discard_trial_candidate(candidate,diag)
  bad=cfg
  deallocate(bad%tiles(1)%base_forcing%root_walsum_geometry)
  call backend%run_trial(columns(1),bad%tiles(1)%template,bad%tiles(1)%parameters,states(1), &
       bad%tiles(1)%base_forcing,bad%numerical,T0,T1,cp,replay,other,diag2)
  call require(.not.replay%completed.and.states(1)%current_revision()==0_int64,'missing geometry rollback')
  call backend%run_trial(columns(1),cfg%tiles(1)%template,cfg%tiles(1)%parameters,states(1), &
       cfg%tiles(1)%base_forcing,cfg%numerical,T0,T1,cp,replay,candidate,diag)
  call require(replay%completed.and.same_bits(replay%mass%total_out,first%mass%total_out),'failed then fresh replay')
  call require(abs(first%mass%residual)<=HARD_MASS_GATE,'one root sink booked')
  call backend%commit_trial_candidate(states(1),candidate,diag,ok,status)
  call require(ok,'active interval commit')
  call fmr_export_committed_restart(columns,[cfg%tiles(1)%template],states, &
       cfg%tiles(1)%parameters%parameter_set_id,bundle,ok,status)
  call require(ok .and. status==FMR_RESTART_OK,'owning thermal/hydraulic restart export without oxygen state')
  call fmr_restore_committed_restart(bundle,cfg%tiles(1)%parameters%parameter_set_id,columns, &
       [cfg%tiles(1)%template],restored,ok,status)
  call require(ok .and. status==FMR_RESTART_OK,'fresh worker restart restore')
  cfg%tiles(1)%base_forcing%root_walsum_geometry%critical_root_zone_depth_cm=1._real64
  cfg%tiles(1)%base_forcing%root_walsum_geometry%current_root_depth_cm=2._real64
  call states(1)%capture_checkpoint(cp,ok)
  call restored(1)%capture_checkpoint(cp2,ok)
  call backend%run_trial(columns(1),cfg%tiles(1)%template,cfg%tiles(1)%parameters,states(1), &
       cfg%tiles(1)%base_forcing,cfg%numerical,T1,T1+1.0e-5_real64,cp,continuation,candidate,diag)
  call resumed%run_trial(columns(1),cfg%tiles(1)%template,cfg%tiles(1)%parameters,restored(1), &
       cfg%tiles(1)%base_forcing,cfg%numerical,T1,T1+1.0e-5_real64,cp2,restart,other,diag2)
  call require(continuation%completed .and. restart%completed,'active continued and restored intervals')
  call require(same_bits(continuation%mass%total_out,restart%mass%total_out) .and. &
       same_bits(continuation%mass%storage_end,restart%mass%storage_end),'restart exact identity')
  print '(a)','D2_ACTUAL_CALL_NONROOTED_SINGLE_SINK_ABA_RESTART=PASS'
  call backend%discard_trial_candidate(candidate,diag)
  do i=1,2
    bad=off
    bad%tiles(1)%base_forcing%root_walsum_geometry%current_root_depth_cm=.75_real64
    if(i==2) bad%tiles(1)%base_forcing%root_walsum_geometry%current_root_depth_cm=1.5_real64
    if(i==1) bad%tiles(1)%base_forcing%root_extraction_sink(3)=0._real64
    bad%tiles(1)%base_forcing%root_drought_reduction_total= &
      bad%tiles(1)%base_forcing%root_potential_transpiration-sum(bad%tiles(1)%base_forcing%root_extraction_sink)
    call backend%run_trial(columns(1),bad%tiles(1)%template,bad%tiles(1)%parameters,states(1), &
       bad%tiles(1)%base_forcing,bad%numerical,T1,T1+1.e-5_real64,cp,replay,candidate,diag)
    call require(replay%completed,'changing rooting depth production trial')
    obs=backend%observation()
    k=.9_real64
    if(i==2) k=.7_real64
    call require(abs(obs%root_compensation_final_uptake-min(.03_real64, &
      sum(bad%tiles(1)%base_forcing%root_extraction_sink)/k))<1.e-14_real64,'dynamic alpha independent sink oracle')
    call backend%discard_trial_candidate(candidate,diag)
  end do
  print '(a)','D3_DYNAMIC_GEOMETRY_ROLLBACK_REPLAY_RESTART=PASS'


  do i=1,2
    bad=cfg
    bad%tiles(1)%base_forcing%root_extraction_sink(1:3)=0.0_real64
    if(i==1) bad%tiles(1)%base_forcing%crop_oxygen%root_density_kg_m3=[real(real64)::]
    call backend%run_trial(columns(1),bad%tiles(1)%template,bad%tiles(1)%parameters,states(1), &
         bad%tiles(1)%base_forcing,bad%numerical,T1,T1+1.0e-5_real64,cp,first,candidate,diag)
    obs=backend%observation()
    call require(first%completed .and. obs%bartholomeus_executed,'active no-roots/zero-demand trial')
    call require(all(abs(obs%root_oxygen_final_sink-bad%tiles(1)%base_forcing%root_extraction_sink)<=0), &
         'no roots/zero demand preserve supplied sink')
    call require(abs(first%mass%residual)<=HARD_MASS_GATE,'no roots/zero demand single owner mass')
    call backend%discard_trial_candidate(candidate,diag)
  end do
  print '(a)','D2_ACTUAL_APPLICATION_NO_ROOTS_ZERO_DEMAND=PASS'

  do i=1,7
    bad=cfg
    select case(i)
    case(1)
      bad%tiles(1)%parameters%bartholomeus%selection%oxygen_mode=1
    case(2)
      bad%tiles(1)%parameters%bartholomeus%selection%hydraulic_waterfilm_mode=1
    case(3)
      deallocate(bad%tiles(1)%base_forcing%crop_oxygen)
    case(4)
      bad%tiles(1)%base_forcing%crop_oxygen%root_density_kg_m3(1)=ieee_value(k,ieee_quiet_nan)
    case(5)
      bad%tiles(1)%parameters%bartholomeus%specific_root_length_m_kg=0
    case(6)
      bad%tiles(1)%parameters%bartholomeus%soil%soil(1)%depth_m=1.0_real64
    case(7)
      bad%tiles(1)%parameters%bartholomeus%soil%soil(1)%waterfilm_gen_n=3.0_real64
    end select
    call badapp%initialize(bad,status)
    if(status==FMR_APP_BOOT_OK) then
      call badapp%run_standalone(T0,T1,rejected,status)
      call require(status/=FMR_APP_BOOT_OK,'invalid actual input fail closed')
    end if
    call badapp%close(status)
  end do
  bad=off
  deallocate(bad%tiles(1)%parameters%bartholomeus,bad%tiles(1)%base_forcing%crop_oxygen, &
       bad%tiles(1)%parameters%soil_temperature,bad%tiles(1)%initial_state%soil_temperature, &
       bad%tiles(1)%base_forcing%soil_temperature)
  bad%tiles(1)%parameters%soil_temperature_active=.false.
  bad%tiles(1)%template%optional_state_layout_id=0_int64
  call badapp%initialize(bad,status)
  call require(status==FMR_APP_BOOT_OK,'Jarvis application without oxygen or thermal carrier')
  call badapp%run_standalone(T0,T1,rejected,status)
  call require(status==FMR_APP_BOOT_OK.and.rejected(1)%committed,'drought-only application commits')
  call require(abs(rejected(1)%mass%residual)<=HARD_MASS_GATE,'drought-only one water owner')
  call require(rejected(1)%actual_transpiration_available,'drought-only accepted uptake published')
  call badapp%close(status)
  print '(a)','D2_DROUGHT_WITHOUT_OXYGEN_CARRIER=PASS'
  print '(a)','D2_ACTUAL_APPLICATION_UNSUPPORTED_INVALID=PASS'
  print '(a)','PPA_WU05D3_APPLICATION_CHAIN=PASS'
contains
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
    integer::s
    logical::valid
    value%tiles(1)%ledger_id=0_int64
    value%tiles(1)%parameters%root_extraction_active=.true.
    value%tiles(1)%parameters%soil_temperature_active=.true.
    value%tiles(1)%template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE
    allocate(value%tiles(1)%parameters%soil_temperature,value%tiles(1)%initial_state%soil_temperature, &
         value%tiles(1)%base_forcing%soil_temperature,value%tiles(1)%parameters%bartholomeus, &
         value%tiles(1)%base_forcing%crop_oxygen)
    call initialize_soil_temperature_parameters(dz,disnod(1:numnod),value%tiles(1)%parameters%cofgen(2,:), &
         spread(.3_real64,1,numnod),spread(.2_real64,1,numnod),spread(.04_real64,1,numnod), &
         value%tiles(1)%parameters%soil_temperature,s)
    call require(s==SOIL_TEMP_OK,'real thermal construction')
    call initialize_soil_temperature_state(spread(20.0_real64,1,numnod),value%tiles(1)%initial_state%soil_temperature,s)
    call require(s==SOIL_TEMP_OK,'real thermal initial state')
    value%tiles(1)%base_forcing%soil_temperature%prescribed_surface_temperature_c=20.0_real64
    call initialize_b110_default_mvg_parameters(hp,value%tiles(1)%parameters%cofgen)
    call bind_b110_default_mvg_provider(hydraulic,hp,T1-T0)
    heads=-100.0_real64;call hydraulic%evaluate(heads,w100,conductivity,capacity,dk)
    heads=-500.0_real64;call hydraulic%evaluate(heads,w500,conductivity,capacity,dk)
    associate(p=>value%tiles(1)%parameters%bartholomeus)
      p%selection%oxygen_mode=2;p%selection%oxygen_type=1
      p%specific_root_length_m_kg=1.0_real64
      call construct_bartholomeus_dataset(value%tiles(1)%parameters%cofgen,dz,spread(.02_real64,1,numnod), &
           spread(.6_real64,1,numnod),spread(1300.0_real64,1,numnod),w100,w500,w100,-100.0_real64, &
           -500.0_real64,0,p%soil,valid)
      call require(valid,'owner-bound oxygen immutable construction')
      p%crop%c_mroot=2.0e-6_real64;p%crop%f_senes=1;p%crop%q10_root=2
      p%crop%specific_resp_humus=1.0e-8_real64;p%crop%q10_microbial=2
      p%crop%microbial_shape_m=.9_real64;p%crop%root_shape_m=.9_real64
      p%crop%root_radius_m=.0002_real64;p%crop%max_resp_factor=2
    end associate
    call publish_crop_bartholomeus_input([1.0_real64,.008_real64,.0006_real64],20.0_real64, &
         value%tiles(1)%base_forcing%crop_oxygen,valid)
    call require(valid,'separate source-unit crop view publication')
    ! Existing drought owner creates the base sink. Oxygen never creates water.
    rp%active_nodes=numnod;rp%hlim3l=-50;rp%hlim3h=-30;rp%hlim4=-150;rp%adcrl=.1_real64;rp%adcrh=.5_real64
    rq%rooted_nodes=3;rq%potential_transpiration=.03_real64;rq%cumulative_root_fraction=[0.0_real64,.4_real64,.8_real64,1.0_real64]
    view%active_nodes=numnod;view%pressure_head=value%tiles(1)%initial_state%pressure_head
    view%water_content=value%tiles(1)%initial_state%water_content
    call evaluate_macro_feddes_drought_uptake(rp,view,rq,rf,rd)
    call require(rd%status==ROOT_UPTAKE_OK,'existing drought owner evaluated')
    value%tiles(1)%base_forcing%root_extraction_sink=rf%root_extraction_sink
    value%tiles(1)%base_forcing%root_potential_sink=rd%potential_root_sink
    value%tiles(1)%base_forcing%root_potential_transpiration=rq%potential_transpiration
    value%tiles(1)%base_forcing%root_drought_reduction_total=rd%drought_reduction_total
    value%tiles(1)%parameters%root_compensation%method=ROOT_COMP_WALSUM
    value%tiles(1)%parameters%root_compensation%stressor=ROOT_COMP_ALL
    value%tiles(1)%parameters%root_compensation%alpha_critical=.7_real64
    value%tiles(1)%base_forcing%root_walsum_geometry=root_walsum_geometry_t(.5_real64,5._real64,1.5_real64)
    ! Existing history certificate is selected explicitly, not changed or relaxed.
    value%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    value%tiles(1)%initial_right_derivative=spread(0.0_real64,1,numnod)
    value%numerical%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
    value%numerical%transaction%temporal_tolerance=1.0_real64
    value%numerical%model_temporal_indicator_budget_available=.true.
    value%numerical%model_temporal_indicator_budget=.01_real64
  end subroutine
  subroutine initialize_application_config(value, initial_head, conductivity0)
    type(fmr_production_application_config_t), intent(out) :: value
    real(real64), intent(in) :: initial_head
    real(real64), intent(out) :: conductivity0

    value%initial_time = T0
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
    call bind_b110_default_mvg_provider(provider, hp, T1 - T0)
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    conductivity0 = conductivity(1)

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64

    forcing%top_flux = -conductivity0
    forcing%top_head = initial_head
    forcing%bottom_flux = -conductivity0
    forcing%bottom_head = -100.0_real64
    allocate(forcing%drainage_flux_by_level(1,numnod), forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    forcing%drainage_flux_by_level = 0.0_real64
    forcing%subsurface_irrigation_source = 0.0_real64
    forcing%root_extraction_sink = 0.0_real64
  end subroutine initialize_state_and_forcing


  logical function same_bits(x,y) result(same)
    real(real64),intent(in)::x,y
    integer(int64)::ix,iy
    ix=transfer(x,ix);iy=transfer(y,iy);same=ix==iy
  end function
  subroutine require(valid,label)
    logical,intent(in)::valid
    character(*),intent(in)::label
    if(.not.valid) then
      print '(a,a)','C3A_APPLICATION_FAIL: ',label
      error stop 1
    end if
  end subroutine
end program
