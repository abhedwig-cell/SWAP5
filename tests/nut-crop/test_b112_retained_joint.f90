program test_b112_retained_joint
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
 use mod_crop_soil_n_historical_project_binding,only:initialize_historical_crop_soil_owner
 use mod_soil_n_historical_activation,only:soil_n_historical_selection_t
 use mod_soil_n_amendment_calendar,only:soil_n_amendment_calendar_t,select_soil_n_amendments, &
  create_soil_n_amendment_calendar,N_CALENDAR_OK
 use mod_soil_n_amendment_input,only:parse_soil_n_date,N_INPUT_OK
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
 use mod_fmr_crop_soil_n_calendar_application,only:run_crop_soil_n_calendar_interval
 use mod_crop_soil_n_calendar_day,only:advance_crop_soil_fallow_calendar_day
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
 if(trim(selected)=='source-profile'.or.trim(selected)=='rotation-profile')then
  call source_continuation()
  stop
 end if
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
  call finish_harvest(water,state,trim(endpoint)//'.fresh-stages')
  call write_crop_soil_n_joint_restart_file(trim(endpoint),column,cfg%tiles(1)%template,670001_int64,water,state,status)
  call require(status==0,'fresh complete endpoint')
  print '(A)','CROP_SOIL_FRESH_PROCESS_CONTINUATION=PASS';stop
 end if
 call fmr_new_b110_temporal_indicator_committed_state(water,column%column_id,cfg%tiles(1)%initial_state,0d0,ok, &
   spread(0d0,1,numnod));call require(ok,'water initialize')
 theta=sum(dz*cfg%tiles(1)%initial_state%water_content)/sum(dz)

 ! Actual source-export startup through the already owned crop+Soil-N state,
 ! before exercising incumbent daily Richards and opaque restart scenarios.
 if(trim(mode)=='write'.and.len_trim(selected)==0)then
 block
   type(soil_n_historical_selection_t)::selection
   type(soil_n_amendment_calendar_t)::startup_calendar
   type(crop_soil_state_t)::startup_state
   type(crop_senescence_policy_t)::startup_policy
   integer::unit,i,errline
   character(16)::key
   selection%swcropsnm=1;selection%sw_wofost=1;selection%source_parameters_complete=.true.
   open(newunit=unit,file='source-crop-startup.txt',status='replace')
   write(unit,'(A)')'[management]'
   write(unit,'(A)')'MatNum MatName AppAge OrgMatFrac OrgNFrac NH4NFrac NO3NFrac'
   write(unit,'(A)')"1 'Mineral' 0 0 0 0.21 0.10"
   write(unit,'(A)')'smedate iMat Dosagekgha VolatFraction'
   write(unit,'(A)')'1900-01-01 1 100 0.1'
   write(unit,'(A)')'[soil_n_parameters]'
   do i=1,8
     write(key,'(A,I1,A)')'FOM',i,'_t'
     write(unit,'(A)')trim(key)//' = 1.0'
   end do
   write(unit,'(A)')'Bio_t = 5','Hum_t = 40','cNH4_t = 0.02','cNO3_t = 0.03', &
     'Temp_ref = 20','SorpCoef = 0.0002','RateConNitrif_ref = 0.02', &
     'RateConDenitr_ref = 0.03','WFPSCrit = 0.6','WFPScrit2 = 0.5', &
     'CdissiHalf = 0.1','TCSF_N = 0.5','LaiCritNupt = 1', &
     'dz_WSN = 0.3','cNH4N_lat = 0.3','cNO3N_lat = 0.4', &
     'cNH4N_seep = 0.1','cNO3N_seep = 0.2'
   close(unit)
   call initialize_historical_crop_soil_owner(selection,sp,cp,crop,9001_int64,9101_int64, &
      0d0,theta,'source-crop-startup.txt','1900-01-01',startup_calendar, &
      startup_state,startup_policy,status,errline)
   call require(status==0.and.startup_state%ready().and.startup_calendar%ready(), &
     'real crop and Soil-N state jointly initialized by one source export')
   call require(all(startup_policy%application_age==[1.27d0,.99d0,1.27d0]), &
     'actual coupled owner has source apparent ages')
 end block
 end if
 call initialize_reactive(sp,9001_int64,0d0,theta,pools,soil,status);call require(status==0,'reactive initialize')
 call initialize_crop_soil(soil,crop,cp,9101_int64,state,status);call require(status==0,'three-owner initialize')
 call state%snapshot(after_soil,crop)
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
 call source_n(crop,after_crop,result%joint%joint%chemical)
 call require(result%joint%joint%chemical%crop%rntranslocation_applied>0d0,'active source storage and multi donor transfer')
 call state%pending_snapshot(pending,has_pending)
 call require(has_pending.and.all(pending%dry_matter_kg_ha(1:2)>0d0).and.pending%dry_matter_kg_ha(3)==0d0.and.result%senescence%incorporated_n==0d0,'source root/partial leaf pending and retained stem')
 call state%snapshot(after_soil,after_crop)
 call require(after_crop%nitrogen%b112_residue_profile.and.all(after_crop%nitrogen%retained_dead_n>0d0),'nonzero actual retained N')
 call require(all(after_crop%crop%biomass%retained_dead_biomass>0d0),'nonzero actual retained DM')
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
 call finish_harvest(water,state,trim(endpoint)//'.stages')
 call finish_harvest(other_water,other_state,trim(endpoint)//'.opaque-stages')
 call write_crop_soil_n_joint_restart_file(trim(endpoint),column,cfg%tiles(1)%template,670001_int64,water,state,status)
 call require(status==0,'continuous complete endpoint')
 call write_crop_soil_n_joint_restart_file(trim(endpoint)//'.opaque',column,cfg%tiles(1)%template,670001_int64,other_water,other_state,status)
 call require(status==0,'opaque complete endpoint')
 print '(A)','B112_ACTUAL_RICHARDS_RETAINED_PENDING_HARVEST_OPAQUE_NATIVE=PASS'
contains
 subroutine source_continuation()
   type(soil_n_historical_selection_t)::selection
   type(soil_n_amendment_calendar_t)::startup_plan
   type(crop_senescence_policy_t)::startup_policy
   type(reactive_state_t)::source_soil
   type(wofost81_crop_owner_state_t)::source_crop
   type(soil_n_day_environment_t)::day2_env,day1_env
   type(senescence_joint_result_t)::day_receipt
   type(b111_soil_n_material_t),allocatable::scheduled(:)
   integer,allocatable::record_indices(:)
   integer::unit,j,error_line,code,day
   integer(int64)::sid
   character(16)::key
   real(real64)::source_water,base_day
   call parse_soil_n_date('1900-12-30',base_day,code)
   if(trim(selected)=='rotation-profile')cp%harvest%crop_end=base_day+120d0
   call require(code==N_INPUT_OK,'year-boundary calendar origin')
   day1_env=soil_n_day_environment_t(base_day,base_day+1d0,5d0)
   selection%swcropsnm=1;selection%sw_wofost=1
   selection%source_parameters_complete=.true.
   ! Source keyword-array subset, preserving original named TTUTIL fields.
   open(newunit=unit,file='source-crop-startup.snm',status='replace')
   write(unit,'(A)')'MatNum = 1'
   write(unit,'(A)')"MatName = 'Mineral'"
   write(unit,'(A)')'AppAge = 0'
   write(unit,'(A)')'OrgMatFrac = 0'
   write(unit,'(A)')'OrgNFrac = 0'
   write(unit,'(A)')'NH4NFrac = 0.21'
   write(unit,'(A)')'NO3NFrac = 0.10'
   write(unit,'(A)')'smedate = 1900-12-30, 1901-01-01, 1901-01-01, 1901-12-31, 1902-01-01'
   write(unit,'(A)')'iMat = 1 1 1 1 1'
   write(unit,'(A)')'Dosagekgha = 100 50 25 75 25'
   write(unit,'(A)')'VolatFraction = 0.1 0.1 0.1 0.1 0.1'
   do j=1,8
     write(key,'(A,I1,A)')'FOM',j,'_t'
     write(unit,'(A)')trim(key)//' = 1.0'
   end do
   write(unit,'(A)')'Bio_t = 5','Hum_t = 40','cNH4_t = 0.02','cNO3_t = 0.03', &
     'Temp_ref = 20','SorpCoef = 0.0002','RateConNitrif_ref = 0.02', &
     'RateConDenitr_ref = 0.03','WFPSCrit = 0.6','WFPScrit2 = 0.5', &
     'CdissiHalf = 0.1','TCSF_N = 0.5','LaiCritNupt = 1', &
     'dz_WSN = 0.3','cNH4N_lat = 0.3','cNO3N_lat = 0.4', &
     'cNH4N_seep = 0.1','cNO3N_seep = 0.2'
   close(unit)
   ! Long-horizon physical variant: remove the prescribed sustained bottom
   ! extraction while retaining root uptake, drainage and strict temporal
   ! certificate. The historic -0.1 bottom-flux stress result remains recorded
   ! as a separate failed diagnostic, not rewritten as a passing experiment.
   cfg%tiles(1)%base_forcing%bottom_flux=0d0
   ! Source owner is reconstructed from the same input in each fresh process.
   ! The restart decoder verifies its parameter identity against these values.
   call fmr_new_b110_temporal_indicator_committed_state(water,column%column_id, &
      cfg%tiles(1)%initial_state,base_day,ok,spread(0d0,1,numnod))
   call require(ok,'source water state')
   source_water=sum(dz*cfg%tiles(1)%initial_state%water_content)/sum(dz)
   ! A malformed source array must not be silently shortened or reordered.
   block
     type(crop_soil_state_t)::rejected_state
     type(soil_n_amendment_calendar_t)::rejected_plan
     type(crop_senescence_policy_t)::rejected_policy
     integer::input_unit,output_unit,ios,case_number,source_record,nitrif_record
     character(512)::source_line
     do case_number=1,9
       open(newunit=input_unit,file='source-crop-startup.snm',status='old',action='read')
       open(newunit=output_unit,file='source-crop-invalid.snm',status='replace')
       source_record=0;nitrif_record=0
       do
         read(input_unit,'(A)',iostat=ios)source_line
         if(ios==0)source_record=source_record+1
         if(ios/=0)exit
         if(index(source_line,'iMat = ')==1)then
           select case(case_number)
           case(1);source_line='iMat = 1,,1,1,1,1'
           case(2);source_line='iMat = 1,1,1,1,1,'
           case(3);source_line='iMat = ,1,1,1,1,1'
           case(4);source_line='iMat = 1 1 1 1'
           case(5);source_line='iMat = 1 1 9 1 1'
           end select
         end if
         if(index(source_line,'MatNum = ')==1)then
           select case(case_number)
           case(6);source_line='MatNum = 2'
           case(7);source_line='MatNum = '
           end select
         end if
         if(index(source_line,'smedate = ')==1.and.case_number==8) &
           source_line='smedate = 1900-12-30 1901-02-29 1901-01-01 1901-12-31 1902-01-01'
         if(index(source_line,'RateConNitrif_ref = ')==1.and.case_number==9)then
           nitrif_record=source_record
           source_line='RateConNitrif_ref = -0.02'
         end if
         write(output_unit,'(A)')trim(source_line)
       end do
       close(input_unit);close(output_unit)
       call initialize_historical_crop_soil_owner(selection,sp,cp,crop,9001_int64,9101_int64, &
         base_day,source_water,'source-crop-invalid.snm','1900-12-30', &
         rejected_plan,rejected_state,rejected_policy,code,error_line)
       call require(code/=0.and..not.rejected_plan%ready().and..not.rejected_state%ready(), &
         'malformed source SNM rejected atomically')
       if(case_number==9)call require(nitrif_record>0.and.error_line==nitrif_record, &
         'SNM invalid nutrient reports original physical source line')
     end do
   end block
   call initialize_historical_crop_soil_owner(selection,sp,cp,crop,9001_int64,9101_int64, &
      base_day,source_water,'source-crop-startup.snm','1900-12-30',startup_plan, &
      state,startup_policy,status,error_line)
   call require(status==0.and.state%ready().and.startup_plan%ready(),'source owner initialized')
   call require(all(startup_policy%application_age==[1.27d0,.99d0,1.27d0]),'source crop ages')
   if(trim(selected)=='rotation-profile')then
    policy=startup_policy
    call state%configuration(cp,sid)
    call state%snapshot(source_soil,source_crop)
    call source_soil%configuration(sp,sid)
    call rotation_continuation(startup_plan,base_day)
    return
   end if
   ! The calendar passes a real 1900/1901 year boundary without resetting Soil-N.
   ! Exact source-event selection across a complete crop-free calendar year.
   ! The actual Richards driver below spans 124 days; the complete
   ! immutable source forcing plan is checked at every daily boundary.
   do day=0,368
     call select_soil_n_amendments(startup_plan,base_day+real(day,real64),base_day+real(day+1,real64), &
       scheduled,record_indices,code)
     call require(code==N_CALENDAR_OK,'source calendar selection')
     if(day==0.or.day==2.or.day==366.or.day==367)then
       if(day==2)then
         call require(size(scheduled)==2.and.size(record_indices)==2,'same-day source batch')
       else
         call require(size(scheduled)==1.and.size(record_indices)==1,'source event count')
       end if
       select case(day)
       case(0);call require(record_indices(1)==1,'first event identity')
       case(2);call require(all(record_indices==[2,3]),'same-day source order')
         call require(abs(scheduled(2)%application_kg_m2-.0025d0)<1d-14,'same-day dose')
       case(366);call require(record_indices(1)==4,'next-year event identity')
       case(367);call require(record_indices(1)==5,'new-year event identity')
       end select
       if(day==0)call require(abs(scheduled(1)%application_kg_m2-.01d0)<1d-14,'first source dose')
       if(day==2)call require(abs(scheduled(1)%application_kg_m2-.005d0)<1d-14,'second source dose')
       if(day==366)call require(abs(scheduled(1)%application_kg_m2-.0075d0)<1d-14,'next-year source dose')
       if(day==367)call require(abs(scheduled(1)%application_kg_m2-.0025d0)<1d-14,'new-year source dose')
     else
       call require(size(scheduled)==0,'source event not duplicated')
     end if
   end do
   ! Outside the daily grid must fail closed without selecting material.
   call select_soil_n_amendments(startup_plan,base_day+.5d0,base_day+1.5d0, &
     scheduled,record_indices,code)
   call require(code/=N_CALENDAR_OK,'fractional calendar time rejected')
   policy=startup_policy
   call state%configuration(cp,sid)
   call state%snapshot(source_soil,source_crop)
   call source_soil%configuration(sp,sid)
   if(trim(mode)=='resume')then
     ! The native decoder requires blank destination owners; the reconstructed
     ! source project above supplies ONLY the exact parameter identity.
     water=kernel_committed_state_t();state=crop_soil_state_t()
     call read_crop_soil_n_joint_restart_file(trim(path),column,cfg%tiles(1)%template, &
        670001_int64,9001_int64,9101_int64,sp,cp,water,state,code)
     call require(code==0,'source restart decoded with exact source parameters')
   else
     call run_crop_soil_n_calendar_interval(backend,column,cfg%tiles(1)%template, &
       cfg%tiles(1)%parameters,water,cfg%tiles(1)%base_forcing,cfg%numerical, &
       state,weather,base_day,base_day+1d0,startup_plan,split,policy,day_receipt,day1_env)
     call require(day_receipt%status==JOINT_OK,'source actual Richards day one')
     call write_crop_soil_n_joint_restart_file(trim(path),column,cfg%tiles(1)%template, &
       670001_int64,water,state,code)
     call require(code==0,'source day-one native restart')
   end if
   ! Full Richards hydrology and production Soil-N are integrated every day,
   ! preserving the one-day native restart split. This month-scale run is
   ! separate from the accepted annual constant-water chemistry qualification.
   do day=1,123
     if(day>=60.and.day<=67)call report_water_state('before',day)
     day2_env=soil_n_day_environment_t(base_day+real(day,real64),base_day+real(day+1,real64),30d0)
     call run_crop_soil_n_calendar_interval(backend,column,cfg%tiles(1)%template, &
       cfg%tiles(1)%parameters,water,cfg%tiles(1)%base_forcing,cfg%numerical, &
       state,weather,base_day+real(day,real64),base_day+real(day+1,real64),startup_plan,split,policy,day_receipt,day2_env)
     if(day>=60.and.day<=67)call report_water_state('after',day)
     if(day>=60.and.day<=67)then
       print *,'source Richards day trace',day,'status',day_receipt%status, &
         'accepted',day_receipt%joint%joint%diagnostics%accepted_substeps, &
         'temporal_reject',day_receipt%joint%joint%diagnostics%temporal_rejections, &
         'min_dt',day_receipt%joint%joint%diagnostics%min_accepted_substep_duration, &
         'max_indicator_normalized',day_receipt%joint%joint%diagnostics%max_temporal_indicator
     end if
     if(day_receipt%status/=JOINT_OK)then
       print *,'source day failure',day,'joint',day_receipt%status, &
         'senescence',day_receipt%senescence%status, &
         'material',day_receipt%joint%materials%status, &
         'inner_joint',day_receipt%joint%joint%status, &
         'water',day_receipt%joint%joint%water%status, &
         'chemical',day_receipt%joint%joint%chemical%status, &
         'soil',day_receipt%joint%joint%chemical%soil%status
       print *,'water diagnosis status',day_receipt%joint%joint%water%status, &
         'completed',day_receipt%joint%joint%water%completed, &
         'completed_t',day_receipt%joint%joint%water%completed_t
       print *,'water trial diagnostic: accepted,attempts,retries,solver,temporal,mass', &
         day_receipt%joint%joint%diagnostics%accepted_substeps, &
         day_receipt%joint%joint%diagnostics%attempts, &
         day_receipt%joint%joint%diagnostics%retries, &
         day_receipt%joint%joint%diagnostics%solver_rejections, &
         day_receipt%joint%joint%diagnostics%temporal_rejections, &
         day_receipt%joint%joint%diagnostics%mass_rejections
       print *,'water timestep min,max and residual', &
         day_receipt%joint%joint%diagnostics%min_accepted_substep_duration, &
         day_receipt%joint%joint%diagnostics%max_accepted_substep_duration, &
         day_receipt%joint%joint%diagnostics%max_abs_step_mass_residual
       print *,'normalized max temporal indicator / raw head budget / source', &
         day_receipt%joint%joint%diagnostics%max_temporal_indicator, &
         cfg%numerical%model_temporal_indicator_budget, &
         day_receipt%joint%joint%diagnostics%temporal_acceptance_source
     end if
     call require(day_receipt%status==JOINT_OK,'source actual Richards continuation')
   end do
   call write_crop_soil_n_joint_restart_file(trim(endpoint),column,cfg%tiles(1)%template, &
      670001_int64,water,state,code)
   call require(code==0,'source day-two native endpoint')
   print '(A)','NUT_SOURCE_124_DAY_REAL_RICHARDS_FRESH_RESTART=PASS'
 end subroutine
 subroutine rotation_continuation(plan,base_day)
   type(soil_n_amendment_calendar_t),intent(in)::plan
   real(real64),intent(in)::base_day
   type(crop_soil_harvest_receipt_t)::hr
   type(crop_soil_harvest_observation_t)::ho
   type(senescence_joint_result_t)::r,rejected
   type(soil_n_day_environment_t)::e,stale
   type(fmr_b110_physical_forcing_t)::forcing
   type(crop_n_configuration_t)::successor_cp,initial_cp
   type(crop_soil_state_t)::before_state
   type(kernel_committed_state_t)::before_water
   type(reactive_state_t)::ss
   type(wofost81_crop_owner_state_t)::cc
   type(soil_n_pool_state_t)::ps
   real(real64)::clock,moisture,season,uptake,max_n,max_w,n_before,flux_root
   integer(int64)::rev,cid
   integer::d,first,code
   character(32)::arg
   logical::inactive
   initial_cp=cp
   call get_command_argument(5,arg)
   first=0
   if(trim(mode)=='resume')then
    read(arg,*)first
    if(first>=365)then
     cp%harvest%crop_identity=2;cp%harvest%crop_end=base_day+500d0
    end if
    water=kernel_committed_state_t();state=crop_soil_state_t()
    call read_crop_soil_n_joint_restart_file(trim(path),column,cfg%tiles(1)%template, &
     670001_int64,9001_int64,merge(9102_int64,9101_int64,first>=365),sp,cp,water,state,code)
    call require(code==0,'rotation fresh process native restart')
   end if
   uptake=0d0;max_n=0d0;max_w=0d0
   do d=first,729
    inactive=d>=120.and.d<365.or.d>=500
    season=sin(6.283185307179586d0*real(d,real64)/365.2425d0)
    forcing=cfg%tiles(1)%base_forcing
    forcing%drainage_flux_by_level=0d0
    forcing%root_extraction_sink=0d0;forcing%root_potential_transpiration=0d0
    if(.not.inactive)then
     flux_root=.002d0*(1d0+.5d0*season)
     forcing%root_extraction_sink=flux_root/real(numnod,real64)
     forcing%root_potential_transpiration=flux_root
    end if
    ! Controlled sealed-surface column with a prescribed groundwater exchange.
    ! Capillary supply replenishes the transpiration; its seasonal perturbation
    ! permits drainage as well. This is NOT a rainfall/evaporation field scenario.
    forcing%bottom_flux=sum(forcing%root_extraction_sink)+.002d0*season
    e=soil_n_day_environment_t(base_day+real(d,real64),base_day+real(d+1,real64), &
     10d0+8d0*season)
    weather%average_temperature=10d0+5d0*season
    weather%minimum_temperature=weather%average_temperature-5d0
    weather%daytime_average_temperature=weather%average_temperature+4d0
    weather%global_radiation=1d7*(1d0+.4d0*season)
    weather%daylength_hours=12d0+3d0*season
    weather%photoperiodic_daylength_hours=weather%daylength_hours
    if(d==120.or.d==366)then
     before_state=state;before_water=water;stale=e;stale%t0=stale%t0-1d0
     call run_crop_soil_n_calendar_interval(backend,column,cfg%tiles(1)%template, &
      cfg%tiles(1)%parameters,water,forcing,cfg%numerical,state,weather,e%t0,e%t1, &
      plan,split,policy,rejected,stale,fallow=inactive)
     call require(rejected%status/=0,'rotation stale environment rejected')
     call require(water%current_revision()==before_water%current_revision(),'rotation rejected water unchanged')
     call require(crop_soil_whole_n(state)==crop_soil_whole_n(before_state),'rotation rejected nitrogen unchanged')
    end if
    n_before=crop_soil_whole_n(state)
    call run_crop_soil_n_calendar_interval(backend,column,cfg%tiles(1)%template, &
     cfg%tiles(1)%parameters,water,forcing,cfg%numerical,state,weather,e%t0,e%t1, &
     plan,split,policy,r,e,fallow=inactive)
    if(r%status/=0)print *,'ROTATION_FAILURE',d,r%status,r%joint%joint%water%status, &
      r%joint%joint%chemical%status,r%joint%joint%chemical%soil%status
    call require(r%status==0,'rotation actual daily Richards crop Soil-N')
    max_w=max(max_w,r%joint%joint%diagnostics%max_abs_step_mass_residual)
    max_n=max(max_n,abs(r%joint%materials%residual))
    uptake=uptake+r%joint%joint%chemical%internal_supply_kg_m2
    if(inactive)call require(r%joint%joint%chemical%internal_supply_kg_m2==0d0,'fallow zero uptake')
    call require(abs(r%joint%materials%residual)<=1d-12,'rotation whole N daily balance')
    if(d+1==120.or.d+1==500)then
     call harvest_crop_soil_boundary(state,hr)
     call require(hr%status==0,'rotation accepted harvest boundary')
     call consume_crop_soil_harvest_pending(state,hr)
     call require(hr%status==0,'rotation harvest residue incorporation')
     call observe_crop_soil_harvest(state,ho,code)
     call require(code==0,'rotation observe harvest')
     call acknowledge_crop_soil_harvest(state,ho,hr)
     call require(hr%status==0,'rotation retire crop')
    end if
    if(d+1==365)then
     successor_cp=cp;successor_cp%harvest%crop_identity=2
     successor_cp%harvest%crop_end=base_day+500d0
     call initialize_crop_soil_successor(state,crop,successor_cp,9102_int64,hr)
     call require(hr%status==0,'rotation successor in same Soil-N owner')
     cp=successor_cp
    end if
    if(d+1==1.or.d+1==120.or.d+1==121.or.d+1==365.or.d+1==366.or.d+1==500)then
     write(arg,'(I0)')d+1
     call write_crop_soil_n_joint_restart_file(trim(path)//'.'//trim(arg),column, &
      cfg%tiles(1)%template,670001_int64,water,state,code)
     call require(code==0,'rotation transition restart write')
    end if
    if(mod(d+1,60)==0)print *,'ROTATION_PROGRESS',d+1,'maxN',max_n,'maxW',max_w
   end do
   call write_crop_soil_n_joint_restart_file(trim(endpoint),column,cfg%tiles(1)%template, &
    670001_int64,water,state,code)
   call require(code==0,'rotation endpoint')
   print *,'ROTATION_730_DAYS_PASS',first,uptake,max_n,max_w
 end subroutine
 subroutine report_water_state(stage,day)
   character(*),intent(in)::stage
   integer,intent(in)::day
   class(transaction_state_t),allocatable::snapshot
   logical::available
   call water%snapshot(snapshot,available)
   call require(available.and.allocated(snapshot),'water state snapshot available')
   select type(physical=>snapshot)
   type is(fmr_b110_temporal_indicator_state_t)
     call require(allocated(physical%pressure_head).and.allocated(physical%water_content), &
       'water state physical arrays')
     print *,'source water state',trim(stage),day, &
       'mean theta',sum(physical%water_content)/real(size(physical%water_content),real64), &
       'theta minmax',minval(physical%water_content),maxval(physical%water_content), &
       'head minmax',minval(physical%pressure_head),maxval(physical%pressure_head), &
       'head surface bottom',physical%pressure_head(1),physical%pressure_head(size(physical%pressure_head))
   class default
     call require(.false.,'expected temporal Richards continuation state')
   end select
 end subroutine
 subroutine finish_harvest(w,n,prefix)
  type(kernel_committed_state_t),intent(inout)::w
  type(crop_soil_state_t),intent(inout)::n
  character(*),intent(in)::prefix
  type(crop_soil_harvest_receipt_t)::receipt
  type(crop_soil_harvest_observation_t)::observation
  type(crop_soil_state_t)::disk
  type(kernel_committed_state_t)::disk_water
  type(reactive_state_t)::chemical
  type(wofost81_crop_owner_state_t)::owner
  type(wofost81_harvest_record_t)::h
  type(crop_soil_receipt_t)::fallow,fallow_disk
  type(crop_n_configuration_t)::successor_config
  type(soil_n_day_environment_t)::fallow_environment
  type(crop_soil_state_t)::invalid_successor,successor_continuous,successor_disk
  type(crop_soil_harvest_receipt_t)::successor_receipt
  type(soil_n_amendment_calendar_t)::fallow_plan
  type(b111_soil_n_material_t)::fallow_definitions(2)
  type(material_day_receipt_t)::fallow_material,fallow_material_disk
  type(reactive_state_t)::chemical_after
  type(wofost81_crop_owner_state_t)::crop_after
  type(soil_n_pool_state_t)::before_pools,after_pools,disk_pools
  real(real64)::soil_time,soil_water,after_time,after_water,disk_time,disk_water_content
  integer(int64)::soil_revision,after_revision,disk_revision
  real(real64)::before_n,before_dm
  logical::has
  integer::code,fallow_day
  before_n=crop_soil_whole_n(n);before_dm=crop_soil_organic_mass(n)
  call n%snapshot(chemical,owner)
  call chemical%snapshot(soil_time,soil_water,before_pools,soil_revision)
  call harvest_crop_soil_boundary(n,receipt)
  if(receipt%status/=0)print *,'joint harvest rejected',receipt%rejection_stage
  call require(receipt%status==0,'actual Richards accepted-boundary harvest')
  call n%snapshot(chemical,owner);call owner%harvest_snapshot(h,has)
  call chemical%snapshot(after_time,after_water,after_pools,after_revision)
  call require(after_time==soil_time.and.after_water==soil_water.and.after_revision==soil_revision, &
    'harvest preserves soil-N accepted clock water revision')
  call require(all(after_pools%fom_kg_m3==before_pools%fom_kg_m3).and. &
    after_pools%biomass_kg_m3==before_pools%biomass_kg_m3.and. &
    after_pools%humus_kg_m3==before_pools%humus_kg_m3.and. &
    after_pools%ammonium_n_kg_m2==before_pools%ammonium_n_kg_m2.and. &
    after_pools%nitrate_n_kg_m2==before_pools%nitrate_n_kg_m2, &
    'harvest must not reinitialize any soil-N pool')
  call require(has.and.all(owner%nitrogen%retained_dead_n==0d0),'harvest clears physical retained N once')
  call require(abs(before_n-crop_soil_whole_n(n)-sum(h%exported_n)*1d-4)<1d-12,'actual harvest whole N')
  call require(abs(before_dm-crop_soil_organic_mass(n)-sum(h%exported_dm)*1d-4)<1d-12,'actual harvest whole OM')
  call write_crop_soil_n_joint_restart_file(prefix//'.harvest-pending',column,cfg%tiles(1)%template,670001_int64,w,n,code)
  call require(code==0,'selected native harvest/pending version')
  call read_crop_soil_n_joint_restart_file(prefix//'.harvest-pending',column,cfg%tiles(1)%template,670001_int64,9001_int64,9101_int64, &
    sp,cp,disk_water,disk,code)
  call require(code==0,'native retained harvest snapshot reconstructs before incorporation')
  call consume_crop_soil_harvest_pending(n,receipt);call require(receipt%status==0,'accepted harvest and daily pending incorporate')
  call consume_crop_soil_harvest_pending(disk,receipt);call require(receipt%status==0,'restored harvest incorporates once')
  call n%snapshot(chemical,owner)
  call chemical%snapshot(after_time,after_water,after_pools,after_revision)
  call disk%snapshot(chemical_after,crop_after)
  call chemical_after%snapshot(disk_time,disk_water_content,disk_pools,disk_revision)
  call require(after_time==disk_time.and.after_water==disk_water_content.and.after_revision==disk_revision, &
    'native restore retains soil-N state identity after harvest incorporation')
  call require(all(after_pools%fom_kg_m3==disk_pools%fom_kg_m3).and. &
    after_pools%biomass_kg_m3==disk_pools%biomass_kg_m3.and. &
    after_pools%humus_kg_m3==disk_pools%humus_kg_m3.and. &
    after_pools%ammonium_n_kg_m2==disk_pools%ammonium_n_kg_m2.and. &
    after_pools%nitrate_n_kg_m2==disk_pools%nitrate_n_kg_m2, &
    'harvest incorporated all eight FOM, biomass humus NH4 NO3 identically')
  call write_crop_soil_n_joint_restart_file(prefix//'.consumed',column,cfg%tiles(1)%template,670001_int64,w,n,code)
  call require(code==0,'selected native consumed harvest version')
  call write_crop_soil_n_joint_restart_file(prefix//'.disk-consumed',column,cfg%tiles(1)%template,670001_int64,disk_water,disk,code)
  call require(code==0,'restored native consumed harvest version')
  call observe_crop_soil_harvest(n,observation,code);call require(code==0,'harvest observation is same-owner receipt')
  call acknowledge_crop_soil_harvest(n,observation,receipt);call require(receipt%status==0,'retire acknowledged harvest')
  call n%snapshot(chemical,owner)
  call require(owner%harvest_retired().and.owner%nitrogen%b112_residue_profile,'retired profile identity remains explicit')
  call observe_crop_soil_harvest(disk,observation,code)
  call require(code==0,'restored harvest observation')
  call acknowledge_crop_soil_harvest(disk,observation,receipt)
  call require(receipt%status==0,'restored harvest retire')
  successor_continuous=n;successor_disk=disk
  fallow_definitions=items(1)%material
  fallow_definitions%application_kg_m2=0d0
  call create_soil_n_amendment_calendar(2d0,[2d0,366d0],[100d0,50d0], &
    fallow_definitions,fallow_plan,code)
  call require(code==N_CALENDAR_OK,'fallow calendar constructed')
  ! Both accepted physical continuations preserve the same soil-N owner during a
  ! no-crop day, and a successor receives that inventory rather than a new one.
  ! An entire crop-free growing year uses the existing reactive Soil-N owner,
  ! not a synthetic concentration update or repeated project initialization.
  ! Accepted water content is held fixed: this qualifies chemical continuity,
  ! not an annual Richards hydrologic simulation.
  do fallow_day=2,367
    fallow_environment=soil_n_day_environment_t(real(fallow_day,real64),real(fallow_day+1,real64),20d0)
    call advance_crop_soil_fallow_calendar_day(successor_continuous,real(fallow_day,real64), &
      real(fallow_day+1,real64),after_water,0d0,0d0,0d0,fallow_plan,split,fallow_material,fallow_environment)
    call require(fallow_material%status==MATERIAL_OK,'annual real Soil-N calendar reaction')
    call advance_crop_soil_fallow_calendar_day(successor_disk,real(fallow_day,real64), &
      real(fallow_day+1,real64),disk_water_content,0d0,0d0,0d0,fallow_plan,split, &
      fallow_material_disk,fallow_environment)
    call require(fallow_material_disk%status==MATERIAL_OK,'annual restarted calendar reaction')
    if(fallow_day==2.or.fallow_day==366)then
      call require(fallow_material%material_count==1.and.fallow_material%gross_n>0d0, &
        'fallow material delivered once')
    else
      call require(fallow_material%material_count==0,'no duplicate fallow material')
    end if
  end do
  call successor_continuous%snapshot(chemical,owner)
  call chemical%snapshot(after_time,after_water,after_pools,after_revision)
  call successor_disk%snapshot(chemical_after,crop_after)
  call chemical_after%snapshot(disk_time,disk_water_content,disk_pools,disk_revision)
  call require(after_time==368d0.and.disk_time==368d0.and.after_revision==disk_revision, &
    'fallow advances accepted soil N clock')
  call require(all(after_pools%fom_kg_m3==disk_pools%fom_kg_m3).and. &
    after_pools%biomass_kg_m3==disk_pools%biomass_kg_m3.and. &
    after_pools%humus_kg_m3==disk_pools%humus_kg_m3.and. &
    after_pools%ammonium_n_kg_m2==disk_pools%ammonium_n_kg_m2.and. &
    after_pools%nitrate_n_kg_m2==disk_pools%nitrate_n_kg_m2, &
    'fallow keeps identical native soil-N inventories')
  successor_config=cp
  successor_config%harvest%crop_identity=2
  successor_config%harvest%crop_end=368d0
  invalid_successor=successor_continuous
  call initialize_crop_soil_successor(invalid_successor,crop,cp,9102_int64,successor_receipt)
  call require(successor_receipt%status/=CROP_SOIL_OK,'same crop identity rejected without mutation')
  call initialize_crop_soil_successor(successor_continuous,crop,successor_config,9102_int64,successor_receipt)
  call require(successor_receipt%status==CROP_SOIL_OK,'successor crop with same soil-N owner')
  call initialize_crop_soil_successor(successor_disk,crop,successor_config,9102_int64,successor_receipt)
  call require(successor_receipt%status==CROP_SOIL_OK,'restored successor crop with same soil-N owner')
  call successor_continuous%snapshot(chemical,owner)
  call chemical%snapshot(after_time,after_water,after_pools,after_revision)
  call successor_disk%snapshot(chemical_after,crop_after)
  call chemical_after%snapshot(disk_time,disk_water_content,disk_pools,disk_revision)
  call require(all(after_pools%fom_kg_m3==disk_pools%fom_kg_m3).and. &
    after_pools%ammonium_n_kg_m2==disk_pools%ammonium_n_kg_m2.and. &
    after_pools%nitrate_n_kg_m2==disk_pools%nitrate_n_kg_m2, &
    'successor retains soil inventory after restart')
 end subroutine
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
  type(fmr_b110_physical_forcing_t)::forcing
  type(senescence_joint_result_t)::r
  type(soil_n_day_environment_t)::next_env
  type(reactive_state_t)::prior_soil
  type(wofost81_crop_owner_state_t)::prior_crop
  type(mineral_state_t)::base
  type(mineral_daily_carrier_t)::carrier
  type(fmr_serialized_physical_observation_t)::obs
  type(soil_n_pool_state_t)::prior_pools,staged,want,got
  type(crop_residue_pending_t)::old_pending,new_pending
  type(b111_soil_n_material_t)::m(3)
  real(real64)::clock,moisture,literal(12),nit,denit,carbon,supply,lai_before
  logical::has
  integer(int64)::rev
  integer::i,code
  next_env=soil_n_day_environment_t(1d0,2d0,30d0)
  call n%snapshot(prior_soil,prior_crop);call prior_soil%snapshot(clock,moisture,prior_pools,rev)
  call n%pending_snapshot(old_pending,has);call require(has,'restart retains yesterday physical material')
  call prior_crop%crop%derive_actual_leaf_area_index(cp%stem_area,cp%storage_area,lai_before,code)
  ! Stale day-one forcing must reject without consuming the next material batch.
  block
   type(kernel_committed_state_t)::before_water
   type(crop_soil_state_t)::before_state
   before_water=w;before_state=n
   call run_crop_soil_n_senescence_interval(b,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,w, &
    cfg%tiles(1)%base_forcing,cfg%numerical,n,weather,1d0,2d0,items,split,policy,r,env)
   call require(r%status/=0.and.w%current_revision()==before_water%current_revision(),'stale restart temperature no water leak')
   call n%snapshot(after_soil,after_crop);call after_soil%snapshot(clock,moisture,got,rev)
   call require(all(pack_crop_n_owner(prior_crop)==pack_crop_n_owner(after_crop)).and.all(got%fom_kg_m3==prior_pools%fom_kg_m3).and. &
    got%ammonium_n_kg_m2==prior_pools%ammonium_n_kg_m2.and.got%nitrate_n_kg_m2==prior_pools%nitrate_n_kg_m2,'stale full chemical rollback')
  end block
  forcing=cfg%tiles(1)%base_forcing;forcing%bottom_flux=.1d0;forcing%drainage_flux_by_level=0d0
  call run_crop_soil_n_senescence_interval(b,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,forcing, &
    cfg%numerical,n,weather,1d0,2d0,items,split,policy,r,next_env)
  if(r%status/=0)print *,'day2 diagnostics',r%status,r%joint%joint%water%status,r%joint%joint%chemical%status,r%joint%joint%chemical%soil%status
  call require(r%status==0,'actual inflow plus material crop N continuation')
  call require(r%joint%joint%chemical%soil%environment_forcing_used.and.r%joint%joint%chemical%soil%temperature_used_c==30d0,'second material day new temperature')
  call require(sp%environment%temperature_c==20d0.and.next_env%temperature_c==30d0,'immutable configuration and forcing')
  obs=b%observation();call prior_soil%mineral_snapshot(base)
  call aggregate_mineral_trace(base,obs%accepted_water_flux_substeps,carrier,code);call require(code==0,'second actual carrier')
  staged=prior_pools;call build_pending_residue_materials(old_pending,m,code)
  do i=1,5
   if(i<=3)then;call literal_material(2,m(i),split,literal)
   else;call literal_material(items(i-3)%kind,items(i-3)%material,split,literal);end if
   staged%fom_kg_m3=staged%fom_kg_m3+literal(1:8);staged%humus_kg_m3=staged%humus_kg_m3+literal(9)
   staged%ammonium_n_kg_m2=staged%ammonium_n_kg_m2+literal(10);staged%nitrate_n_kg_m2=staged%nitrate_n_kg_m2+literal(11)
  end do
  oracle_p=sp;oracle_p%environment%temperature_c=30d0
  call literal_crop_day(oracle_p,staged,carrier%water_start,carrier%water_end,carrier%outflow,carrier%in_bottom,carrier%in_lateral,carrier%root_water, &
   want,nit,denit,carbon,r%joint%joint%chemical%prepared%nitrogen_request%soil_request,prior_crop%crop%development_stage,lai_before,30d0,1d0,1d0,supply)
  call n%snapshot(after_soil,after_crop);call after_soil%snapshot(clock,moisture,got,rev)
  call require(maxval(abs(got%fom_kg_m3-want%fom_kg_m3))<=1d-12.and.abs(got%biomass_kg_m3-want%biomass_kg_m3)<=1d-12.and. &
   abs(got%humus_kg_m3-want%humus_kg_m3)<=1d-12.and.abs(got%ammonium_n_kg_m2-want%ammonium_n_kg_m2)<=1d-12.and. &
   abs(got%nitrate_n_kg_m2-want%nitrate_n_kg_m2)<=1d-12.and.abs(supply-r%joint%joint%chemical%internal_supply_kg_m2)<=1d-12,'second full literal state and supply')
  call require(abs(r%senescence%materials%residual)<=1d-12.and.r%senescence%materials%gross_n>0d0,'second batch whole N')
  call require(r%senescence%incorporated_n==old_pending%nitrogen_kg_m2().and.abs(r%senescence%whole_n_residual)<=1d-12,'delayed internal transfer full whole N')
  call source_n(prior_crop,after_crop,r%joint%joint%chemical)
  call n%pending_snapshot(new_pending,has);call require(has.and.new_pending%clock==2d0,'new day replaces consumed pending once')
  call require(r%joint%joint%chemical%soil%external_in>0d0.and.abs(r%joint%joint%chemical%whole_n_residual)<=1d-12,'inflow whole soil crop N')
 end subroutine
 subroutine source_n(before,after,day)
  type(wofost81_crop_owner_state_t),intent(in)::before,after
  type(crop_soil_receipt_t),intent(in)::day
  real(real64)::want(8),loss(3),trans(3),uptake(3),requests(6),x(3),pv(4),m(4),dead(3),nmaxlv
  integer::code
  pv=[cp%b111_reproductive%dvsnlt,cp%b111_reproductive%dvsnt,cp%b111_reproductive%nfixf,cp%b111_reproductive%fntrt]
  ! The fixture has a constant maximum concentration table.
  nmaxlv=.02d0
  associate(q=>day%prepared)
   m=[q%wlv_before,q%wst_before,q%wrt_before,q%wso_before];dead=[q%drlv,q%drst,q%drrt]
   call literal_n(cp%base%nitrogen%donor_view(),pv,before%nitrogen%value,before%crop%development_stage, &
     nmaxlv,m,dead,q%corrected_rates%relative_transpiration_used,day%internal_supply_kg_m2*1d4, &
     want,loss,trans,uptake,requests,x)
  end associate
  associate(n=>after%nitrogen%value)
   call require(maxval(abs([n%namountlv,n%namountst,n%namountrt,n%namountso,n%nuptake_total,n%nfix_total, &
    n%nlosses_total,n%initial_total]-want))<=1d-12,'actual joint literal source N all organs ledgers')
  end associate
  call require(all([day%crop%rndeathlv,day%crop%rndeathst,day%crop%rndeathrt]==loss),'joint residual death source')
  call require(all([day%crop%rntranslocationlv_applied,day%crop%rntranslocationst_applied, &
    day%crop%rntranslocationrt_applied]==trans),'joint source donor partitions')
  call require(abs(day%crop%rntranslocation_applied-sum(trans))<=1d-12,'storage credit funded independently')
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
