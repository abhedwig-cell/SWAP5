program test_reactive_joint
 use iso_fortran_env,only:real64,int64
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
 use mod_fmr_b111_reactive_n_joint_application
 use mod_reactive_n_joint_restart_file
 use mod_mineral_joint_restart_file,only:write_mineral_joint_restart_file
 use mod_fmr_b111_mineral_joint_application,only:run_mineral_joint_interval,mineral_joint_result_t
 use mod_fmr_b111_reactive_n_route,only:consume_reactive_n_trace,initialize_historical_reactive_n_route, &
   initialize_historical_reactive_n_from_tables,initialize_historical_reactive_n_complete_tables, &
   initialize_historical_reactive_n_named_files,initialize_historical_reactive_n_unified_export
 use mod_soil_n_amendment_calendar,only:soil_n_amendment_calendar_t
 use mod_crop_soil_n_historical_project_binding,only:initialize_historical_crop_soil_project
 use mod_crop_soil_n_configuration,only:crop_n_configuration_t
 use mod_crop_senescence_residue,only:crop_senescence_policy_t
 use mod_soil_n_historical_activation,only:soil_n_historical_selection_t,soil_n_historical_rates_t,soil_n_historical_initial_t
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use MOD_texture_orgmat,only:bdens
 implicit none
 real(real64),parameter::T0=0d0,T1=1d0,HARD_MASS_GATE=1d-10
 type(fmr_production_application_config_t)::cfg
 type(fmr_serialized_reference_backend_t)::backend,second
 type(fixed_flux_top_boundary_provider_t),target::top
 type(fmr_logical_column_t)::column
 type(kernel_committed_state_t)::water,other_water,initial_water
 type(reactive_state_t)::nitrogen,other_n,initial_n
 type(reactive_n_joint_restart_t)::payload
 type(reactive_n_joint_result_t)::result
 type(reactive_parameters_t)::p,pbad,historical_params
 type(soil_n_historical_rates_t)::historical_rates
 type(soil_n_historical_initial_t)::historical_initial
 real(real64)::historical_tcsf,historical_lai
 type(soil_n_historical_selection_t)::historical
 type(soil_n_amendment_calendar_t)::historical_plan
 integer::input_line,input_unit
 type(soil_n_pool_state_t)::pools,s
 type(fmr_b110_physical_forcing_t)::invalid
 real(real64)::k,time,theta
 integer(int64)::revision
 integer::status
 logical::ok
 character(512)::mode,path,endpoint
 call get_command_argument(1,mode);call get_command_argument(2,path);call get_command_argument(3,endpoint)
 call initialize_application_config(cfg,-75d0,k)
 cfg%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
 cfg%tiles(1)%base_forcing%top_flux=0d0
 cfg%tiles(1)%base_forcing%bottom_flux=-.1d0
 cfg%tiles(1)%base_forcing%drainage_flux_by_level=1d-4
 cfg%tiles(1)%base_forcing%subsurface_irrigation_source=0d0
 cfg%tiles(1)%parameters%root_extraction_active=.true.
 cfg%tiles(1)%base_forcing%root_extraction_sink=1d-4
 cfg%numerical%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
 cfg%numerical%model_temporal_indicator_budget_available=.true.
 cfg%numerical%model_temporal_indicator_budget=1d-4
 cfg%numerical%transaction%temporal_tolerance=0d0
 cfg%numerical%transaction%max_retries=30;cfg%numerical%max_committed_substeps=4096
 column%column_id=cfg%tiles(1)%tile_id;column%template_id=cfg%tiles(1)%template%template_id
 column%parameter_ref=1_int64;column%state_handle=1_int64;column%forcing_handle=1_int64
 column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
 call parameters(p)
 call initialize_soil_n_pool_state(p%mineral%inventory,[10d0,20d0],5d0,40d0,.02d0,.03d0,pools,status)
 call require(status==0,'inventory initialization')
 call backend%initialize(top);call second%initialize(top)
 if(trim(mode)=='reject')then
   call read_reactive_n_joint_restart_file(trim(path),column,cfg%tiles(1)%template,670001_int64,9001_int64,p,water,nitrogen,status)
   call require(status/=0.and..not.water%ready().and..not.nitrogen%ready(),'invalid disk atomic rejection')
   print '(A)','REACTIVE_INVALID_DISK=PASS';stop
 end if
 if(trim(mode)=='resume')then
   call read_reactive_n_joint_restart_file(trim(path),column,cfg%tiles(1)%template,670001_int64,9001_int64,p,water,nitrogen,status)
   call require(status==0,'fresh-process disk reconstruction')
   call second_day(backend,water,nitrogen)
   call write_reactive_n_joint_restart_file(trim(endpoint),column,cfg%tiles(1)%template,670001_int64,water,nitrogen,status)
   call require(status==0,'fresh endpoint')
   print '(A)','REACTIVE_FRESH_PROCESS_CONTINUATION=PASS';stop
 end if
 call off_mode_contract()
 call fmr_new_b110_temporal_indicator_committed_state(water,column%column_id,cfg%tiles(1)%initial_state,0d0,ok, &
   spread(0d0,1,numnod));call require(ok,'water initialization')
 theta=sum(dz*cfg%tiles(1)%initial_state%water_content)/sum(dz)
 historical%swcropsnm=1;historical%sw_wofost=1;historical%source_parameters_complete=.true.
 open(newunit=input_unit,file='historical-actual-input.snm',status='replace')
 write(input_unit,'(A)') 'MatNum MatName AppAge OrgMatFrac OrgNFrac NH4NFrac NO3NFrac'
 write(input_unit,'(A)') "1 'Mineral' 0 0 0 0.21 0.10"
 write(input_unit,'(A)') 'smedate iMat Dosagekgha VolatFraction'
 write(input_unit,'(A)') '1900-01-01 1 100 0.1'
 close(input_unit)
 call initialize_historical_reactive_n_from_tables(historical,p,pools,9001_int64,0d0,theta, &
   'does-not-exist.snm','1900-01-01',historical_plan,nitrogen,status,input_line)
 call require(status/=0.and..not.nitrogen%ready().and..not.historical_plan%ready(),'no half-published read')
 call initialize_historical_reactive_n_from_tables(historical,p,pools,9001_int64,0d0,theta, &
   'historical-actual-input.snm','1900-01-01',historical_plan,nitrogen,status,input_line)
 call require(status==0.and.nitrogen%ready().and.historical_plan%ready(), &
   'historical file+N activation into actual Richards route')

 historical_rates%temp_ref=20d0;historical_rates%sorpcoef=p%mineral%sorption
 historical_rates%ratecon_nitrif_ref=p%environment%nitrification_ref_per_day
 historical_rates%ratecon_denitr_ref=p%environment%denitrification_ref_per_day
 historical_rates%wfpscrit=p%wfpscrit;historical_rates%wfpscrit2=p%environment%wfpscrit2
 historical_rates%cdissi_half=p%environment%cdissi_half_kg_m2
 historical_rates%tcsf_n=.5d0;historical_rates%lai_crit_nupt=3d0
 historical_rates%depth_m=p%mineral%inventory%depth_m
 historical_rates%nh4_lat=p%mineral%c_lateral(1);historical_rates%no3_lat=p%mineral%c_lateral(2)
 historical_rates%nh4_seep=p%mineral%c_bottom(1);historical_rates%no3_seep=p%mineral%c_bottom(2)
 historical_initial%fom_kg_m3=[10d0,20d0,10d0,20d0,10d0,20d0,10d0,20d0]
 ! The full legacy profile requires eight FOM fractions. Keep the existing two-pool
 ! Richards fixture intact and verify rejection before any owner or calendar publication.
 call initialize_historical_reactive_n_complete_tables(historical,historical_rates,historical_initial, &
   p,9001_int64,0d0,theta,'historical-actual-input.snm','1900-01-01',historical_plan, &
   nitrogen,historical_params,historical_tcsf,historical_lai,status,input_line)
 call require(status/=0.and..not.nitrogen%ready().and..not.historical_plan%ready(), &
   'complete historical route rejects unqualified pool layout atomically')
 ! Positive eight-pool historical profile on the actual accepted Richards carrier.
 block
   type(reactive_parameters_t)::eight,eight_bound
   type(reactive_state_t)::eight_n
   type(kernel_committed_state_t)::eight_water
   type(reactive_n_joint_result_t)::eight_result
   type(soil_n_pool_state_t)::eight_after
   real(real64)::et,ew
   integer(int64)::erev
   eight=p
   eight%mineral%inventory%nfrac_fom=[.015d0,.025d0,.015d0,.025d0,.015d0,.025d0,.015d0,.025d0]
   eight%organic_reference%ratecon_fom=[.04d0,.015d0,.04d0,.015d0,.04d0,.015d0,.04d0,.015d0]
   eight%organic_reference%asfa_fom_bio=[.2d0,.25d0,.2d0,.25d0,.2d0,.25d0,.2d0,.25d0]
   eight%organic_reference%asfa_fom_hum=[.15d0,.1d0,.15d0,.1d0,.15d0,.1d0,.15d0,.1d0]
   eight%cfrac_fom=[.45d0,.45d0,.45d0,.45d0,.45d0,.45d0,.45d0,.45d0]
   historical_initial%bio_kg_m3=5d0;historical_initial%hum_kg_m3=40d0
   historical_initial%cnh4_kg_m3=.02d0;historical_initial%cno3_kg_m3=.03d0
   open(newunit=input_unit,file='historical-params.txt',status='replace')
   block
     integer::pool_i
     character(16)::pool_name
     do pool_i=1,8
       write(pool_name,'(A,I1,A)')'FOM',pool_i,'_t'
       write(input_unit,'(A,ES20.12)')trim(pool_name)//' = ',historical_initial%fom_kg_m3(pool_i)
     end do
   end block
   write(input_unit,'(A,ES20.12)') 'Bio_t = ',historical_initial%bio_kg_m3
   write(input_unit,'(A,ES20.12)') 'Hum_t = ',historical_initial%hum_kg_m3
   write(input_unit,'(A,ES20.12)') 'cNH4_t = ',historical_initial%cnh4_kg_m3
   write(input_unit,'(A,ES20.12)') 'cNO3_t = ',historical_initial%cno3_kg_m3
   write(input_unit,'(A,ES20.12)') 'Temp_ref = ',historical_rates%temp_ref
   write(input_unit,'(A,ES20.12)') 'SorpCoef = ',historical_rates%sorpcoef
   write(input_unit,'(A,ES20.12)') 'RateConNitrif_ref = ',historical_rates%ratecon_nitrif_ref
   write(input_unit,'(A,ES20.12)') 'RateConDenitr_ref = ',historical_rates%ratecon_denitr_ref
   write(input_unit,'(A,ES20.12)') 'WFPSCrit = ',historical_rates%wfpscrit
   write(input_unit,'(A,ES20.12)') 'WFPScrit2 = ',historical_rates%wfpscrit2
   write(input_unit,'(A,ES20.12)') 'CdissiHalf = ',historical_rates%cdissi_half
   write(input_unit,'(A,ES20.12)') 'TCSF_N = ',historical_rates%tcsf_n
   write(input_unit,'(A,ES20.12)') 'LaiCritNupt = ',historical_rates%lai_crit_nupt
   write(input_unit,'(A,ES20.12)') 'dz_WSN = ',historical_rates%depth_m
   write(input_unit,'(A,ES20.12)') 'cNH4N_lat = ',historical_rates%nh4_lat
   write(input_unit,'(A,ES20.12)') 'cNO3N_lat = ',historical_rates%no3_lat
   write(input_unit,'(A,ES20.12)') 'cNH4N_seep = ',historical_rates%nh4_seep
   write(input_unit,'(A,ES20.12)') 'cNO3N_seep = ',historical_rates%no3_seep
   close(input_unit)
   ! Feed exactly the same management and nutrient records through a single
   ! bounded export, without silently selecting a second calendar or owner.
   block
     integer::source_unit,target_unit,ios
     character(2048)::buffer
     open(newunit=target_unit,file='historical-unified.txt',status='replace')
     write(target_unit,'(A)')'[management]'
     open(newunit=source_unit,file='historical-actual-input.snm',status='old',action='read')
     do
       read(source_unit,'(A)',iostat=ios)buffer
       if(ios/=0)exit
       write(target_unit,'(A)')trim(buffer)
     end do
     close(source_unit)
     write(target_unit,'(A)')'[soil_n_parameters]'
     open(newunit=source_unit,file='historical-params.txt',status='old',action='read')
     do
       read(source_unit,'(A)',iostat=ios)buffer
       if(ios/=0)exit
       write(target_unit,'(A)')trim(buffer)
     end do
     close(source_unit);close(target_unit)
   end block
   call initialize_historical_reactive_n_unified_export(historical,eight,9001_int64,0d0,theta, &
      'historical-unified.txt','1900-01-01',historical_plan,eight_n,eight_bound, &
      historical_tcsf,historical_lai,status,input_line)
   call require(status==0.and.eight_n%ready().and.historical_plan%ready(), &
      'unified original-material and eight-pool source accepted in actual Richards owner')
   block
     type(crop_n_configuration_t)::crop_profile,crop_initialized
     type(crop_senescence_policy_t)::death_policy
     allocate(crop_profile%harvest)
     crop_profile%harvest%sw_wofost=1
     call initialize_historical_crop_soil_project(historical,eight,crop_profile,9001_int64, &
       0d0,theta,'historical-unified.txt','1900-01-01',historical_plan,eight_n, &
       eight_bound,crop_initialized,death_policy,status,input_line)
     call require(status==0.and.eight_n%ready().and.historical_plan%ready(), &
       'same-file historical project initializes crop and soil together')
     call require(all(death_policy%application_age==[1.27d0,.99d0,1.27d0]), &
       'historical crop senescence policy bound by project')
     call require(all(crop_initialized%harvest%policy%application_age== &
       [1.27d0,.99d0,1.27d0,1.27d0]),'historical project harvest policy')
     call require(crop_initialized%tcsf_n==historical_tcsf.and. &
       crop_initialized%lai_crit_nupt==historical_lai,'project crop-N supply parameters')
     deallocate(crop_profile%harvest)
     call initialize_historical_crop_soil_project(historical,eight,crop_profile,9001_int64, &
       0d0,theta,'historical-unified.txt','1900-01-01',historical_plan,eight_n, &
       eight_bound,crop_initialized,death_policy,status,input_line)
     call require(status/=0.and..not.eight_n%ready().and..not.historical_plan%ready(), &
       'invalid crop owner rejects combined project without partial soil/calendar')

   end block
   ! Late malformed parameter after valid management rows must publish no owner or calendar.
   open(newunit=input_unit,file='historical-unified.txt',position='append')
   write(input_unit,'(A)')'FOM1_t = 1.0'
   close(input_unit)
   call initialize_historical_reactive_n_unified_export(historical,eight,9001_int64,0d0,theta, &
      'historical-unified.txt','1900-01-01',historical_plan,eight_n,eight_bound, &
      historical_tcsf,historical_lai,status,input_line)
   call require(status/=0.and..not.eight_n%ready().and..not.historical_plan%ready(), &
      'unified malformed late record returns no partial committed owner or calendar')

   call initialize_historical_reactive_n_named_files(historical,eight,9001_int64,0d0,theta, &
      'historical-params.txt','historical-actual-input.snm','1900-01-01',historical_plan, &
      eight_n,eight_bound,historical_tcsf,historical_lai,status,input_line)
   call require(status==0.and.eight_n%ready().and.historical_plan%ready(), &
     'named historical file accepted by real Richards owner')
   call require(all(abs(eight_bound%organic_reference%ratecon_fom(1:4)-3d0/365.2425d0)<1d-15), &
     'historical source fast organic kinetics in actual owner')
   call require(all(abs(eight_bound%organic_reference%ratecon_fom(5:8)-.3d0/365.2425d0)<1d-15), &
     'historical source slow organic kinetics in actual owner')
   call require(all(eight_bound%mineral%inventory%nfrac_fom==[.06d0,.002d0,.06d0,.002d0, &
      .06d0,.002d0,.06d0,.002d0]),'historical eight FOM N signatures')
   call require(abs(eight_bound%organic_reference%asfa_bio-.092d0)<1d-15, &
      'historical original biomass routing')

   call require(status==0.and.eight_n%ready().and.historical_plan%ready(),'eight-pool positive source activation')
   call fmr_new_b110_temporal_indicator_committed_state(eight_water,column%column_id, &
     cfg%tiles(1)%initial_state,0d0,ok,spread(0d0,1,numnod))
   call require(ok,'eight-pool water state')
   call run_reactive_n_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters, &
     eight_water,cfg%tiles(1)%base_forcing,cfg%numerical,eight_n,0d0,1d0,eight_result)
   call require(eight_result%status==JOINT_OK,'eight-pool actual Richards accepted')
   call require(abs(eight_result%chemical%residual)<=1d-12,'eight-pool whole N')
   call eight_n%snapshot(et,ew,eight_after,erev)
   call require(et==1d0.and.erev==1,'eight-pool committed time and revision')
   call require(size(eight_after%fom_kg_m3)==8,'eight-pool retained physical inventory')
 end block
 ! Recreate the already-qualified two-pool owner for incumbent Richards execution.
 call initialize_historical_reactive_n_from_tables(historical,p,pools,9001_int64,0d0,theta, &
   'historical-actual-input.snm','1900-01-01',historical_plan,nitrogen,status,input_line)
 call require(status==0.and.nitrogen%ready().and.historical_plan%ready(), &
   'incumbent historical reader restored after rejected complete route')

 initial_water=water;initial_n=nitrogen
 ! Invalid water forcing does not mutate either committed owner.
 invalid=cfg%tiles(1)%base_forcing;invalid%root_extraction_sink=-1d0
 call run_reactive_n_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,water, &
   invalid,cfg%numerical,nitrogen,0d0,1d0,result)
 call require(result%status/=0,'hydraulic rejection');call unchanged()
 ! A valid water trial with unsupported chemical carrier must also roll back.
 invalid=cfg%tiles(1)%base_forcing;invalid%top_flux=-.001d0
 call run_reactive_n_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,water, &
   invalid,cfg%numerical,nitrogen,0d0,1d0,result)
 call require(result%status==JOINT_CHEMICAL_REJECTED,'N rejects successful unsupported hydraulic trial');call unchanged()
 block
   type(reactive_state_t)::bad_n
   type(kernel_committed_state_t)::bad_w
   pbad=p;pbad%organic_reference%ratecon_bio=0d0;pbad%organic_reference%ratecon_hum=0d0
   call initialize_reactive(pbad,9001_int64,0d0,theta,pools,bad_n,status)
   call require(status==0,'singular process configuration is staged, not executed by constructor')
   bad_w=water
   call run_reactive_n_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,bad_w, &
       cfg%tiles(1)%base_forcing,cfg%numerical,bad_n,0d0,1d0,result)
   call require(result%status==JOINT_CHEMICAL_REJECTED,'organic-process rejection rolls water back')
   call require(bad_w%current_revision()==water%current_revision(),'organic failure no water revision')
   call bad_n%snapshot(time,theta,s,revision)
   call require(time==0d0.and.revision==0.and.all(s%fom_kg_m3==pools%fom_kg_m3),'organic failure no N revision/store')
 end block
 call run_reactive_n_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,water, &
   cfg%tiles(1)%base_forcing,cfg%numerical,nitrogen,0d0,1d0,result)
 if(result%status/=0)print *,'diagnostics',result%status,result%water%status,result%chemical%status,result%chemical%residual
 call require(result%status==0,'one-day actual Richards and N retry')
 call require(abs(result%chemical%residual)<=1d-12,'whole N hard budget')
 call require(result%chemical%external_out>0d0.and.result%chemical%external_in==0d0,'actual outflow plus gas receipt')
 call nitrogen%snapshot(time,theta,s,revision)
 call require(time==1d0.and.revision==1,'consumed daily clock')
 call require(any(s%fom_kg_m3<pools%fom_kg_m3),'actual organic turnover')
 call carrier_controls()
 call export_reactive_n_joint_restart(column,cfg%tiles(1)%template,670001_int64,water,nitrogen,payload,status)
 call require(status==0,'joint opaque export')
 call restore_reactive_n_joint_restart(payload,column,cfg%tiles(1)%template,670001_int64,9002_int64,other_water,other_n,status)
 call require(status/=0.and..not.other_water%ready().and..not.other_n%ready(),'wrong identity atomic opaque rejection')
 call restore_reactive_n_joint_restart(payload,column,cfg%tiles(1)%template,670001_int64,9001_int64,other_water,other_n,status)
 call require(status==0,'joint opaque restore')
 call write_reactive_n_joint_restart_file(trim(path),column,cfg%tiles(1)%template,670001_int64,water,nitrogen,status)
 call require(status==0,'joint disk export')
 block
   type(kernel_committed_state_t)::empty_water
   type(reactive_state_t)::empty_n
   pbad=p;pbad%mineral%sorption=p%mineral%sorption*2d0
   call read_reactive_n_joint_restart_file(trim(path),column,cfg%tiles(1)%template,670001_int64,9001_int64,pbad,empty_water,empty_n,status)
   call require(status/=0.and..not.empty_water%ready().and..not.empty_n%ready(),'same id different parameters')
   call read_reactive_n_joint_restart_file(trim(path),column,cfg%tiles(1)%template,670002_int64,9001_int64,p,empty_water,empty_n,status)
   call require(status/=0,'wrong water identity')
 end block
 call second_day(backend,water,nitrogen)
 call second_day(second,other_water,other_n)
 call write_reactive_n_joint_restart_file(trim(endpoint),column,cfg%tiles(1)%template,670001_int64,water,nitrogen,status)
 call require(status==0,'normal endpoint')
 call write_reactive_n_joint_restart_file(trim(endpoint)//'.opaque',column,cfg%tiles(1)%template,670001_int64,other_water,other_n,status)
 call require(status==0,'opaque endpoint')
 print '(A)','REACTIVE_ACTUAL_RICHARDS_DAILY_ATOMIC_OPAQUE_DISK=PASS'
contains
 subroutine off_mode_contract()
   type(kernel_committed_state_t)::w1,w2
   type(mineral_state_t)::n1,base
   type(reactive_state_t)::n2
   type(reactive_parameters_t)::offp
   type(mineral_joint_result_t)::r1
   type(reactive_n_joint_result_t)::r2
   integer::code
   real(real64)::water0
   logical::available
   offp=p;offp%enabled=.false.
   water0=sum(dz*cfg%tiles(1)%initial_state%water_content)/sum(dz)
   call fmr_new_b110_temporal_indicator_committed_state(w1,column%column_id,cfg%tiles(1)%initial_state,0d0,available,spread(0d0,1,numnod))
   call require(available,'off water initialization');w2=w1
   call initialize_mineral(p%mineral,9001_int64,0d0,water0,pools,n1,code)
   call require(code==0,'off base N initialization')
   call initialize_reactive(offp,9001_int64,0d0,water0,pools,n2,code)
   call require(code==0,'off reactive initialization')
   call run_mineral_joint_interval(second,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,w1,cfg%tiles(1)%base_forcing, &
       cfg%numerical,n1,0d0,1d0,r1)
   call run_reactive_n_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,w2,cfg%tiles(1)%base_forcing, &
       cfg%numerical,n2,0d0,1d0,r2)
   call require(r1%status==0.and.r2%status==0.and..not.r2%chemical%reactions_executed,'off actual water route')
   call n2%mineral_snapshot(base)
   call write_mineral_joint_restart_file(trim(endpoint)//'.off-old',column,cfg%tiles(1)%template,670001_int64,w1,n1,code)
   call require(code==0,'off original endpoint')
   call write_mineral_joint_restart_file(trim(endpoint)//'.off-new',column,cfg%tiles(1)%template,670001_int64,w2,base,code)
   call require(code==0,'off reactive endpoint')
   print '(A)','REACTIVE_OFF_ACTUAL_MINERAL_EQUIVALENCE=PASS'
 end subroutine
 subroutine carrier_controls()
   type(fmr_serialized_physical_observation_t)::obs
   type(fmr_water_flux_substep_trace_t),allocatable::steps(:)
   type(reactive_state_t)::trial
   type(reactive_receipt_t)::r
   type(soil_n_pool_state_t)::before,after
   real(real64)::t,w,v,root,net_out,nit,denit,carbon,nan
   type(soil_n_pool_state_t)::expected
   integer(int64)::rev
   integer::i,j
   obs=backend%observation()
   call require(obs%accepted_water_flux_trace_available,'actual carrier available')
   call initial_n%snapshot(t,w,before,rev)
   call nitrogen%snapshot(t,v,after,rev)
   root=0d0
   do j=1,size(obs%accepted_water_flux_substeps)
     associate(q=>obs%accepted_water_flux_substeps(j))
       root=root+(q%t1-q%t0)*sum(q%root_sink)*.01d0
     end associate
   end do
   net_out=(w-v)*p%mineral%inventory%depth_m-root
   call require(net_out>0d0.and.root>0d0,'actual outflow and root water')
   call literal_day(p,before,w,v,net_out,0d0,0d0,root,expected,nit,denit,carbon)
   call require(all(abs(after%fom_kg_m3-expected%fom_kg_m3)<=1d-12),'actual literal FOM')
   call require(abs(after%biomass_kg_m3-expected%biomass_kg_m3)<=1d-12,'actual literal biomass')
   call require(abs(after%humus_kg_m3-expected%humus_kg_m3)<=1d-12,'actual literal humus')
   call require(abs(after%ammonium_n_kg_m2-expected%ammonium_n_kg_m2)<=1d-12,'actual literal NH4')
   call require(abs(after%nitrate_n_kg_m2-expected%nitrate_n_kg_m2)<=1d-12,'actual literal NO3')
   call require(abs(result%chemical%process%exchange%nh4_nitrified_kg_m2-nit)<=1d-12,'actual literal nitrification')
   call require(abs(result%chemical%process%exchange%no3_denitrified_kg_m2-denit)<=1d-12,'actual literal denitrification')
   call require(abs(result%chemical%process%dissimilation%carbon_dissimilation_kg_m2-carbon)<=1d-12,'actual literal C')
   call require(nit>0d0.and.denit>0d0.and.carbon>0d0,'all daily reaction pathways active')
   nan=ieee_value(0d0,ieee_quiet_nan)
   do i=1,9
     steps=obs%accepted_water_flux_substeps;trial=initial_n
     select case(i)
     case(1);steps(1)%t0=steps(1)%t0+.01d0
     case(2);deallocate(steps(1)%water_start)
     case(3);steps(1)%water_start(1)=nan
     case(4);steps(1)%bottom_flux=huge(0d0)
     case(5);steps(1)%net_node_source(1)=1d0
     case(6);steps(1)%top_flux=-.01d0
     case(7)
       if(allocated(steps(1)%subsurface_source))deallocate(steps(1)%subsurface_source)
       allocate(steps(1)%subsurface_source(numnod));steps(1)%subsurface_source=1d0
     case(8)
       if(allocated(steps(1)%macropore_matrix_exchange))deallocate(steps(1)%macropore_matrix_exchange)
       allocate(steps(1)%macropore_matrix_exchange(numnod));steps(1)%macropore_matrix_exchange=1d0
     case(9);steps(size(steps))%t1=huge(0d0)
     end select
     call consume_reactive_n_trace(trial,steps,r);call require(r%status/=0,'malformed carrier rejected')
     call trial%snapshot(t,v,after,rev)
     call require(t==0d0.and.rev==0.and.v==w.and.after%ammonium_n_kg_m2==before%ammonium_n_kg_m2.and. &
        after%nitrate_n_kg_m2==before%nitrate_n_kg_m2,'malformed carrier atomic rollback')
   end do
   print '(A)','REACTIVE_ACTUAL_LITERAL_AND_NINE_CARRIER_NEGATIVES=PASS'
 end subroutine
 subroutine unchanged()
   type(soil_n_pool_state_t)::x
   real(real64)::t,w
   integer(int64)::rev
   call require(water%current_revision()==initial_water%current_revision(),'water revision rolled back')
   call nitrogen%snapshot(t,w,x,rev)
   call require(t==0d0.and.rev==0.and.x%ammonium_n_kg_m2==pools%ammonium_n_kg_m2.and. &
     x%nitrate_n_kg_m2==pools%nitrate_n_kg_m2,'N rolled back')
   call require(reactive_n_joint_states_match(water,nitrogen),'joint state remains matched')
 end subroutine
 subroutine second_day(b,w,n)
   type(fmr_serialized_reference_backend_t),intent(inout)::b
   type(kernel_committed_state_t),intent(inout)::w
   type(reactive_state_t),intent(inout)::n
   type(fmr_b110_physical_forcing_t)::forcing
   type(reactive_n_joint_result_t)::r
   forcing=cfg%tiles(1)%base_forcing;forcing%bottom_flux=.1d0;forcing%drainage_flux_by_level=0d0
   call run_reactive_n_joint_interval(b,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,forcing,cfg%numerical,n,1d0,2d0,r)
   if(r%status/=0)print *,'day2 diagnostics',r%status,r%water%status,r%chemical%status,r%chemical%residual
   call require(r%status==0,'actual inflow continuation')
   call require(r%chemical%external_in>0d0.and.r%chemical%process%exchange%no3_denitrified_kg_m2>0d0,'actual inflow plus gas loss')
   call require(abs(r%chemical%residual)<=1d-12,'day2 whole N')
 end subroutine
 subroutine require(ok,label)
   logical,intent(in)::ok
   character(*),intent(in)::label
   if(.not.ok)then;print '(A)','FAIL '//label;error stop 1;end if
 end subroutine
 include 'reactive_parameters.inc'
 include 'reactive_oracle.inc'
 include 'matrix_fixture.inc'
end program
