program test_root_growth_transaction
 use, intrinsic :: iso_fortran_env, only: real64,int64
 use mod_transaction_reference, only: transaction_state_t,TX_TEMPORAL_MODEL_CERTIFICATE
 use mod_kernel_transactions
 use mod_canonical_contracts
 use mod_fwof34_test_model
 use mod_fmr_wofost_accepted_window_lineage
 use mod_fmr_wofost_crop_transaction
 use mod_fmr_biomass_root_uptake_input
 use mod_crop_root_uptake_input_contract,only:crop_root_uptake_input_t
 use mod_fmr_biomass_root_depth_binding
 use mod_fmr_root_depth_rate_daily_binding
 use mod_crop_root_depth_biomass
 use mod_crop_root_depth_rate_owner
 use mod_wofost_rate_table
 use mod_wofost_rate_parameters
 use mod_wofost_crop_owner_state
 use mod_wofost_potential_shadow_state
 use mod_wofost_one_day_structural_evolution
 implicit none
 type(wofost_rate_scalar_parameters_t)::s
 type(wofost_rate_parameter_tables_t)::t
 type(wofost_rate_parameter_bundle_t)::p
 type(wofost_crop_owner_state_t)::seed,actual,restored_owner
 type(wofost_potential_shadow_state_t)::shadow
 type(wofost_one_day_forcing_t)::forcing
 type(wofost_one_day_update_parameters_t)::u
 type(fmr_wofost_crop_transaction_state_t)::initial,restored,no_shadow
 type(fmr_wofost_crop_transaction_persistence_t)::pv,rv
 type(fmr_wofost_crop_transaction_parameters_t)::cp
 type(fmr_wofost_crop_event_forcing_t)::event
 type(fmr_wofost_crop_transaction_model_t),target::cm
 type(kernel_executor_t)::ck,wk
 type(kernel_committed_state_t)::crop,water
 type(kernel_checkpoint_t)::checkpoint,water_checkpoint
 type(kernel_candidate_state_t)::candidate,duplicate
 type(kernel_result_t)::result
 type(kernel_diagnostics_t)::diag
 type(canonical_numerical_config_t)::config,wconfig
 type(fwof34_model_t),target::wm
 type(fwof34_parameters_t)::wp
 type(fwof34_forcing_t)::wf
 type(fmr_wofost_accepted_window_t)::window
 type(fmr_wofost_trial_contribution_t)::trial
 type(fmr_wofost_accepted_interval_certificate_t)::cert
 type(wofost_accepted_window_aggregates_t)::agg
 type(fmr_wofost_crop_event_identity_t)::identity
 type(fmr_wofost_crop_event_token_t)::token
 type(fmr_wofost_root_growth_carrier_t)::growth
 type(crop_root_uptake_input_t)::root_input
 type(wofost_rate_table_t)::depth,density
 type(crop_root_depth_biomass_result_t)::rd,rdrestored
 type(crop_root_depth_rate_parameters_t)::rp
 type(crop_root_depth_rate_state_t)::r0,rnext
 type(crop_root_depth_rate_daily_forcing_t)::rf
 type(crop_root_depth_rate_diagnostics_t)::rdiag
 class(transaction_state_t),allocatable::physical
 real(real64)::oxygen,expected,death,clock
 integer::status,commit_status,profile
 logical::ok,available,did_commit,gated,enabled
 character(30)::arg
 call get_command_argument(1,arg);read(arg,*)profile
 enabled=profile/=3
 oxygen=.2_real64
 if(profile==1)oxygen=.4_real64
 if(profile==2)oxygen=.8_real64
 gated=enabled.and.oxygen<.4_real64
 call configure_parameters(s,t)
 call construct_wofost_rate_parameter_bundle(s,t,p,status);call require(status==0,'rate bundle')
 seed%crop_emerged=.true.;seed%development_stage=.25_real64
 allocate(seed%biomass,seed%evolution_continuation)
 seed%biomass%root_biomass=20d0;seed%biomass%stem_biomass=20d0;seed%biomass%storage_biomass=0d0
 seed%biomass%exponential_leaf_area_index=1d0;seed%biomass%leaf_biomass=[20d0]
 seed%biomass%specific_leaf_area=[.02d0];seed%biomass%leaf_age=[1d0]
 seed%evolution_continuation%temperature_sum=25d0;seed%evolution_continuation%minimum_temperature_history=10d0
 seed%evolution_continuation%minimum_temperature_history_count=7;seed%evolution_continuation%anthesis_reached=.false.
 call require(seed%validate()==0,'seed owner')
 forcing%minimum_temperature=10d0;forcing%average_temperature=20d0;forcing%daytime_average_temperature=20d0
 forcing%global_radiation=1d6;forcing%daylength_hours=12d0;forcing%photoperiodic_daylength_hours=12d0
 forcing%sinld=.5d0;forcing%cosld=.4d0;forcing%diffuse_perpendicular_radiation=100d0
 forcing%daily_sine_solar_elevation_integral=10000d0;forcing%co2_efficiency_factor=1d0;forcing%co2_amax_factor=1d0
 u%development_stage_end=2d0;u%leaf_lifespan=100d0
 call initialize_fmr_wofost_crop_transaction_state(seed,initial,status,enable_potential_shadow=.true.)
 call require(status==0,'initial actual plus potential owner')
 call roundtrip(initial,restored)
 call restored%snapshot_root_growth(growth,available);call require(.not.available,'no growth receipt before event')
 allocate(fmr_wofost_crop_transaction_state_t::physical)
 select type(physical)
 type is(fmr_wofost_crop_transaction_state_t)
 physical=restored
 end select
 call crop%initialize(33001_int64,physical,ok,100d0);call require(ok,'crop carrier')
 deallocate(physical);allocate(fwof34_state_t::physical)
 select type(physical)
 type is(fwof34_state_t)
 physical%water=1d0
 end select
 call water%initialize(33002_int64,physical,ok,100d0);call require(ok,'test water carrier')
 config%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
 config%transaction%temporal_tolerance=0d0;config%transaction%mass_tolerance=0d0
 config%transaction%max_retries=0;config%max_committed_substeps=1;config%progress_tolerance=0d0
 wconfig%transaction%temporal_tolerance=1d0;wconfig%transaction%mass_tolerance=1d-12
 wconfig%transaction%max_retries=2;wconfig%max_committed_substeps=8
 call ck%bind_model(cm);call wk%bind_model(wm)
 call water%capture_checkpoint(water_checkpoint,ok);call require(ok,'water checkpoint')
 call open_wofost_accepted_window(water_checkpoint,101d0,window,status);call require(status==0,'window open')
 ! Rejected oxygen would permit growth; it must never enter the accepted window.
 call begin_wofost_trial_contribution(water_checkpoint,101d0,trial,status)
 call accumulate_wofost_trial_process_rate(trial,100d0,101d0,1d0,1d0,status,deepest_root_oxygen_factor=.95d0)
 call discard_wofost_trial_contribution(trial)
 call require(window%interval_count()==0,'rejected oxygen discarded')
 call begin_wofost_trial_contribution(water_checkpoint,101d0,trial,status)
 if(profile==4)then
 call accumulate_wofost_trial_process_rate(trial,100d0,101d0,1d0,1d0,status)
 else
 call accumulate_wofost_trial_process_rate(trial,100d0,100.25d0,1d0,1d0,status,deepest_root_oxygen_factor=oxygen)
 call accumulate_wofost_trial_process_rate(trial,100.25d0,101d0,1d0,1d0,status,deepest_root_oxygen_factor=oxygen)
 end if
 call require(status==0,'accepted oxygen rates')
 call wk%advance_interval(wp,water,wf,wconfig,100d0,101d0,result,candidate,diag,water_checkpoint)
 call require(result%completed,'test water positive interval completes')
 call wk%commit_candidate(water,candidate,diag,did_commit,commit_status);call require(did_commit,'test water commit')
 call certify_fkt_accepted_interval(water_checkpoint,water,cert,status);call require(status==0,'real accepted revision certificate')
 call admit_wofost_accepted_trial(window,cert,trial,status);call require(status==0,'accepted oxygen admission')
 call prepare_wofost_crop_event_delivery(window,agg,token,available,status);call require(status==0.and.available,'daily event')
 if(profile/=4)call require(abs(agg%deepest_root_oxygen_factor_integral-oxygen)<1d-14,'duration weighted oxygen')
 call identify_wofost_crop_event(token,identity,status);call require(status==0,'public event identity')
 call prepare_fmr_wofost_crop_event_forcing(window,forcing,event,status);call require(status==0,'crop event')
 call construct_fmr_wofost_crop_transaction_parameters(p,u,0d0,0d0,cp,status,enable_potential_shadow=.true., &
 enable_anaerobic_root_growth_gate=enabled,aeration_critical_factor=.4d0)
 call require(status==0,'crop parameter gate')
 call crop%capture_checkpoint(checkpoint,ok);call require(ok,'crop checkpoint')
 call ck%advance_interval(cp,crop,event,config,100d0,101d0,result,candidate,diag,checkpoint)
 if(profile==4)then
 call require(.not.result%completed.and..not.candidate%ready(),'missing oxygen refuses crop event')
 call require(crop%current_revision()==0_int64,'missing oxygen no publication')
 print '(A)','ROOT_GROWTH_MISSING_OXYGEN_FAIL_CLOSED=PASS'
 stop
 end if
 call require(result%completed.and.candidate%ready(),'crop trial')
 call crop%snapshot(physical,ok)
 select type(physical)
 type is(fmr_wofost_crop_transaction_state_t)
 call physical%snapshot_owner(actual,available)
 call require(available.and.actual%biomass%root_biomass==20d0,'precommit primary unchanged')
 call physical%snapshot_root_growth(growth,available);call require(.not.available,'precommit carrier absent')
 end select
 call ck%rollback_candidate(candidate,diag);call require(.not.candidate%ready(),'candidate discarded')
 call ck%advance_interval(cp,crop,event,config,100d0,101d0,result,candidate,diag,checkpoint)
 call require(result%completed,'retry same checkpoint')
 call ck%commit_candidate(crop,candidate,diag,did_commit,commit_status)
 call require(did_commit.and.crop%current_revision()==1_int64,'single crop publication')
 call crop%snapshot(physical,ok)
 select type(physical)
 type is(fmr_wofost_crop_transaction_state_t)
 call physical%snapshot_owner(actual,available);call require(available,'actual snapshot')
 call physical%snapshot_potential_shadow(shadow,available);call require(available,'potential snapshot')
 call physical%snapshot_root_growth(growth,available);call require(available,'growth carrier')
 death=20d0*.01d0
 if(gated)then
 call require(growth%actual_gross_root_growth==0d0,'anaerobic actual GRRT exactly zero')
 call require(abs(actual%biomass%root_biomass-(20d0-death))<1d-12,'source WRT loses DRRT while GRRT zero')
 else
 call require(growth%actual_gross_root_growth>0d0,'boundary or OFF actual growth positive')
 call require(abs(actual%biomass%root_biomass-(20d0+growth%actual_gross_root_growth-death))<1d-12,'source root mass update')
 end if
 call require(growth%potential_gross_root_growth>0d0.and.shadow%root_biomass()>20d0,'potential remains independent')
 call make([0d0,100d0],[0d0,100d0],depth)
 call bind_committed_biomass_root_depth(physical,depth,100d0,100d0,rd,status)
 call require(status==0,'SWRD3 real owner binding')
 call make([0d0,1d0],[1d0,1d0],density)
 call bind_committed_biomass_root_uptake_input(physical,depth,density,100d0,100d0, &
 [-10d0,-20d0,-30d0,-100d0],root_input,status)
 call require(status==0.and.root_input%crop_emerged.and.root_input%rooted_nodes>0,'real biomass root uptake adapter')
 call require(root_input%cumulative_root_fraction(1)==0d0.and. &
 root_input%cumulative_root_fraction(root_input%rooted_nodes+1)==1d0,'biomass density normalized')
 call bind_committed_biomass_root_uptake_input(physical,depth,density,100d0,100d0, &
 [-10d0,-5d0,-30d0,-100d0],root_input,status)
 call require(status/=0.and..not.allocated(root_input%cumulative_root_fraction).and. &
 root_input%rooted_nodes==0,'invalid geometry clears output without touching crop')
 call initialize_fmr_wofost_crop_transaction_state(seed,no_shadow,status)
 call require(status==0,'existing no-shadow owner')
 call bind_committed_biomass_root_uptake_input(no_shadow,depth,density,100d0,100d0, &
 [-10d0,-20d0,-30d0,-100d0],root_input,status)
 call require(status/=0.and.root_input%rooted_nodes==0,'active biomass route requires potential owner')
 call bind_committed_biomass_root_uptake_input(physical,depth,density,100d0,100d0, &
 [-10d0,-20d0,-30d0,-100d0],root_input,status)
 call require(status==0.and.root_input%rooted_nodes>0,'valid binding after failed request ABA')
 print '(A,4(ES26.17,1X))','ROOT_OBSERVATION ',actual%biomass%root_biomass,shadow%root_biomass(), &
 growth%actual_gross_root_growth,growth%potential_gross_root_growth
 call require(abs(rd%actual_root_depth_cm-actual%biomass%root_biomass)<1d-12,'literal linear AFGEN WRT depth')
 call require(abs(rd%potential_root_depth_cm-shadow%root_biomass())<1d-12,'literal potential AFGEN')
 call bind_accepted_crop_event_to_root_depth_rate(physical,agg,rf,status);call require(status==0,'SWRD2 accepted carrier binding')
 rp%initial_root_depth_cm=10d0;rp%maximum_root_depth_cm=100d0;rp%maximum_daily_extension_cm=5d0
 rp%anaerobic_extension_gate_enabled=enabled;rp%aeration_critical_factor=.4d0
 call initialize_crop_root_depth_rate_state(rp,r0,status);call require(status==0,'SWRD2 seed')
 call evaluate_crop_root_depth_rate_candidate(rp,r0,rf,rnext,rdiag,status);call require(status==0,'SWRD2 accepted composition')
 expected=15d0;if(gated)expected=10d0
 call require(abs(rnext%actual_root_depth_cm-expected)<1d-12.and.rnext%potential_root_depth_cm==15d0,'SWRD2 actual/potential gate')
 call roundtrip(physical,restored)
 call require(restored%consumed_event(identity),'restart retains consumed oxygen identity')
 call bind_committed_biomass_root_depth(restored,depth,100d0,100d0,rdrestored,status)
 call require(status==0.and.rdrestored%actual_root_depth_cm==rd%actual_root_depth_cm.and. &
 rdrestored%potential_root_depth_cm==rd%potential_root_depth_cm,'postevent restart identical depth')
 call restored%snapshot_owner(restored_owner,available)
 call require(available.and.restored_owner%biomass%root_biomass==actual%biomass%root_biomass,'postevent actual exact')
 class default
 call require(.false.,'committed type')
 end select
 call ck%advance_interval(cp,crop,event,config,101d0,102d0,result,duplicate,diag)
 call require(.not.result%completed.and..not.duplicate%ready(),'consumed event replay refused')
 call crop%current_time(clock,ok);call require(ok.and.clock==101d0.and.crop%current_revision()==1_int64,'replay clock revision unchanged')
 print '(A,I0,A)','ROOT_GROWTH_SWRD2_SWRD3_OXYGEN_RESTART_PROFILE_',profile,'=PASS'
contains
 subroutine roundtrip(state,next)
 type(fmr_wofost_crop_transaction_state_t),intent(in)::state
 type(fmr_wofost_crop_transaction_state_t),intent(out)::next
 call export_fmr_wofost_crop_transaction_persistence(state,pv,ok,status);call require(ok.and.status==0,'export crop')
 call reconstruct_fmr_wofost_crop_transaction_from_persistence(pv,next,ok,status);call require(ok.and.status==0,'restore crop')
 call export_fmr_wofost_crop_transaction_persistence(next,rv,ok,status);call require(ok.and.status==0,'restored export')
 call require(pv%root_growth_carrier_present.eqv.rv%root_growth_carrier_present,'restart growth presence')
 if(pv%root_growth_carrier_present)call require( &
 pv%root_growth_carrier%actual_gross_root_growth==rv%root_growth_carrier%actual_gross_root_growth.and. &
 pv%root_growth_carrier%potential_gross_root_growth==rv%root_growth_carrier%potential_gross_root_growth,'restart carrier exact')
 end subroutine
 subroutine require(condition,label)
 logical,intent(in)::condition
 character(*),intent(in)::label
 if(.not.condition)then
 print '(A)','FAIL '//label
 error stop 1
 end if
 end subroutine
  subroutine configure_parameters(s,t)
    type(wofost_rate_scalar_parameters_t), intent(out) :: s
    type(wofost_rate_parameter_tables_t), intent(out) :: t
    s%development_daylength_mode=0
    s%vegetative_temperature_sum_required=100.0_real64
    s%generative_temperature_sum_required=200.0_real64
    s%diffuse_extinction_coefficient=0.5_real64
    s%initial_light_use_efficiency=0.4_real64
    s%co2_to_dry_matter_fraction=0.4_real64
    s%attainable_yield_multiplier=1.0_real64
    s%conversion_efficiency_root=1.0_real64
    s%conversion_efficiency_stem=1.0_real64
    s%conversion_efficiency_leaf=1.0_real64
    s%conversion_efficiency_storage=1.0_real64
    s%respiration_temperature_q10=2.0_real64
    s%maintenance_respiration_root=0.0_real64
    s%maintenance_respiration_leaf=0.0_real64
    s%maintenance_respiration_stem=0.0_real64
    s%maintenance_respiration_storage=0.0_real64
    s%maximum_leaf_relative_death_rate=0.0_real64
    s%leaf_age_base_temperature=0.0_real64
    s%maximum_relative_lai_growth_rate=0.01_real64

    call make([0.0_real64,40.0_real64],[0.0_real64,40.0_real64],t%temperature_sum_increment)
    call make([0.0_real64,2.0_real64],[20.0_real64,20.0_real64],t%maximum_assimilation)
    call make([0.0_real64,40.0_real64],[1.0_real64,1.0_real64],t%daytime_temperature_factor)
    call make([-20.0_real64,20.0_real64],[1.0_real64,1.0_real64],t%minimum_temperature_factor)
    call make([0.0_real64,2.0_real64],[1.0_real64,1.0_real64],t%maintenance_respiration_factor)
    call make([0.0_real64,2.0_real64],[0.5_real64,0.5_real64],t%root_partition_fraction)
    call make([0.0_real64,2.0_real64],[0.5_real64,0.5_real64],t%leaf_partition_fraction)
    call make([0.0_real64,2.0_real64],[0.5_real64,0.5_real64],t%stem_partition_fraction)
    call make([0.0_real64,2.0_real64],[0.0_real64,0.0_real64],t%storage_partition_fraction)
    call make([0.0_real64,2.0_real64],[0.01_real64,0.01_real64],t%relative_root_death_rate)
    call make([0.0_real64,2.0_real64],[0.0_real64,0.0_real64],t%relative_stem_death_rate)
    call make([0.0_real64,2.0_real64],[0.02_real64,0.02_real64],t%specific_leaf_area)
  end subroutine configure_parameters

  subroutine make(x,y,table)
    real(real64), intent(in) :: x(:),y(:)
    type(wofost_rate_table_t), intent(out) :: table
    integer :: rc
    call construct_wofost_rate_table(x,y,table,rc)
    if(rc/=WOFOST_RATE_TABLE_OK) error stop 99
  end subroutine make
end program
