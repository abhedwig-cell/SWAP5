program test_a27_abc01_transition
 use,intrinsic::iso_fortran_env,only:int64,real64
 use MOD_grid,only:numnod,z,dz,disnod
 use mod_transaction_reference,only:transaction_state_t,TX_TEMPORAL_EXTERNAL_FULL_HALF
 use mod_canonical_contracts,only:canonical_numerical_config_t,CANONICAL_STATUS_COMPLETED
 use mod_kernel_transactions,only:kernel_committed_state_t,kernel_checkpoint_t,kernel_result_t,kernel_candidate_state_t,kernel_diagnostics_t
 use mod_fmr_runtime_core,only:fmr_logical_column_t,fmr_template_t,FMR_BACKEND_SERIALIZED_REFERENCE,FMR_NUMERICAL_CONTINUATION_NONE,FMR_OPTIONAL_STATE_LAYOUT_RFM
 use mod_fmr_checkpoint_orchestrator,only:fmr_capture_checkpoint
 use mod_fmr_serialized_reference_backend,only:fmr_b110_physical_parameters_t,fmr_b110_physical_forcing_t,fmr_b110_physical_state_t, &
      fmr_b110_rfm_state_t,fmr_serialized_reference_backend_t,fmr_new_b110_rfm_committed_state
 use mod_rfm_runtime_configuration,only:rfm_runtime_configuration_t
 use mod_rfm_physical_state,only:rfm_physical_state_t
 use mod_rfm_live_trial_preparer,only:rfm_live_trial_prepare_result_t,prepare_rfm_live_trial
 use mod_rfm_surface_forcing,only:rfm_surface_forcing_t
 use mod_process_hydraulic_view,only:process_hydraulic_view_t
 use mod_soil_water_solver_contract,only:soil_water_parameter_set_t,soil_water_solve_request_t,soil_water_solve_result_t, &
      soil_water_top_boundary_result_t,SW_SOLVE_CONVERGED,SW_TOP_BOUNDARY_AVAILABLE,SW_TOP_BOUNDARY_REGIME_FLUX
 use mod_reference_richards_legacy_binding,only:reference_richards_legacy_solver_t,reference_richards_legacy_workspace_t
 use mod_reference_richards_state_binding,only:FSI_TOP_MODE_EXPLICIT_FLUX
 use mod_b110_default_mvg_provider,only:b110_default_mvg_parameters_t,b110_default_mvg_provider_t, &
      initialize_b110_default_mvg_parameters,bind_b110_default_mvg_provider
 use mod_b110_source_sink_provider,only:b110_source_sink_provider_t,bind_b110_source_sink_provider
 use mod_rfm_matrix_source_provider,only:rfm_matrix_source_provider_t,bind_rfm_matrix_source_provider
 use mod_fixed_flux_top_boundary_provider,only:fixed_flux_top_boundary_provider_t
 implicit none
 real(real64),parameter::DT=.01_real64
 real(real64),parameter::scales(5)=[1._real64,.5_real64,.25_real64,.125_real64,0._real64]
 real(real64),parameter::dts(5)=[.01_real64,.005_real64,.0025_real64,.00125_real64,.000625_real64]
 type(fmr_serialized_reference_backend_t)::backend
 type(fixed_flux_top_boundary_provider_t),target::top
 type(fmr_b110_physical_parameters_t),target::p
 type(fmr_b110_physical_forcing_t)::forcing
 type(fmr_b110_physical_state_t)::base
 type(rfm_physical_state_t)::rfm
 type(rfm_runtime_configuration_t)::cfg
 type(fmr_logical_column_t)::column
 type(fmr_template_t)::template
 type(canonical_numerical_config_t)::cn
 type(kernel_committed_state_t)::committed
 type(kernel_checkpoint_t)::checkpoint
 type(kernel_result_t)::kr
 type(kernel_candidate_state_t)::kc
 type(kernel_diagnostics_t)::kd
 class(transaction_state_t),allocatable::snap
 type(b110_default_mvg_parameters_t),target::hp
 type(b110_default_mvg_provider_t),target::hyd
 type(process_hydraulic_view_t)::view
 type(soil_water_top_boundary_result_t)::preflight
 type(rfm_surface_forcing_t)::dry_surface
 type(rfm_live_trial_prepare_result_t)::live
 real(real64)::heads(numnod),theta(numnod),cond(numnod),cap(numnod),dkdh(numnod)
 logical::ok,available,did_commit
 integer::step,commit_status,i
 real(real64),allocatable::accepted_h(:),accepted_theta(:),source(:)
 type(rfm_physical_state_t)::accepted_rfm

 call init_parameters(p)
 call initialize_b110_default_mvg_parameters(hp,p%cofgen)
 call bind_b110_default_mvg_provider(hyd,hp,DT)
 heads=-150._real64-z
 call hyd%evaluate(heads,theta,cond,cap,dkdh)
 base%active_nodes=numnod;allocate(base%pressure_head(numnod),base%water_content(numnod))
 base%pressure_head=heads;base%water_content=theta;base%ponding_depth=0._real64;base%groundwater_level=-150._real64
 call init_rfm_config(cfg)
 call rfm%initialize(1,ok);if(.not.ok)error stop 'rfm init'

 call backend%initialize(top)
 call backend%configure_rfm_runtime(cfg,ok);if(.not.ok)error stop 'rfm config'
 template%template_id=527901_int64;template%physics_topology_id=527902_int64;template%vertical_layout_id=527903_int64
 template%state_layout_id=527904_int64;template%solver_interface_id=527905_int64
 template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_RFM;template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
 template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
 column%column_id=527901_int64;column%template_id=template%template_id;column%parameter_ref=1_int64
 column%state_handle=1_int64;column%forcing_handle=1_int64;column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
 cn%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF;cn%transaction%temporal_tolerance=1._real64
 cn%transaction%mass_tolerance=1e-7_real64;cn%transaction%retry_scale=.5_real64;cn%transaction%max_retries=4
 cn%max_committed_substeps=32;cn%progress_tolerance=0._real64
 call fmr_new_b110_rfm_committed_state(committed,column%column_id,base,rfm,0._real64,ok);if(.not.ok)error stop 'committed'

 do step=1,4
   call init_forcing(forcing,8._real64,.true.)
   call fmr_capture_checkpoint(committed,checkpoint,ok);if(.not.ok)error stop 'checkpoint wet'
   call backend%run_trial(column,template,p,committed,forcing,cn,real(step-1,real64)*DT,real(step,real64)*DT,checkpoint,kr,kc,kd)
   if(.not.kr%completed.or.kr%status/=CANONICAL_STATUS_COMPLETED)error stop 'wet production C failed before transition'
   call backend%commit_trial_candidate(committed,kc,kd,did_commit,commit_status);if(.not.did_commit)error stop 'wet commit'
 enddo

 call committed%snapshot(snap,available);if(.not.available)error stop 'accepted snapshot'
 select type(s=>snap)
 type is(fmr_b110_rfm_state_t)
   accepted_h=s%pressure_head;accepted_theta=s%water_content;accepted_rfm=s%rfm
   view%active_nodes=s%active_nodes;allocate(view%pressure_head(numnod),view%water_content(numnod))
   view%pressure_head=s%pressure_head;view%water_content=s%water_content
   view%ponding_depth=s%ponding_depth;view%groundwater_level=s%groundwater_level
 class default
   error stop 'accepted RFM state type'
 end select

 preflight%status=SW_TOP_BOUNDARY_AVAILABLE;preflight%regime=SW_TOP_BOUNDARY_REGIME_FLUX
 preflight%carries_surface_mass_terms=.true.;preflight%runoff_resolved=.true.
 preflight%candidate_ponding_depth=0._real64;preflight%runoff_depth=0._real64;preflight%net_potential_surface_flux=0._real64
 dry_surface=rfm_surface_forcing_t();dry_surface%supplied=.true.;dry_surface%event_active=.false.;dry_surface%runoff_exponent=1._real64
 call bind_b110_default_mvg_provider(hyd,hp,DT)
 call prepare_rfm_live_trial(accepted_rfm,cfg,dry_surface,view,hyd,preflight,abs(z),dz,DT,1e-8_real64,live)
 if(.not.live%valid)error stop 'dry live prepare'
 source=live%candidate%matrix_source_rate_per_day
 write(*,'(*(g0,:,","))') 'ACCEPTED',accepted_rfm%endpoint_water_cm(1),accepted_rfm%wall_age_day(1), &
      accepted_rfm%wall_sorptivity_cm_sqrt_day(1),accepted_h(6),accepted_theta(6),accepted_rfm%tau_surface_day
 write(*,'(*(g0,:,","))') 'DRY_RELEASE',DT,live%candidate%endpoint_release%release_total_cm,sum(source),source(6), &
      live%candidate%candidate_rfm%endpoint_water_cm(1),live%candidate%candidate_rfm%tau_surface_day

 call init_forcing(forcing,0._real64,.false.)
 call fmr_capture_checkpoint(committed,checkpoint,ok);if(.not.ok)error stop 'checkpoint dry'
 call backend%run_trial(column,template,p,committed,forcing,cn,.04_real64,.05_real64,checkpoint,kr,kc,kd)
 write(*,'(*(g0,:,","))') 'PRODUCTION_DRY',kr%status,merge(1,0,kr%completed),kd%attempts,kd%retries,kd%solver_rejections, &
      kd%temporal_rejections,kd%mass_rejections,kd%nonlinear_iterations,kd%backtracking_attempts,kd%headcalc_calls

 do i=1,size(scales)
   call direct_solve(DT,scales(i)*source,accepted_h,accepted_theta,kr_status_dummy=step)
 enddo

 do i=1,size(dts)
   call bind_b110_default_mvg_provider(hyd,hp,dts(i))
   call prepare_rfm_live_trial(accepted_rfm,cfg,dry_surface,view,hyd,preflight,abs(z),dz,dts(i),1e-8_real64,live)
   if(.not.live%valid)error stop 'dt live prepare'
   source=live%candidate%matrix_source_rate_per_day
   write(*,'(*(g0,:,","))') 'DT_RELEASE',dts(i),live%candidate%endpoint_release%release_total_cm,sum(source),source(6)
   call direct_solve(dts(i),source,accepted_h,accepted_theta,kr_status_dummy=step,tag='DT_SOLVE')
 enddo
 print '(a)','A27_ABC01_TR01_EXECUTED=PASS'

contains

 subroutine direct_solve(dt,src,h0,t0,kr_status_dummy,tag)
   real(real64),intent(in)::dt,src(:),h0(:),t0(:)
   integer,intent(out)::kr_status_dummy
   character(len=*),intent(in),optional::tag
   type(soil_water_parameter_set_t),target::sp
   type(b110_default_mvg_parameters_t),target::lhp
   type(b110_default_mvg_provider_t),target::lhyd
   type(b110_source_sink_provider_t),target::bss
   type(rfm_matrix_source_provider_t),target::rss
   type(fixed_flux_top_boundary_provider_t),target::ltop
   type(reference_richards_legacy_solver_t)::solver
   type(reference_richards_legacy_workspace_t)::ws
   type(soil_water_solve_request_t)::q
   type(soil_water_solve_result_t)::r
   real(real64),allocatable,target::qdra(:,:),qssdi(:),qrot(:)
   logical::lok
   character(len=16)::label
   integer::j
   label='SCALE_SOLVE';if(present(tag))label=tag
   sp%parameter_set_id=p%parameter_set_id;sp%active_nodes=numnod;sp%z=p%z;sp%dz=p%dz;sp%node_distance=p%node_distance
   call initialize_b110_default_mvg_parameters(lhp,p%cofgen);call bind_b110_default_mvg_provider(lhyd,lhp,dt)
   allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod));qdra=0._real64;qssdi=0._real64;qrot=0._real64
   call bind_b110_source_sink_provider(bss,qdra,qssdi,qrot)
   call bind_rfm_matrix_source_provider(rss,bss,src,lok);if(.not.lok)error stop 'direct source bind'
   q%parameters=>sp;q%step_duration=dt;q%base_state%active_nodes=numnod
   allocate(q%base_state%pressure_head(numnod),q%base_state%water_content(numnod))
   q%base_state%pressure_head=h0;q%base_state%water_content=t0;q%base_state%ponding_depth=0._real64;q%base_state%groundwater_level=-150._real64
   q%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX;q%boundary%top_flux=0._real64;q%boundary%bottom_mode=7
   q%boundary%top_head=0._real64;q%boundary%bottom_head=0._real64;q%boundary%bottom_flux=0._real64
   q%physical%macropore_active=.false.;q%numerical%max_iterations=64;q%numerical%max_backtracking=24
   q%numerical%conductivity_implicit_mode=0;q%numerical%conductivity_mean_method=1;q%numerical%min_step_duration=1e-12_real64
   q%numerical%compartment_balance_tolerance=1e-8_real64;q%numerical%total_balance_tolerance=1e-8_real64
   q%numerical%head_abs_tolerance=1e-8_real64;q%numerical%head_rel_tolerance=1e-8_real64;q%numerical%ponding_tolerance=1e-8_real64
   q%evaluation%constitutive=>lhyd;q%evaluation%source_sink=>rss;q%evaluation%top_boundary=>ltop
   call solver%solve(q,ws,r)
   kr_status_dummy=r%status
   write(*,'(*(g0,:,","))') trim(label),dt,sum(src),r%status,r%diagnostics%nonlinear_iterations,r%diagnostics%backtracking_attempts, &
        merge(r%integrated_mass_balance_residual_cm,huge(0._real64),r%integrated_mass_balance_residual_available)
 end subroutine direct_solve

 subroutine init_parameters(x)
   type(fmr_b110_physical_parameters_t),intent(out)::x
   integer::j
   x%parameter_set_id=527911_int64;x%active_nodes=numnod;allocate(x%z(numnod),x%dz(numnod),x%node_distance(numnod),x%cofgen(24,numnod))
   x%z=z;x%dz=dz;x%node_distance=disnod(1:numnod);x%cofgen=0._real64
   do j=1,numnod
    x%cofgen(1,j)=.02_real64;x%cofgen(2,j)=.42749391_real64;x%cofgen(3,j)=31.22501566_real64
    x%cofgen(4,j)=.02165898_real64;x%cofgen(5,j)=.98087016_real64;x%cofgen(6,j)=1.73473668_real64
    x%cofgen(7,j)=1._real64-1._real64/x%cofgen(6,j);x%cofgen(8,j)=x%cofgen(4,j)
    x%cofgen(10,j)=x%cofgen(3,j);x%cofgen(11,j)=.999_real64;x%cofgen(12,j)=.99_real64*x%cofgen(3,j)
    x%cofgen(22,j)=-1e6_real64;x%cofgen(23,j)=1e-12_real64
   enddo
   x%bottom_mode=7;x%swkimpl=0;x%swkmean=1;x%swsophy=0;x%max_iterations=64;x%max_backtracking=24;x%min_step_duration=1e-12_real64
   x%compartment_balance_tolerance=1e-8_real64;x%total_balance_tolerance=1e-8_real64;x%head_abs_tolerance=1e-8_real64
   x%head_rel_tolerance=1e-8_real64;x%ponding_tolerance=1e-8_real64
 end subroutine init_parameters

 subroutine init_rfm_config(x)
   type(rfm_runtime_configuration_t),intent(out)::x
   x%enabled=.true.;x%sigma_b=.65_real64;x%f_mb=.25_real64;x%connectivity_p=1._real64
   x%z_ah_cm=20._real64;x%z_ic_cm=60._real64;x%chi_wall=1._real64;x%exchange_length_cm=20._real64;x%mb_contact_length_cm=80._real64
   x%sorptivity_panels=64;x%mb_wall_node_index=10
   x%endpoint_depth_cm=[60._real64];x%endpoint_contact_thickness_cm=[20._real64];x%endpoint_area_fraction=[.0375_real64];x%endpoint_node_index=[6]
 end subroutine init_rfm_config

 subroutine init_forcing(f,rain,event)
   type(fmr_b110_physical_forcing_t),intent(out)::f
   real(real64),intent(in)::rain
   logical,intent(in)::event
   f=fmr_b110_physical_forcing_t();f%top_flux=0._real64;f%top_head=0._real64;f%bottom_flux=0._real64;f%bottom_head=0._real64
   allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod),f%rfm_surface)
   f%drainage_flux_by_level=0._real64;f%subsurface_irrigation_source=0._real64;f%root_extraction_sink=0._real64
   f%rfm_surface%supplied=.true.;f%rfm_surface%event_active=event;f%rfm_surface%precipitation_rate_cm_per_day=rain
   f%rfm_surface%ponding_max_cm=0._real64;f%rfm_surface%runoff_resistance_day=0._real64;f%rfm_surface%runoff_exponent=1._real64
 end subroutine init_forcing
end program
