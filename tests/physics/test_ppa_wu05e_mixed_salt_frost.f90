program test_ppa_wu05e_mixed_salt_frost
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
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_soil_temperature_contract, only: soil_temperature_restart_payload_t, &
       export_soil_temperature_restart,reconstruct_soil_temperature_restart
  use mod_fmr_committed_restart
  use mod_fmr_restart_state_contract, only: fmr_restart_state_matches_template
  use mod_rutter_source_window_processor, only: initialize_rutter_canopy_state, RUTTER_WINDOW_OK
  implicit none
  real(real64),parameter::T0=5100.1875_real64,T1=T0+1.e-5_real64,HARD_MASS_GATE=1.e-12_real64
  type(fmr_production_application_config_t)::cfg,bad,oracle
  type(fmr_production_application_bootstrap_t)::app,badapp
  type(fmr_serialized_column_result_t),allocatable::app_results(:),scenario_results(:)
  type(fmr_serialized_reference_backend_t)::backend,resumed
  type(fixed_flux_top_boundary_provider_t),target::top
  type(fmr_base_salt_temporal_policy_t)::policy,tight
  type(fmr_logical_column_t)::columns(1)
  type(kernel_committed_state_t)::states(1),restored(1)
  type(kernel_checkpoint_t)::cp,cp2
  type(kernel_candidate_state_t)::candidate,other
  type(kernel_result_t)::first,replay,continuation,restart
  type(kernel_diagnostics_t)::diag,diag2
  type(fmr_serialized_physical_observation_t)::obs,obs2
  type(fmr_committed_restart_bundle_t)::bundle
  class(transaction_state_t),allocatable::snapshot,after
  real(real64)::k,expected_alpha,losses(4),raw(numnod),dry(numnod),frs(numnod),potential(numnod),a(4),w,q,total
  integer::status,scenario,j,selector
  character(512)::mode,restart_path,result_path,variant,compensation
  logical::ok,dispersive,walsum
  call get_command_argument(1,mode)
  call get_command_argument(2,restart_path)
  call get_command_argument(3,result_path)
  call get_command_argument(4,variant)
  call get_command_argument(5,compensation)
  dispersive=trim(variant)=='dispersion'
  walsum=trim(compensation)=='walsum'
  call initialize_application_config(cfg,-75._real64,k)
  call add_root_thermal_oxygen(cfg)
  if(walsum)then
    cfg%tiles(1)%parameters%root_compensation%method=ROOT_COMP_WALSUM
    ! Walsum derives alpha from current geometry, ignoring this poisoned fixed alpha.
    cfg%tiles(1)%parameters%root_compensation%alpha_critical=ieee_value(0._real64,ieee_quiet_nan)
    allocate(cfg%tiles(1)%base_forcing%root_walsum_geometry)
    cfg%tiles(1)%base_forcing%root_walsum_geometry=root_walsum_geometry_t(.5_real64,5._real64,1.5_real64)
  end if
  cfg%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
  cfg%tiles(1)%template%solute_state_layout_id=FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED
  cfg%numerical%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
  cfg%numerical%model_temporal_indicator_budget_available=.false.
  cfg%tiles(1)%parameters%root_salinity_active=.true.
  cfg%tiles(1)%parameters%solute_tscf=1._real64
  cfg%tiles(1)%parameters%saltmax_mg_cm3=0._real64
  cfg%tiles(1)%parameters%saltslope_cm3_mg=1._real64
  cfg%tiles(1)%parameters%salt_temporal_tolerance_mg_cm2=0._real64
  call fmr_initialize_mobile_salt_profile(cfg%tiles(1)%initial_state,dz,[.1_real64,.3_real64,.6_real64,.1_real64],status)
  call require(status==0,'matrix salt initialization')
  deallocate(cfg%tiles(1)%parameters%bartholomeus,cfg%tiles(1)%base_forcing%crop_oxygen)
  cfg%tiles(1)%parameters%frost_active=.true.
  cfg%tiles(1)%parameters%frost_hydraulic%active=.true.
  cfg%tiles(1)%parameters%frost_hydraulic%reduction_start_c=0._real64
  cfg%tiles(1)%parameters%frost_hydraulic%reduction_end_c=-2._real64
  cfg%tiles(1)%parameters%root_frost%active=.true.
  cfg%tiles(1)%parameters%root_frost%rooted_nodes=3
  cfg%tiles(1)%parameters%root_frost_head_budget_cm=1.e-6_real64
  cfg%tiles(1)%parameters%root_frost_temperature_budget_c=1.e-6_real64
  deallocate(cfg%tiles(1)%initial_state%soil_temperature)
  allocate(cfg%tiles(1)%initial_state%soil_temperature)
  call initialize_soil_temperature_state([-1._real64,1._real64,-1._real64,1._real64], &
       cfg%tiles(1)%initial_state%soil_temperature,status)
  call require(status==SOIL_TEMP_OK,'joint thermal fixture')
  cfg%tiles(1)%base_forcing%soil_temperature%prescribed_surface_temperature_c=-1._real64
  cfg%tiles(1)%base_forcing%top_flux=0._real64
  cfg%tiles(1)%base_forcing%bottom_flux=0._real64
  cfg%tiles(1)%base_forcing%subsurface_irrigation_source=0._real64
  allocate(cfg%tiles(1)%base_forcing%c_drain_salt,cfg%tiles(1)%base_forcing%soil_salt_boundary)
  associate(f=>cfg%tiles(1)%base_forcing)
    f%c_drain_salt%revision=0_int64;f%c_drain_salt%available=.true.;f%c_drain_salt%source_id=1_int64
    f%c_drain_salt%unit_id=1;f%c_drain_salt%valid_t0=T0;f%c_drain_salt%valid_t1=T1+1.e-5_real64
    f%c_drain_salt%concentration_mg_cm3=.25_real64
    f%soil_salt_boundary%revision=0_int64;f%soil_salt_boundary%available=.true.;f%soil_salt_boundary%source_id=1_int64
    f%soil_salt_boundary%unit_id=1;f%soil_salt_boundary%valid_t0=T0;f%soil_salt_boundary%valid_t1=T1+1.e-5_real64
    f%soil_salt_boundary%matrix_top_mg_cm3=.4_real64;f%soil_salt_boundary%matrix_bottom_mg_cm3=.2_real64
  end associate
  deallocate(cfg%tiles(1)%base_forcing%drainage_flux_by_level)
  allocate(cfg%tiles(1)%base_forcing%drainage_flux_by_level(2,numnod))
  cfg%tiles(1)%base_forcing%drainage_flux_by_level(1,:)=0._real64
  cfg%tiles(1)%base_forcing%drainage_flux_by_level(2,:)=0._real64
  cfg%tiles(1)%base_forcing%subsurface_irrigation_source=0._real64
  if(dispersive)then
    allocate(cfg%tiles(1)%parameters%mobile_dispersion)
    associate(p=>cfg%tiles(1)%parameters%mobile_dispersion)
      p%molecular_diffusion_cm2_day=.05_real64
      allocate(p%dispersivity_cm(numnod-1),p%theta_sat_left(numnod-1), &
        p%face_distance_cm(numnod-1),p%face_left_weight(numnod-1),p%face_right_weight(numnod-1))
      p%dispersivity_cm=.5_real64;p%theta_sat_left=cfg%tiles(1)%parameters%cofgen(2,1:numnod-1)
      p%face_distance_cm=cfg%tiles(1)%parameters%node_distance(2:numnod)
      p%face_left_weight=.5_real64*dz(2:numnod)/p%face_distance_cm
      p%face_right_weight=.5_real64*dz(1:numnod-1)/p%face_distance_cm
    end associate
  end if
  cfg%numerical%transaction%max_retries=20
  cfg%numerical%max_committed_substeps=2048
  columns(1)%column_id=cfg%tiles(1)%tile_id;columns(1)%template_id=cfg%tiles(1)%template%template_id
  columns(1)%parameter_ref=1_int64;columns(1)%state_handle=1_int64;columns(1)%forcing_handle=1_int64
  columns(1)%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  call backend%initialize(top)
  call fmr_new_b110_committed_state(states(1),columns(1)%column_id,cfg%tiles(1)%initial_state,T0,ok)
  call require(ok,'salt thermal committed state')
  call states(1)%capture_checkpoint(cp,ok)
  call backend%run_trial(columns(1),cfg%tiles(1)%template,cfg%tiles(1)%parameters,states(1), &
       cfg%tiles(1)%base_forcing,cfg%numerical,T0,T1,cp,first,candidate,diag)
  call require(.not.first%completed.and..not.candidate%ready(),'unconfigured matrix salt fails closed')
  policy%enabled=.true.;policy%head_tolerance_cm=.01_real64;policy%water_tolerance_cm=1.e-6_real64
  policy%salt_tolerance_mg_cm2=1.e-7_real64;policy%temperature_tolerance_c=.01_real64
  if(dispersive)then
    policy%transport%enabled=.true.;policy%transport%max_step_day=1.e-6_real64
    policy%transport%max_substeps=100;policy%transport%courant_fraction=.9_real64
  end if
  if(trim(mode)=='resume')then
    call read_restart_file(trim(restart_path),bundle)
    call fmr_restore_committed_restart(bundle,cfg%tiles(1)%parameters%parameter_set_id,columns, &
         [cfg%tiles(1)%template],restored,ok,status)
    call require(ok.and.status==FMR_RESTART_OK,'separate process restart restore')
    call backend%configure_base_salt_temporal_policy(policy,ok)
    call change_boundary()
    call restored(1)%capture_checkpoint(cp,ok)
    call backend%run_trial(columns(1),cfg%tiles(1)%template,cfg%tiles(1)%parameters,restored(1), &
         cfg%tiles(1)%base_forcing,cfg%numerical,T1,T1+1.e-5_real64,cp,continuation,candidate,diag)
    call require(continuation%completed.and.candidate%ready(),'separate process changed forcing continuation')
    call candidate%snapshot(snapshot,ok)
    call write_physical_file(trim(result_path),snapshot)
    print '(a)','PPA_WU05E_FRESH_PROCESS_RESTART=PASS_TEST_ONLY'
    stop
  end if
  cfg%base_salt_temporal_policy=policy
  call backend%configure_base_salt_temporal_policy(policy,ok)
  call require(ok,'joint salt policy')
  oracle=cfg
  do scenario=1,6
    cfg=oracle
    if(scenario>3)then
      deallocate(cfg%tiles(1)%initial_state%salt)
      call fmr_initialize_mobile_salt_profile(cfg%tiles(1)%initial_state,dz,spread(.99_real64,1,numnod),status)
      call require(status==0,'severe matrix salt profile')
    end if
    call fmr_new_b110_committed_state(states(1),columns(1)%column_id,cfg%tiles(1)%initial_state,T0,ok)
    call states(1)%capture_checkpoint(cp,ok)
    bad=cfg
    selector=mod(scenario-1,3)+1
    if(selector==2)bad%tiles(1)%parameters%root_compensation%stressor=ROOT_COMP_SALINITY
    if(selector==3)bad%tiles(1)%parameters%root_compensation%stressor=ROOT_COMP_FROST
    call backend%run_trial(columns(1),bad%tiles(1)%template,bad%tiles(1)%parameters,states(1), &
         bad%tiles(1)%base_forcing,bad%numerical,T0,T1,cp,first,candidate,diag,trace_accepted_water_flux_substeps=.true.)
    print *, 'JOINT ',scenario,first%completed,diag%solver_rejections,diag%temporal_rejections,diag%mass_rejections
    call require(first%completed.and.candidate%ready(),'actual joint candidate')
    obs=backend%observation()
    call require(obs%root_frost_executed.and.obs%root_salinity_executed.and.obs%root_compensation_executed,'joint actual caller')
    potential=bad%tiles(1)%base_forcing%root_potential_sink
    dry=1._real64
    where(potential>0._real64)dry=bad%tiles(1)%base_forcing%root_extraction_sink/potential
    frs=[0._real64,1._real64,0._real64,1._real64]
    raw=bad%tiles(1)%base_forcing%root_extraction_sink*obs%root_salinity_alpha*frs
    losses=0._real64
    do j=1,numnod
      w=sum(1._real64-[dry(j),1._real64,obs%root_salinity_alpha(j),frs(j)])
      if(w>0._real64)losses=losses+(1._real64-[dry(j),1._real64,obs%root_salinity_alpha(j),frs(j)])/w*(potential(j)-raw(j))
    end do
    q=bad%tiles(1)%base_forcing%root_potential_transpiration
    total=sum(raw)/q
    a=total**(losses/(q-sum(raw)))
    if(selector==1)then
      total=min(total/.7_real64,1._real64)
    else
      j=merge(3,4,selector==2);a(j)=min(a(j)/.7_real64,1._real64);total=product(a)
    end if
    if(scenario>3)then
      call require(obs%root_compensation_base_uptake/q<.05_real64.and. &
           obs%root_compensation_base_uptake/q>1.e-14_real64,'actual severe uptake lies in exact-source eligibility domain')
      call require(obs%root_compensation_final_uptake>obs%root_compensation_base_uptake,'actual severe source compensation executes')
      print *, 'PPA_EXACT01_ACTUAL_SEVERE_SELECTOR=',selector
    end if
    call require(abs(obs%root_compensation_final_uptake-q*total)<1.e-14_real64,'independent source joint uptake oracle')
    call require(abs(obs%root_compensation_final_uptake+obs%root_compensation_drought_loss+ &
         obs%root_compensation_oxygen_loss+obs%root_salinity_reduction_total+obs%root_compensation_frost_loss-q)< &
         1.e-14_real64,'joint four-channel loss closure')
    call require(obs%root_salinity_reduction_total>0._real64.and.obs%root_compensation_frost_loss>0._real64,'both stresses apportioned')
    call require(abs(first%mass%residual)<=HARD_MASS_GATE,'joint hard water balance')
    do j=1,size(obs%accepted_water_flux_substeps)
      call require(obs%accepted_water_flux_substeps(j)%root_sink(1)==0._real64.and. &
           obs%accepted_water_flux_substeps(j)%root_sink(3)==0._real64,'frozen nodes never resurrect')
    end do
    call candidate%snapshot(snapshot,ok);call verify_ledger(obs,snapshot)
    call badapp%initialize(bad,status)
    call require(status==FMR_APP_BOOT_OK,'joint actual application initializes')
    call badapp%run_standalone(T0,T1,app_results,status)
    call require(status==FMR_APP_BOOT_OK.and.app_results(1)%committed,'joint actual application commits')
    call require(app_results(1)%actual_transpiration_available,'accepted joint transpiration publishes')
    call require(abs(root_water_amount(obs)-app_results(1)%actual_transpiration_amount)<1.e-18_real64,'one accepted joint root receipt')
    call badapp%close(status)
    call backend%discard_trial_candidate(candidate,diag)
    call states(1)%snapshot(after,ok);call require_same_physical(cfg%tiles(1)%initial_state,after)
  end do
  cfg=oracle
  call fmr_new_b110_committed_state(states(1),columns(1)%column_id,cfg%tiles(1)%initial_state,T0,ok)
  call states(1)%capture_checkpoint(cp,ok)
  ! Invalid hybrid/input profiles reject before publishing accepted transpiration.
  do scenario=1,9
    bad=cfg
    select case(scenario)
    case(1);bad%base_salt_temporal_policy%enabled=.false.
    case(2);bad%tiles(1)%parameters%root_frost_head_budget_cm=0._real64
    case(3);bad%tiles(1)%parameters%frost_bottom%active=.true.
    case(4);bad%tiles(1)%parameters%frost_drainage%active=.true.
    case(5);allocate(bad%tiles(1)%parameters%bartholomeus)
    case(6);bad%tiles(1)%base_forcing%drainage_flux_by_level(1,1)=1.e-4_real64
    case(7);bad%tiles(1)%base_forcing%bottom_flux=1.e-4_real64
    case(8);bad%tiles(1)%base_forcing%subsurface_irrigation_source(1)=1.e-4_real64
    case(9);bad%tiles(1)%parameters%saltslope_cm3_mg=ieee_value(0._real64,ieee_quiet_nan)
    end select
    print *, 'JOINT_INVALID_PROFILE ',scenario
    call backend%configure_base_salt_temporal_policy(bad%base_salt_temporal_policy,ok)
    call backend%run_trial(columns(1),bad%tiles(1)%template,bad%tiles(1)%parameters,states(1), &
         bad%tiles(1)%base_forcing,bad%numerical,T0,T1,cp,replay,other,diag2)
    call require(.not.replay%completed.and..not.other%ready(),'invalid joint backend profile rejects')
    call states(1)%snapshot(after,ok);call require_same_physical(cfg%tiles(1)%initial_state,after)
    call badapp%initialize(bad,status)
    if(status==FMR_APP_BOOT_OK)then
      call badapp%run_standalone(T0,T1,scenario_results,status)
      call require(status/=FMR_APP_BOOT_OK,'invalid joint application execution rejects')
      if(allocated(scenario_results))then
        if(size(scenario_results)>0)call require(.not.scenario_results(1)%committed.and. &
             .not.scenario_results(1)%actual_transpiration_available,'rejected joint transpiration unavailable')
      end if
      call badapp%close(status)
    end if
  end do
  call backend%configure_base_salt_temporal_policy(policy,ok)
  ! Actual all-frozen, warm, and a short real thaw from a shallow subzero state.
  do scenario=1,3
    bad=cfg
    deallocate(bad%tiles(1)%initial_state%soil_temperature)
    allocate(bad%tiles(1)%initial_state%soil_temperature)
    k=merge(-1._real64,1._real64,scenario==1)
    if(scenario==3)k=-1.e-5_real64
    call initialize_soil_temperature_state(spread(k,1,numnod),bad%tiles(1)%initial_state%soil_temperature,status)
    bad%tiles(1)%base_forcing%soil_temperature%prescribed_surface_temperature_c=k
    if(scenario==3)bad%tiles(1)%base_forcing%soil_temperature%prescribed_surface_temperature_c=5._real64
    call fmr_new_b110_committed_state(states(1),columns(1)%column_id,bad%tiles(1)%initial_state,T0,ok)
    call states(1)%capture_checkpoint(cp,ok)
    call backend%run_trial(columns(1),bad%tiles(1)%template,bad%tiles(1)%parameters,states(1), &
         bad%tiles(1)%base_forcing,bad%numerical,T0,T1,cp,replay,other,diag2,trace_accepted_water_flux_substeps=.true.)
    print *, 'JOINT_THERMAL_REGIME ',scenario,replay%completed,diag2%temporal_rejections,diag2%accepted_substeps
    call require(replay%completed.and.other%ready(),'actual joint thermal regime completes')
    obs2=backend%observation()
    if(scenario==1)then
      call require(root_water_amount(obs2)==0._real64,'all-frozen accepted root water is zero')
      do j=1,size(obs2%accepted_water_flux_substeps)
        call require(all(obs2%accepted_water_flux_substeps(j)%salt_receipt%root_solute_uptake_mg_cm2==0._real64), &
             'all-frozen accepted root salt is zero')
      end do
    else
      call require(root_water_amount(obs2)>0._real64,'warm/thawed accepted roots extract water')
      call require(obs2%root_compensation_final_uptake>0._real64,'warm/thawed joint response positive')
      if(scenario==2)call require(obs2%root_compensation_frost_loss==0._real64,'warm frost factor identity')
      if(scenario==3)call require(all(obs2%accepted_water_flux_substeps(1)%root_sink==0._real64), &
           'real thaw starts with zero frozen root extraction')
    end if
    call backend%discard_trial_candidate(other,diag2)
    call states(1)%snapshot(after,ok);call require_same_physical(bad%tiles(1)%initial_state,after)
  end do
  call fmr_new_b110_committed_state(states(1),columns(1)%column_id,cfg%tiles(1)%initial_state,T0,ok)
  call states(1)%capture_checkpoint(cp,ok)
  ! Independently activate each temporal owner while the other is permissive.
  do scenario=1,2
    bad=cfg;tight=policy
    bad%numerical%transaction%max_retries=0
    if(scenario==1)then
      tight%salt_tolerance_mg_cm2=1.e-25_real64
      bad%tiles(1)%parameters%root_frost_head_budget_cm=1._real64
      bad%tiles(1)%parameters%root_frost_temperature_budget_c=1._real64
    else
      tight%head_tolerance_cm=1._real64;tight%water_tolerance_cm=1._real64
      tight%salt_tolerance_mg_cm2=1._real64;tight%temperature_tolerance_c=1._real64
      bad%tiles(1)%parameters%root_frost_temperature_budget_c=1.e-25_real64
    end if
    call backend%configure_base_salt_temporal_policy(tight,ok)
    call backend%run_trial(columns(1),bad%tiles(1)%template,bad%tiles(1)%parameters,states(1), &
         bad%tiles(1)%base_forcing,bad%numerical,T0,T1,cp,replay,other,diag2)
    print *, 'JOINT_REJECT ',scenario,replay%completed,diag2%solver_rejections,diag2%temporal_rejections
    call require(.not.replay%completed.and..not.other%ready().and.diag2%temporal_rejections>0.and. &
         diag2%solver_rejections==0,'both temporal owners independently reject')
    call states(1)%snapshot(after,ok);call require_same_physical(cfg%tiles(1)%initial_state,after)
  end do
  tight=policy;tight%salt_tolerance_mg_cm2=1.e-13_real64
  call backend%configure_base_salt_temporal_policy(tight,ok)
  bad=cfg;bad%numerical%transaction%max_retries=20;bad%numerical%max_committed_substeps=2048
  call backend%run_trial(columns(1),bad%tiles(1)%template,bad%tiles(1)%parameters,states(1), &
       bad%tiles(1)%base_forcing,bad%numerical,T0,T1,cp,replay,other,diag2,trace_accepted_water_flux_substeps=.true.)
  print *, 'JOINT_ADAPTIVE ',replay%completed,diag2%temporal_rejections,diag2%accepted_substeps
  call require(replay%completed.and.other%ready().and.diag2%temporal_rejections>0,'attainable joint adaptive recovery')
  obs2=backend%observation();call other%snapshot(after,ok);call verify_ledger(obs2,after)
  call backend%discard_trial_candidate(other,diag2)
  call backend%configure_base_salt_temporal_policy(policy,ok)
  call backend%run_trial(columns(1),cfg%tiles(1)%template,cfg%tiles(1)%parameters,states(1), &
       cfg%tiles(1)%base_forcing,cfg%numerical,T0,T1,cp,first,candidate,diag,trace_accepted_water_flux_substeps=.true.)
  call require(first%completed.and.candidate%ready(),'joint final candidate')
  call backend%commit_trial_candidate(states(1),candidate,diag,ok,status)
  call require(ok,'joint final commit')
  call fmr_export_committed_restart(columns,[cfg%tiles(1)%template],states, &
       cfg%tiles(1)%parameters%parameter_set_id,bundle,ok,status)
  call require(ok.and.status==FMR_RESTART_OK,'salt thermal restart export')
  if(trim(mode)=='write')call write_restart_file(trim(restart_path),bundle)
  call fmr_restore_committed_restart(bundle,cfg%tiles(1)%parameters%parameter_set_id,columns, &
       [cfg%tiles(1)%template],restored,ok,status)
  call require(ok.and.status==FMR_RESTART_OK,'salt thermal restart restore')
  call resumed%initialize(top)
  call resumed%configure_base_salt_temporal_policy(policy,ok)
  call change_boundary()
  call states(1)%capture_checkpoint(cp,ok);call restored(1)%capture_checkpoint(cp2,ok)
  call backend%run_trial(columns(1),cfg%tiles(1)%template,cfg%tiles(1)%parameters,states(1), &
       cfg%tiles(1)%base_forcing,cfg%numerical,T1,T1+1.e-5_real64,cp,continuation,candidate,diag)
  call resumed%run_trial(columns(1),cfg%tiles(1)%template,cfg%tiles(1)%parameters,restored(1), &
       cfg%tiles(1)%base_forcing,cfg%numerical,T1,T1+1.e-5_real64,cp2,restart,other,diag2)
  call require(continuation%completed.and.restart%completed,'changed boundary fresh backend continuation')
  call require(same_bits(continuation%mass%total_out,restart%mass%total_out).and. &
       same_bits(continuation%mass%storage_end,restart%mass%storage_end),'restart water identity')
  call candidate%snapshot(snapshot,ok);call other%snapshot(after,ok)
  if(trim(mode)=='write')call write_physical_file(trim(result_path),snapshot)
  select type(p=>snapshot)
  type is(fmr_b110_physical_state_t)
    select type(q=>after)
    type is(fmr_b110_physical_state_t)
      call require(all(p%salt%mass_mg_cm2==q%salt%mass_mg_cm2),'restart salt identity')
    end select
  end select
  call require_same_physical(snapshot,after)
  if(dispersive)print '(a)','PPA_SALFRO01_JOINT_TRANSPORT_ACTUAL_LIFECYCLE=PASS_TEST_ONLY'
  if(walsum)print '(a)','PPA_SALFRO01_WALSUM_SALINITY=PASS_TEST_ONLY'
  print '(a)','PPA_SALFRO01_MATRIX_MIXED_STRESS_LIFECYCLE=PASS_TEST_ONLY'
contains
  subroutine verify_ledger(observation,physical)
    type(fmr_serialized_physical_observation_t),intent(in)::observation
    class(transaction_state_t),intent(in)::physical
    real(real64)::net,root_total,cursor,dt
    integer::j
    call require(observation%accepted_water_flux_trace_available,'accepted salt trace')
    net=0;root_total=0;cursor=T0
    do j=1,size(observation%accepted_water_flux_substeps)
      associate(s=>observation%accepted_water_flux_substeps(j))
        call require(s%t0==cursor.and.s%t1>s%t0,'accepted trace contiguous')
        call require(allocated(s%salt_receipt),'matrix salt receipt')
        dt=s%t1-s%t0
        associate(r=>s%salt_receipt)
          call require(abs(r%closure_error_mg_cm2)<1.e-12_real64,'salt substep hard balance')
          call require(size(r%qdra_signed_out_mg_cm2)==2.and.all(r%qdra_signed_out_mg_cm2==0._real64),'joint no-drain receipt')
          root_total=root_total+sum(r%root_solute_uptake_mg_cm2)
          net=net+r%matrix_top_input_mg_cm2-r%matrix_top_output_mg_cm2+ &
               r%matrix_bottom_input_mg_cm2-r%matrix_bottom_output_mg_cm2- &
               sum(r%root_solute_uptake_mg_cm2)-sum(r%qdra_signed_out_mg_cm2)
        end associate
        cursor=s%t1
      end associate
    end do
    call require(cursor==T1.and.root_total>0._real64,'complete accepted root salt removal')
    select type(p=>physical)
    type is(fmr_b110_physical_state_t)
      call require(abs(sum(p%salt%mass_mg_cm2)-sum(cfg%tiles(1)%initial_state%salt%mass_mg_cm2)-net)< &
           1.e-12_real64,'independent interval salt ledger')
    class default
      error stop 'salt ledger family'
    end select
  end subroutine
  real(real64) function root_water_amount(observation)result(amount)
    type(fmr_serialized_physical_observation_t),intent(in)::observation
    integer::j
    amount=0._real64
    do j=1,size(observation%accepted_water_flux_substeps)
      associate(s=>observation%accepted_water_flux_substeps(j))
        amount=amount+sum(s%root_sink)*(s%t1-s%t0)
      end associate
    end do
  end function
  subroutine require_same_physical(a,b)
    class(transaction_state_t),intent(in)::a,b
    type(soil_temperature_restart_payload_t)::ta,tb
    integer::s
    select type(p=>a)
    type is(fmr_b110_physical_state_t)
      select type(q=>b)
      type is(fmr_b110_physical_state_t)
        call require(all(transfer(p%pressure_head,[0_int64],size(p%pressure_head))== &
             transfer(q%pressure_head,[0_int64],size(q%pressure_head))).and. &
             all(transfer(p%water_content,[0_int64],size(p%water_content))== &
             transfer(q%water_content,[0_int64],size(q%water_content))).and. &
             p%ponding_depth==q%ponding_depth.and.p%groundwater_level==q%groundwater_level,'hydraulic state bitwise identity')
        call require(all(p%salt%mass_mg_cm2==q%salt%mass_mg_cm2).and. &
             p%salt%cdrain_source_id==q%salt%cdrain_source_id.and. &
             p%salt%cdrain_revision==q%salt%cdrain_revision,'salt state exact identity')
        call export_soil_temperature_restart(p%soil_temperature,ta,s)
        call require(s==SOIL_TEMP_OK,'first thermal snapshot')
        call export_soil_temperature_restart(q%soil_temperature,tb,s)
        call require(s==SOIL_TEMP_OK.and.all(ta%temperature_c==tb%temperature_c),'temperature state exact identity')
      class default
        error stop 'second physical family'
      end select
    class default
      error stop 'first physical family'
    end select
  end subroutine
  subroutine change_boundary()
    cfg%tiles(1)%base_forcing%soil_temperature%prescribed_surface_temperature_c=5._real64
    cfg%tiles(1)%base_forcing%soil_salt_boundary%matrix_top_mg_cm3=.8_real64
    cfg%tiles(1)%base_forcing%soil_salt_boundary%revision=1_int64
    cfg%tiles(1)%base_forcing%c_drain_salt%revision=1_int64
    if(walsum)then
      cfg%tiles(1)%base_forcing%root_walsum_geometry%current_root_depth_cm=2._real64
      cfg%tiles(1)%base_forcing%root_walsum_geometry%critical_root_zone_depth_cm=1._real64
    end if
  end subroutine
  ! Test-only bounded stream encoding of the actual decoded restart contract.
  ! This is deliberately not a public production restart file format.
  subroutine write_restart_file(path,b)
    character(*),intent(in)::path
    type(fmr_committed_restart_bundle_t),intent(in)::b
    integer::u
    call require(size(b%records)==1,'one serialized restart record')
    open(newunit=u,file=path,access='stream',form='unformatted',status='replace')
    write(u)b%schema_version,b%parameter_set_identity
    associate(r=>b%records(1))
      write(u)r%schema_version,r%kernel_schema_version,r%column_id,r%parameter_ref,r%forcing_handle, &
           r%template_identity,r%lineage_id,r%revision,r%committed_time,r%time_bound
      call write_physical(u,r%physical_state)
    end associate
    close(u)
  end subroutine
  subroutine read_restart_file(path,b)
    character(*),intent(in)::path
    type(fmr_committed_restart_bundle_t),intent(out)::b
    type(soil_temperature_restart_payload_t)::thermal
    integer::u,s,n
    open(newunit=u,file=path,access='stream',form='unformatted',status='old')
    read(u)b%schema_version,b%parameter_set_identity
    allocate(b%records(1))
    associate(r=>b%records(1))
      read(u)r%schema_version,r%kernel_schema_version,r%column_id,r%parameter_ref,r%forcing_handle, &
           r%template_identity,r%lineage_id,r%revision,r%committed_time,r%time_bound
      allocate(fmr_b110_physical_state_t::r%physical_state)
      select type(p=>r%physical_state)
      type is(fmr_b110_physical_state_t)
        read(u)n
        call require(n==numnod,'restart node count')
        p%active_nodes=n
        allocate(p%pressure_head(n),p%water_content(n),p%salt,p%soil_temperature,thermal%temperature_c(n))
        allocate(p%salt%mass_mg_cm2(n))
        read(u)p%pressure_head,p%water_content,p%ponding_depth,p%groundwater_level, &
             p%salt%mass_mg_cm2,p%salt%cdrain_source_id,p%salt%cdrain_revision, &
             thermal%schema_version,thermal%temperature_c
        call reconstruct_soil_temperature_restart(thermal,p%soil_temperature,s)
        call require(s==SOIL_TEMP_OK,'restart thermal payload reconstructed')
      end select
    end associate
    close(u)
  end subroutine
  subroutine write_physical_file(path,p)
    character(*),intent(in)::path
    class(transaction_state_t),intent(in)::p
    integer::u
    open(newunit=u,file=path,access='stream',form='unformatted',status='replace')
    call write_physical(u,p)
    close(u)
  end subroutine
  subroutine write_physical(u,physical)
    integer,intent(in)::u
    class(transaction_state_t),intent(in)::physical
    type(soil_temperature_restart_payload_t)::thermal
    integer::s
    select type(p=>physical)
    type is(fmr_b110_physical_state_t)
      call require(.not.allocated(p%macropore).and..not.allocated(p%snow),'bounded serialized state')
      call require(allocated(p%salt).and.allocated(p%soil_temperature),'serialized salt thermal owners')
      call export_soil_temperature_restart(p%soil_temperature,thermal,s)
      call require(s==SOIL_TEMP_OK,'restart thermal payload export')
      write(u)p%active_nodes,p%pressure_head,p%water_content,p%ponding_depth,p%groundwater_level, &
           p%salt%mass_mg_cm2,p%salt%cdrain_source_id,p%salt%cdrain_revision, &
           thermal%schema_version,thermal%temperature_c
    class default
      error stop 'serialized state family'
    end select
  end subroutine
  include 'wu05e_mixed_fixture.inc'
end program
