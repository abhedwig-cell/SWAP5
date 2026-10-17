program test_b112_retained_empty
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use literal_reproductive,only:literal_n=>literal
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
 character(32)::selected
 call get_command_argument(1,mode);call get_command_argument(2,path);call get_command_argument(3,endpoint)
 call get_command_argument(4,selected)
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
 call parameters(sp);call materials(items,split);call configure_crop(cp);cp%base%nitrogen%nfix_fr=.3d0;cp%update%leaf_lifespan=100d0;cp%lai_crit_nupt=1d0
 if(trim(selected)=='old-profile')then
  allocate(cp%b111_request);cp%b111_request%dvsnlt=.9d0;cp%b111_request%nfixf=.25d0
 else if(trim(selected)/='absent')then
  allocate(cp%b111_reproductive)
  cp%b111_reproductive%dvsnlt=.9d0;cp%b111_reproductive%dvsnt=.4d0
  cp%b111_reproductive%nfixf=.25d0;cp%b111_reproductive%fntrt=.25d0
  select case(trim(selected))
  case('wrong-dvsnlt');cp%b111_reproductive%dvsnlt=.7d0
  case('wrong-dvsnt');cp%b111_reproductive%dvsnt=.3d0
  case('wrong-nfixf');cp%b111_reproductive%nfixf=.5d0
  case('wrong-fntrt');cp%b111_reproductive%fntrt=.5d0
  end select
 end if
 if(trim(selected)/='old-profile'.and.trim(selected)/='absent'.and.trim(selected)/='legacy')then
  allocate(cp%b112_return,cp%harvest)
  cp%b112_return%leaf_fraction=.25d0
  if(trim(selected)=='wrong-return')cp%b112_return%leaf_fraction=.5d0
  cp%harvest%crop_identity=1;cp%harvest%crop_end=1d0;cp%harvest%sw_harv=0;cp%harvest%sw_wofost=1
  cp%harvest%policy%return_fraction=[.5d0,.25d0,.5d0]
  cp%harvest%policy%application_age=[1.57d0,.99d0,1.57d0,1.57d0]
 endif
 cp%tables(15)%y=.02d0
 call configure_owner(crop,cp,status);call require(status==0,'WOFOST81 owner initialize')
 crop%nitrogen%value%namountlv=4d0;crop%nitrogen%value%namountst=1d0;crop%nitrogen%value%namountrt=.5d0
 crop%nitrogen%value%namountso=.5d0;crop%nitrogen%value%initial_total=6d0
 crop%nitrogen%value%namountlv=crop%nitrogen%value%namountlv-2d0
 crop%nitrogen%value%initial_total=crop%nitrogen%value%initial_total-2d0
 weather%minimum_temperature=3d0;weather%average_temperature=10d0;weather%daytime_average_temperature=15d0
 weather%global_radiation=1d7;weather%daylength_hours=12d0;weather%photoperiodic_daylength_hours=12d0
 weather%sinld=.3d0;weather%cosld=.7d0;weather%diffuse_perpendicular_radiation=100d0
 weather%daily_sine_solar_elevation_integral=30000d0
 call initialize_soil_n_pool_state(sp%mineral%inventory,spread(1d0,1,8),5d0,40d0,.02d0,.03d0,pools,status)
 call require(status==0,'soil inventory initialize')
 call backend%initialize(top);call second%initialize(top)
 call fmr_new_b110_temporal_indicator_committed_state(water,column%column_id,cfg%tiles(1)%initial_state,0d0,ok, &
   spread(0d0,1,numnod));call require(ok,'water initialize')
 theta=sum(dz*cfg%tiles(1)%initial_state%water_content)/sum(dz)
 call initialize_reactive(sp,9001_int64,0d0,theta,pools,soil,status);call require(status==0,'reactive initialize')
 call initialize_crop_soil(soil,crop,cp,9101_int64,state,status);call require(status==0,'three-owner initialize')
 call state%snapshot(after_soil,crop)
 call write_crop_soil_n_joint_restart_file('empty.bin',column,cfg%tiles(1)%template,670001_int64,water,state,status)
 call require(status==0,'native live empty write')
 call read_crop_soil_n_joint_restart_file('empty.bin',column,cfg%tiles(1)%template,670001_int64,9001_int64,9101_int64, &
  sp,cp,other_water,other_state,status)
 call require(status==0,'native live empty restore')
 call other_state%snapshot(after_soil,after_crop)
 call require(all(pack_crop_n_owner(crop)==pack_crop_n_owner(after_crop)),'native live empty exact profile')
 print '(A)','B112_NATIVE_LIVE_EMPTY=PASS'
contains
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then;print *,label;error stop 1;end if
 end subroutine
 include 'crop_fixture.inc'
 include 'material_fixture.inc'
 include 'matrix_fixture.inc'
end program
