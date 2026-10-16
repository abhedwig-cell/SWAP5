program test_mineral_joint
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
 use mod_soil_n_pool_state
 use mod_fmr_b111_mineral_joint_application
 use mod_mineral_joint_restart_file
 use mod_fmr_b111_mineral_route,only:consume_mineral_trace
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use MOD_texture_orgmat,only:bdens
 implicit none
 real(real64),parameter::T0=0d0,T1=1d0,HARD_MASS_GATE=1d-10
 type(fmr_production_application_config_t)::cfg
 type(fmr_serialized_reference_backend_t)::backend,second
 type(fixed_flux_top_boundary_provider_t),target::top
 type(fmr_logical_column_t)::column
 type(kernel_committed_state_t)::water,other_water,initial_water
 type(mineral_state_t)::nitrogen,other_n,initial_n
 type(mineral_joint_restart_t)::payload
 type(mineral_joint_result_t)::result
 type(mineral_parameters_t)::p,pbad
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
 p%dz_cm=dz;p%inventory%depth_m=sum(dz)*.01d0;p%inventory%nfrac_fom=[.01d0,.02d0]
 p%inventory%nfrac_biomass=.03d0;p%inventory%nfrac_humus=.04d0
 p%drybd=1300d0;p%sorption=.0002d0;p%c_bottom=[.1d0,.2d0];p%c_lateral=[.3d0,.4d0]
 call initialize_soil_n_pool_state(p%inventory,[10d0,20d0],5d0,40d0,.02d0,.03d0,pools,status)
 call require(status==0,'inventory initialization')
 call backend%initialize(top);call second%initialize(top)
 if(trim(mode)=='reject')then
   call read_mineral_joint_restart_file(trim(path),column,cfg%tiles(1)%template,670001_int64,9001_int64,p,water,nitrogen,status)
   call require(status/=0.and..not.water%ready().and..not.nitrogen%ready(),'invalid disk atomic rejection')
   print '(A)','MINERAL_INVALID_DISK=PASS';stop
 end if
 if(trim(mode)=='resume')then
   call read_mineral_joint_restart_file(trim(path),column,cfg%tiles(1)%template,670001_int64,9001_int64,p,water,nitrogen,status)
   call require(status==0,'fresh-process disk reconstruction')
   call second_day(backend,water,nitrogen)
   call write_mineral_joint_restart_file(trim(endpoint),column,cfg%tiles(1)%template,670001_int64,water,nitrogen,status)
   call require(status==0,'fresh endpoint')
   print '(A)','MINERAL_FRESH_PROCESS_CONTINUATION=PASS';stop
 end if
 call fmr_new_b110_temporal_indicator_committed_state(water,column%column_id,cfg%tiles(1)%initial_state,0d0,ok, &
   spread(0d0,1,numnod));call require(ok,'water initialization')
 theta=sum(dz*cfg%tiles(1)%initial_state%water_content)/sum(dz)
 call initialize_mineral(p,9001_int64,0d0,theta,pools,nitrogen,status);call require(status==0,'N initialization')
 initial_water=water;initial_n=nitrogen
 ! Invalid water forcing does not mutate either committed owner.
 invalid=cfg%tiles(1)%base_forcing;invalid%root_extraction_sink=-1d0
 call run_mineral_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,water, &
   invalid,cfg%numerical,nitrogen,0d0,1d0,result)
 call require(result%status/=0,'hydraulic rejection');call unchanged()
 ! A valid water trial with unsupported chemical carrier must also roll back.
 invalid=cfg%tiles(1)%base_forcing;invalid%top_flux=-.001d0
 call run_mineral_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,water, &
   invalid,cfg%numerical,nitrogen,0d0,1d0,result)
 call require(result%status==JOINT_CHEMICAL_REJECTED,'N rejects successful unsupported hydraulic trial');call unchanged()
 call run_mineral_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,water, &
   cfg%tiles(1)%base_forcing,cfg%numerical,nitrogen,0d0,1d0,result)
 if(result%status/=0)print *,'diagnostics',result%status,result%water%status,result%chemical%status,result%chemical%residual
 call require(result%status==0,'one-day actual Richards and N retry')
 call require(abs(result%chemical%residual)<=1d-12,'whole N hard budget')
 call require(result%chemical%external_out>0d0.and.result%chemical%external_in==0d0,'actual outflow receipt')
 call nitrogen%snapshot(time,theta,s,revision)
 call require(time==1d0.and.revision==1,'consumed daily clock')
 call require(all(s%fom_kg_m3==pools%fom_kg_m3).and.s%humus_kg_m3==pools%humus_kg_m3.and. &
   s%biomass_kg_m3==pools%biomass_kg_m3,'no organic turnover')
 call carrier_controls()
 call export_mineral_joint_restart(column,cfg%tiles(1)%template,670001_int64,water,nitrogen,payload,status)
 call require(status==0,'joint opaque export')
 call restore_mineral_joint_restart(payload,column,cfg%tiles(1)%template,670001_int64,9002_int64,other_water,other_n,status)
 call require(status/=0.and..not.other_water%ready().and..not.other_n%ready(),'wrong identity atomic opaque rejection')
 call restore_mineral_joint_restart(payload,column,cfg%tiles(1)%template,670001_int64,9001_int64,other_water,other_n,status)
 call require(status==0,'joint opaque restore')
 call write_mineral_joint_restart_file(trim(path),column,cfg%tiles(1)%template,670001_int64,water,nitrogen,status)
 call require(status==0,'joint disk export')
 block
   type(kernel_committed_state_t)::empty_water
   type(mineral_state_t)::empty_n
   pbad=p;pbad%sorption=p%sorption*2d0
   call read_mineral_joint_restart_file(trim(path),column,cfg%tiles(1)%template,670001_int64,9001_int64,pbad,empty_water,empty_n,status)
   call require(status/=0.and..not.empty_water%ready().and..not.empty_n%ready(),'same id different parameters')
   call read_mineral_joint_restart_file(trim(path),column,cfg%tiles(1)%template,670002_int64,9001_int64,p,empty_water,empty_n,status)
   call require(status/=0,'wrong water identity')
 end block
 call second_day(backend,water,nitrogen)
 call second_day(second,other_water,other_n)
 call write_mineral_joint_restart_file(trim(endpoint),column,cfg%tiles(1)%template,670001_int64,water,nitrogen,status)
 call require(status==0,'normal endpoint')
 call write_mineral_joint_restart_file(trim(endpoint)//'.opaque',column,cfg%tiles(1)%template,670001_int64,other_water,other_n,status)
 call require(status==0,'opaque endpoint')
 print '(A)','MINERAL_ACTUAL_RICHARDS_DAILY_ATOMIC_OPAQUE_DISK=PASS'
contains
 subroutine carrier_controls()
   type(fmr_serialized_physical_observation_t)::obs
   type(fmr_water_flux_substep_trace_t),allocatable::steps(:)
   type(mineral_state_t)::trial
   type(mineral_receipt_t)::r
   type(soil_n_pool_state_t)::before,after
   real(real64)::t,w,v,root,net_out,initial_c(2),sorption(2),ce,ca,pa,nan
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
   ! Independent historical management balance reconstruction (no copied face aggregation).
   net_out=(w-v)*p%inventory%depth_m-root
   call require(net_out>0d0.and.root>0d0,'actual outflow and root water')
   initial_c=[before%ammonium_n_kg_m2/(p%inventory%depth_m*(w+p%drybd*p%sorption)), &
      before%nitrate_n_kg_m2/(p%inventory%depth_m*w)]
   sorption=[p%sorption,0d0];bdens(1)=p%drybd
   do i=1,2
     call Wofost_SoilWaterN(p%inventory%depth_m,1d0,v,w,net_out,root,0d0,0d0,0d0,0d0,0d0,0d0,pa, &
       sorption(i),p%c_bottom(i),0d0,p%c_lateral(i),initial_c(i),ce,ca)
     call require(abs(ce-result%chemical%concentration_end(i))<1d-10,'actual daily literal end')
     call require(abs(ca-result%chemical%concentration_average(i))<1d-10,'actual daily literal mean')
   end do
   call require(after%ammonium_n_kg_m2/before%ammonium_n_kg_m2>after%nitrate_n_kg_m2/before%nitrate_n_kg_m2, &
     'NH4 sorption retards loss relative to NO3')
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
     call consume_mineral_trace(trial,steps,r);call require(r%status/=0,'malformed carrier rejected')
     call trial%snapshot(t,v,after,rev)
     call require(t==0d0.and.rev==0.and.v==w.and.after%ammonium_n_kg_m2==before%ammonium_n_kg_m2.and. &
        after%nitrate_n_kg_m2==before%nitrate_n_kg_m2,'malformed carrier atomic rollback')
   end do
   print '(A)','MINERAL_ACTUAL_LITERAL_AND_NINE_CARRIER_NEGATIVES=PASS'
 end subroutine
 subroutine unchanged()
   type(soil_n_pool_state_t)::x
   real(real64)::t,w
   integer(int64)::rev
   call require(water%current_revision()==initial_water%current_revision(),'water revision rolled back')
   call nitrogen%snapshot(t,w,x,rev)
   call require(t==0d0.and.rev==0.and.x%ammonium_n_kg_m2==pools%ammonium_n_kg_m2.and. &
     x%nitrate_n_kg_m2==pools%nitrate_n_kg_m2,'N rolled back')
   call require(mineral_joint_states_match(water,nitrogen),'joint state remains matched')
 end subroutine
 subroutine second_day(b,w,n)
   type(fmr_serialized_reference_backend_t),intent(inout)::b
   type(kernel_committed_state_t),intent(inout)::w
   type(mineral_state_t),intent(inout)::n
   type(fmr_b110_physical_forcing_t)::forcing
   type(mineral_joint_result_t)::r
   forcing=cfg%tiles(1)%base_forcing;forcing%bottom_flux=.1d0;forcing%drainage_flux_by_level=0d0
   call run_mineral_joint_interval(b,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,forcing,cfg%numerical,n,1d0,2d0,r)
   if(r%status/=0)print *,'day2 diagnostics',r%status,r%water%status,r%chemical%status,r%chemical%residual
   call require(r%status==0,'actual inflow continuation')
   call require(r%chemical%external_in>0d0.and.r%chemical%external_out==0d0,'actual inflow receipt')
   call require(abs(r%chemical%residual)<=1d-12,'day2 whole N')
 end subroutine
 subroutine require(ok,label)
   logical,intent(in)::ok
   character(*),intent(in)::label
   if(.not.ok)then;print '(A)','FAIL '//label;error stop 1;end if
 end subroutine
 include 'matrix_fixture.inc'
end program
