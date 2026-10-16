program test_harvest_joint
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_fmr_runtime_core
 use mod_fmr_serialized_reference_backend
 use mod_fmr_production_application_bootstrap
 use mod_kernel_transactions
 use mod_fixed_flux_top_boundary_provider
 use mod_b110_default_mvg_provider
 use MOD_grid,only:numnod,z,dz,disnod
 use mod_transaction_reference,only:transaction_state_t,TX_TEMPORAL_MODEL_CERTIFICATE
 use mod_b111_soil_n_mineral_owner
 use mod_b111_soil_n_reactive_owner
 use mod_soil_n_pool_state
 use mod_b111_soil_n_addition
 use mod_crop_soil_n_material_day
 use mod_fmr_crop_soil_n_material_application
 use mod_crop_soil_n_day
 use mod_crop_soil_n_configuration
 use mod_wofost81_crop_owner_state
 use mod_wofost81_n_owner_state,only:initialize_wofost81_n_owner_state,WOFOST81_N_OWNER_OK
 use mod_wofost_one_day_structural_evolution
 use mod_fmr_crop_soil_n_joint_application
 use mod_crop_soil_n_joint_restart_file
 use mod_fmr_b111_mineral_route,only:aggregate_mineral_trace,mineral_daily_carrier_t
 use mod_soil_n_day_environment
 use mod_crop_senescence_residue
 use mod_crop_soil_n_senescence_day
 use mod_fmr_crop_soil_n_senescence_application
 implicit none
 real(real64),parameter::T0=0d0,T1=1d0,HARD_MASS_GATE=1d-10
 type(fmr_production_application_config_t)::cfg
 type(fmr_serialized_reference_backend_t)::backend,second
 type(fixed_flux_top_boundary_provider_t),target::top
 type(fmr_logical_column_t)::column
 type(kernel_committed_state_t)::water,other_water,initial_water
 type(reactive_state_t)::soil,initial_soil,after_soil
 type(crop_soil_state_t)::state,other_state,initial_state
 type(crop_soil_n_joint_restart_t)::payload
 type(crop_soil_harvest_receipt_t)::harvest_result
 type(senescence_joint_result_t)::result
 type(soil_n_material_input_t)::items(2),bad_items(2)
 type(b111_soil_n_split_parameters_t)::split
 type(crop_senescence_policy_t)::policy,bad_policy
 type(crop_residue_pending_t)::pending
 logical::has_pending
 type(soil_n_day_environment_t)::env,bad_env
 type(reactive_parameters_t)::oracle_p
 type(reactive_parameters_t)::sp,bad_sp
 type(crop_n_configuration_t)::cp,bad_cp
 type(wofost81_crop_owner_state_t)::crop,after_crop
 type(wofost_one_day_forcing_t)::weather,bad_weather
 type(soil_n_pool_state_t)::pools,s
 type(fmr_b110_physical_forcing_t)::invalid
 real(real64),allocatable::old_crop(:),actual_crop(:)
 real(real64)::k,time,theta
 integer(int64)::revision
 integer::status
 logical::ok
 character(512)::mode,path,endpoint
 call get_command_argument(1,mode);call get_command_argument(2,path);call get_command_argument(3,endpoint)
 policy%application_age=[1.57d0,.99d0,1.57d0]
 env=soil_n_day_environment_t(0d0,1d0,5d0)
 call initialize_application_config(cfg,-75d0,k)
 cfg%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
 cfg%tiles(1)%base_forcing%top_flux=0d0;cfg%tiles(1)%base_forcing%bottom_flux=-.1d0
 cfg%tiles(1)%base_forcing%drainage_flux_by_level=1d-4
 cfg%tiles(1)%base_forcing%subsurface_irrigation_source=0d0
 cfg%tiles(1)%parameters%root_extraction_active=.true.
 cfg%tiles(1)%base_forcing%root_extraction_sink=1d-4
 cfg%tiles(1)%base_forcing%root_potential_transpiration=.0008d0
 cfg%numerical%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
 cfg%numerical%model_temporal_indicator_budget_available=.true.;cfg%numerical%model_temporal_indicator_budget=1d-4
 cfg%numerical%transaction%temporal_tolerance=0d0
 cfg%numerical%transaction%max_retries=30;cfg%numerical%max_committed_substeps=4096
 column%column_id=cfg%tiles(1)%tile_id;column%template_id=cfg%tiles(1)%template%template_id
 column%parameter_ref=1_int64;column%state_handle=1_int64;column%forcing_handle=1_int64
 column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
 call parameters(sp);call materials(items,split);call configure_crop(cp);cp%base%nitrogen%nfix_fr=.3d0;cp%update%leaf_lifespan=1.5d0;cp%lai_crit_nupt=1d0
 call configure_owner(crop,cp,status);call require(status==0,'WOFOST81 owner initialize')
 allocate(cp%harvest);cp%harvest%crop_identity=7;cp%harvest%crop_end=0d0
 cp%harvest%policy%return_fraction=[.2d0,.5d0,.3d0]
 cp%harvest%policy%application_age=[1.57d0,.99d0,1.57d0,.99d0]

 crop%nitrogen%value%namountlv=crop%nitrogen%value%namountlv-2d0
 crop%nitrogen%value%initial_total=crop%nitrogen%value%initial_total-2d0
 weather%minimum_temperature=3d0;weather%average_temperature=10d0;weather%daytime_average_temperature=15d0
 weather%global_radiation=1d7;weather%daylength_hours=12d0;weather%photoperiodic_daylength_hours=12d0
 weather%sinld=.3d0;weather%cosld=.7d0;weather%diffuse_perpendicular_radiation=100d0
 weather%daily_sine_solar_elevation_integral=30000d0
 call initialize_soil_n_pool_state(sp%mineral%inventory,spread(1d0,1,8),5d0,40d0,.02d0,.03d0,pools,status)
 call require(status==0,'soil inventory initialize')
 call backend%initialize(top);call second%initialize(top)
 if(trim(mode)=='reject')then
  call read_crop_soil_n_joint_restart_file(trim(path),column,cfg%tiles(1)%template,670001_int64,9001_int64,9101_int64, &
    sp,cp,water,state,status)
  call require(status/=0.and..not.water%ready().and..not.state%ready(),'invalid complete restart atomic rejection')
  print '(A)','CROP_SOIL_INVALID_DISK=PASS';stop
 end if
 if(trim(mode)=='resume')then
  call read_crop_soil_n_joint_restart_file(trim(path),column,cfg%tiles(1)%template,670001_int64,9001_int64,9101_int64, &
    sp,cp,water,state,status)
  call require(status==0,'fresh-process three-owner reconstruction')
  call second_day(backend,water,state)
  call write_crop_soil_n_joint_restart_file(trim(endpoint),column,cfg%tiles(1)%template,670001_int64,water,state,status)
  call require(status==0,'fresh complete endpoint')
  print '(A)','CROP_SOIL_FRESH_PROCESS_CONTINUATION=PASS';stop
 end if
 call fmr_new_b110_temporal_indicator_committed_state(water,column%column_id,cfg%tiles(1)%initial_state,0d0,ok, &
   spread(0d0,1,numnod));call require(ok,'water initialize')
 theta=sum(dz*cfg%tiles(1)%initial_state%water_content)/sum(dz)
 call initialize_reactive(sp,9001_int64,0d0,theta,pools,soil,status);call require(status==0,'reactive initialize')
 call initialize_crop_soil(soil,crop,cp,9101_int64,state,status);call require(status==0,'three-owner initialize')
 initial_water=water;initial_state=state;initial_soil=soil;old_crop=pack_crop_n_owner(crop)
 bad_items=items;bad_items(2)%kind=999
 call run_crop_soil_n_senescence_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,water, &
   cfg%tiles(1)%base_forcing,cfg%numerical,state,weather,0d0,1d0,bad_items,split,policy,result,env)
 call require(result%status/=0,'late material rejects whole batch');call unchanged()

 invalid=cfg%tiles(1)%base_forcing;invalid%root_extraction_sink=-1d0
 call run_crop_soil_n_senescence_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,water,invalid, &
    cfg%numerical,state,weather,0d0,1d0,items,split,policy,result,env)
 call require(result%status/=0,'water rejected');call unchanged()
 invalid=cfg%tiles(1)%base_forcing;invalid%top_flux=-.001d0
 call run_crop_soil_n_senescence_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,water,invalid, &
    cfg%numerical,state,weather,0d0,1d0,items,split,policy,result,env)
 call require(result%status==JOINT_CHEMICAL_REJECTED,'carrier rejects after actual water trial');call unchanged()
 bad_weather=weather;bad_weather%average_temperature=ieee_value(0d0,ieee_quiet_nan)
 call run_crop_soil_n_senescence_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,water, &
    cfg%tiles(1)%base_forcing,cfg%numerical,state,bad_weather,0d0,1d0,items,split,policy,result,env)
 call require(result%status==JOINT_CHEMICAL_REJECTED,'crop forcing rejects after actual water trial');call unchanged()
 block
  type(crop_soil_state_t)::bad_state
  type(kernel_committed_state_t)::bad_water
  bad_sp=sp;bad_sp%organic_reference%ratecon_bio=0d0;bad_sp%organic_reference%ratecon_hum=0d0
  call initialize_reactive(bad_sp,9001_int64,0d0,theta,pools,after_soil,status)
  call initialize_crop_soil(after_soil,crop,cp,9101_int64,bad_state,status)
  call require(status==0,'stage singular organic trial')
  bad_water=water
  call run_crop_soil_n_senescence_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,bad_water, &
    cfg%tiles(1)%base_forcing,cfg%numerical,bad_state,weather,0d0,1d0,items,split,policy,result,env)
  call require(result%status==JOINT_CHEMICAL_REJECTED,'reaction rejects after actual crop preparation')
  call require(bad_water%current_revision()==water%current_revision(),'reaction no water leak')
  call bad_state%snapshot(after_soil,after_crop);actual_crop=pack_crop_n_owner(after_crop)
  call require(all(actual_crop==old_crop),'reaction no crop leak')
 end block
 block
  integer::i
  do i=1,5
   bad_env=env
   select case(i)
   case(1);bad_env%temperature_c=ieee_value(0d0,ieee_quiet_nan)
   case(2);bad_env%temperature_c=-20.01d0
   case(3);bad_env%temperature_c=60.01d0
   case(4);bad_env%t0=1d0
   case(5);bad_env%t1=2d0
   end select
   call run_crop_soil_n_senescence_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,water, &
    cfg%tiles(1)%base_forcing,cfg%numerical,state,weather,0d0,1d0,items,split,policy,result,bad_env)
   call require(result%status==JOINT_CHEMICAL_REJECTED,'material plus invalid temperature after actual water');call unchanged()
  end do
 end block
 bad_policy=policy;bad_policy%application_age(3)=100.01d0
 call run_crop_soil_n_senescence_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,water, &
    cfg%tiles(1)%base_forcing,cfg%numerical,state,weather,0d0,1d0,items,split,bad_policy,result,env)
 call require(result%status/=0,'late invalid pending material after actual water crop');call unchanged()
 call run_crop_soil_n_senescence_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,water, &
    cfg%tiles(1)%base_forcing,cfg%numerical,state,weather,0d0,1d0,items,split,policy,result,env)
 if(result%status/=0)print *,'diagnostics',result%status,result%joint%joint%water%status,result%joint%joint%chemical%status,result%joint%joint%chemical%soil%status
 call require(result%status==JOINT_OK,'actual Richards WOFOST81 material N valid retry')
 call require(result%senescence%materials%gross_n>0d0.and.result%senescence%materials%volatilized_n>0d0.and. &
   abs(result%senescence%materials%residual)<=1d-12,'material plus day whole N')
 call require(abs(result%joint%joint%chemical%whole_n_residual)<=1d-12,'hard soil crop whole N balance')
 call require(result%joint%joint%chemical%internal_supply_kg_m2>0d0.and.result%joint%joint%chemical%fixation_kg_m2>0d0,'soil debit plus WOFOST81 fixation')
 call require(result%joint%joint%chemical%internal_supply_kg_m2<result%joint%joint%chemical%prepared%nitrogen_request%soil_request*1d-4,'actual limited supply')
 call literal_actual()
 call state%pending_snapshot(pending,has_pending)
 call require(has_pending.and.all(pending%dry_matter_kg_ha>0d0).and.result%senescence%incorporated_n==0d0,'actual3-organ pending, no same-day incorporation')
 call require(abs(result%senescence%whole_n_residual)<=1d-12,'pending included whole N')
 block
  real(real64),allocatable::before(:),after(:)
  integer(int64)::water_revision
  call state%snapshot(after_soil,after_crop);before=pack_crop_n_owner(after_crop);water_revision=water%current_revision()
  call run_crop_soil_n_senescence_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,water, &
    cfg%tiles(1)%base_forcing,cfg%numerical,state,weather,0d0,1d0,items,split,policy,result,env)
  call require(result%status/=0,'consumed batch cannot replay')
  call state%snapshot(after_soil,after_crop);after=pack_crop_n_owner(after_crop)
  call require(all(before==after).and.water%current_revision()==water_revision,'replay no owner leak')
 end block
 call run_crop_soil_n_harvest_boundary(water,state,.false.,harvest_result)
 call require(harvest_result%status==0.and.abs(harvest_result%residual)<=1d-12,'actual joint same-clock harvest')
 call require(water%current_revision()==1_int64,'harvest leaves water revision unchanged')
 call state%pending_snapshot(pending,has_pending)
 call require(has_pending,'final daily death survives actual harvest')
 call run_crop_soil_n_harvest_boundary(water,state,.false.,harvest_result)
 call require(harvest_result%status/=0,'actual duplicate harvest rejected')
 call export_crop_soil_n_joint_restart(column,cfg%tiles(1)%template,670001_int64,water,state,payload,status)
 call require(status==0,'opaque complete export')
 call write_crop_soil_n_joint_restart_file(trim(path),column,cfg%tiles(1)%template,670001_int64,water,state,status)
 call require(status==0,'complete disk export')
 other_water=kernel_committed_state_t();other_state=crop_soil_state_t()
 call restore_crop_soil_n_joint_restart(payload,column,cfg%tiles(1)%template,670001_int64,9999_int64,other_water,other_state,status)
 call require(status/=0.and..not.other_water%ready().and..not.other_state%ready(),'opaque wrong crop identity atomic')
 call restore_crop_soil_n_joint_restart(payload,column,cfg%tiles(1)%template,670001_int64,9101_int64,other_water,other_state,status)
 call require(status==0,'opaque complete restore')
 call second_day(backend,water,state);call second_day(second,other_water,other_state)
 call write_crop_soil_n_joint_restart_file(trim(endpoint),column,cfg%tiles(1)%template,670001_int64,water,state,status)
 call require(status==0,'continuous complete endpoint')
 call write_crop_soil_n_joint_restart_file(trim(endpoint)//'.opaque',column,cfg%tiles(1)%template,670001_int64,other_water,other_state,status)
 call require(status==0,'opaque complete endpoint')
 print '(A)','HARVEST_ACTUAL_RICHARDS_ATOMIC_PENDING_OPAQUE_NATIVE=PASS'
contains
 subroutine literal_actual()
  type(fmr_serialized_physical_observation_t)::obs
  type(mineral_state_t)::base
  type(mineral_daily_carrier_t)::c
  type(soil_n_pool_state_t)::want,staged
  integer::i
  real(real64)::nit,denit,carbon,supply,literal(12)
  obs=backend%observation();call initial_soil%mineral_snapshot(base)
  call aggregate_mineral_trace(base,obs%accepted_water_flux_substeps,c,status);call require(status==0,'actual validated carrier')
  staged=pools
  do i=1,2
   call literal_material(items(i)%kind,items(i)%material,split,literal)
   staged%fom_kg_m3=staged%fom_kg_m3+literal(1:8);staged%humus_kg_m3=staged%humus_kg_m3+literal(9)
   staged%ammonium_n_kg_m2=staged%ammonium_n_kg_m2+literal(10);staged%nitrate_n_kg_m2=staged%nitrate_n_kg_m2+literal(11)
  end do
  oracle_p=sp;oracle_p%environment%temperature_c=5d0
  call require(result%joint%joint%chemical%soil%environment_forcing_used.and.result%joint%joint%chemical%soil%temperature_used_c==5d0,'actual material first temperature')
  call literal_crop_day(oracle_p,staged,c%water_start,c%water_end,c%outflow,c%in_bottom,c%in_lateral,c%root_water,want, &
    nit,denit,carbon,result%joint%joint%chemical%prepared%nitrogen_request%soil_request,.5d0,4d0,30d0,1d0,1d0,supply)
  call state%snapshot(after_soil,after_crop);call after_soil%snapshot(time,theta,s,revision)
  call require(abs(supply-result%joint%joint%chemical%internal_supply_kg_m2)<=1d-12,'actual literal soil supply')
  call require(abs(s%ammonium_n_kg_m2-want%ammonium_n_kg_m2)<=1d-12.and. &
    abs(s%nitrate_n_kg_m2-want%nitrate_n_kg_m2)<=1d-12,'actual literal full NH4 NO3 state')
  call require(maxval(abs(s%fom_kg_m3-want%fom_kg_m3))<=1d-12.and.abs(s%biomass_kg_m3-want%biomass_kg_m3)<=1d-12.and.abs(s%humus_kg_m3-want%humus_kg_m3)<=1d-12,'literal actual eight FOM biomass humus')
  call require(time==1d0.and.revision==1,'joint daily consumed clock')
 end subroutine
 subroutine unchanged()
  call require(water%current_revision()==initial_water%current_revision(),'water revision unchanged')
  call state%snapshot(after_soil,after_crop);actual_crop=pack_crop_n_owner(after_crop)
  call require(all(actual_crop==old_crop),'crop mass N cohorts history unchanged')
  call after_soil%snapshot(time,theta,s,revision)
  call require(time==0d0.and.revision==0.and.all(s%fom_kg_m3==pools%fom_kg_m3).and. &
    s%ammonium_n_kg_m2==pools%ammonium_n_kg_m2.and.s%nitrate_n_kg_m2==pools%nitrate_n_kg_m2,'soil rollback')
 end subroutine
 subroutine second_day(b,w,n)
  type(fmr_serialized_reference_backend_t),intent(inout)::b
  type(kernel_committed_state_t),intent(inout)::w
  type(crop_soil_state_t),intent(inout)::n
  type(kernel_committed_state_t)::unchanged_water
  type(crop_soil_state_t)::before
  type(crop_soil_harvest_receipt_t)::r
  type(reactive_state_t)::soil
  type(wofost81_crop_owner_state_t)::crop
  type(wofost81_harvest_record_t)::h
  type(crop_residue_pending_t)::pending
  real(real64)::initial,expected,time
  logical::has,ok
  unchanged_water=w;before=n;initial=crop_soil_whole_n(n)
  call n%snapshot(soil,crop);call crop%harvest_snapshot(h,has)
  call require(has.and..not.h%pending_incorporated,'restart retains unconsumed harvest phase')
  expected=sum(h%pending_n)*1d-4
  call n%pending_snapshot(pending,has);if(has)expected=expected+pending%nitrogen_kg_m2()
  call run_crop_soil_n_harvest_boundary(w,n,.true.,r)
  call require(r%status==0.and.abs(r%residual)<=1d-12.and.abs(r%incorporated_n-expected)<=1d-12,'actual joint seven-organ consumption')
  call require(abs(initial-crop_soil_whole_n(n))<=1d-12,'actual internal pending whole N')
  call require(w%current_revision()==unchanged_water%current_revision().and. &
   w%current_lineage_id()==unchanged_water%current_lineage_id(),'no physical revision or lineage change')
  call w%current_time(time,ok);call require(ok.and.time==1d0,'no fictitious physical time')
  call run_crop_soil_n_harvest_boundary(w,n,.true.,r)
  call require(r%status/=0,'actual consumed restart phase cannot replay')
 end subroutine
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then;print '(A)','FAIL '//label;error stop 1;end if
 end subroutine
 include 'crop_fixture.inc'
 include 'material_fixture.inc'
 include 'material_oracle.inc'
 include 'crop_oracle.inc'
 include 'matrix_fixture.inc'
end program
