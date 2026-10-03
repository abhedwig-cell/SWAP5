! Research-only fixed-grid temporal refinement. No kernel acceptance or commit.
program top03_surface_transition
 use,intrinsic::iso_fortran_env,only:int64,real64
 use MOD_grid,only:numnod,z,dz,disnod
 use mod_soil_water_solver_contract,only:soil_water_parameter_set_t,soil_water_solve_request_t,soil_water_solve_result_t,SW_SOLVE_CONVERGED
 use mod_reference_richards_legacy_binding,only:reference_richards_legacy_solver_t,reference_richards_legacy_workspace_t
 use mod_reference_richards_state_binding,only:FSI_TOP_MODE_DYNAMIC_PROVIDER
 use mod_b110_default_mvg_provider,only:b110_default_mvg_parameters_t,b110_default_mvg_provider_t,initialize_b110_default_mvg_parameters,bind_b110_default_mvg_provider
 use mod_b110_source_sink_provider,only:b110_source_sink_provider_t,bind_b110_source_sink_provider
 use mod_b110_dynamic_top_boundary_solver_adapter,only:b110_dynamic_top_boundary_solver_provider_t,bind_b110_dynamic_top_boundary_solver_provider
 use mod_top03_observed_top,only:top03_observed_top_t,top03_top_trace_t
 use mod_fmr_top_surface_exchange,only:fmr_top_surface_exchange_t,materialize_fmr_top_surface_exchange,FMR_TOP_EXCHANGE_OK
 implicit none
 type(soil_water_parameter_set_t),target::params
 type(b110_default_mvg_parameters_t),target::hp
 type(b110_default_mvg_provider_t),target::hyd
 type(b110_source_sink_provider_t),target::source
 type(top03_observed_top_t),target::top
 type(top03_top_trace_t),target::trace
 type(reference_richards_legacy_solver_t)::solver
 type(soil_water_solve_request_t)::q
 type(soil_water_solve_result_t)::r
 type(fmr_top_surface_exchange_t)::x
 real(real64),allocatable,target::qdra(:,:),qssdi(:),qrot(:)
 real(real64)::cofgen(24,numnod),cond(numnod),cap(numnod),dkdh(numnod)
 real(real64)::theta_eval(numnod),cond_eval(numnod),cap_eval(numnod),dkdh_eval(numnod)
 real(real64)::heads(3),hstart(numnod),theta0(numnod),dt,transfer_cm,bottom_cm,resmax,cpu0,cpu1,first_cm,storage0,bottom_rate,horizon,water_diff,head_diff,previous_theta(numnod),previous_head(numnod),external_head,cv_external_total,cv_surface_resmax,cv_stage_scale
 integer::i,profile,level,steps,j,iters,done,window,stop_code,bottom_case,geometry_id,previous_steps,history,switches,external_calls,flux_calls,head_calls,evaluations,within_switches,last_regime,regime,cv_positive_steps,cv_negative_steps
 integer,parameter::bottom_modes(3)=[7,2,5]
 real(real64),parameter::stage_ramp_day=0.001953125_real64,stage_recession_start_day=0.125_real64
 logical::continued
 character(len=8)::geometry_arg
 character(len=32)::cv_stage_scale_arg
 call get_command_argument(1,geometry_arg)
 read(geometry_arg,*)geometry_id
 cv_stage_scale=1.0_real64
 call get_command_argument(2,cv_stage_scale_arg)
 if(len_trim(cv_stage_scale_arg)>0)read(cv_stage_scale_arg,*)cv_stage_scale
 heads=[-123.0_real64,-10.0_real64,0.02_real64]
 allocate(params%z(numnod),params%dz(numnod),params%node_distance(numnod))
 params%parameter_set_id=49009_int64;params%active_nodes=numnod
 params%z=z;params%dz=dz;params%node_distance=disnod(1:numnod)
 cofgen=0.0_real64
    do i=1,numnod
      cofgen(1,i)=0.032_real64; cofgen(2,i)=0.423_real64; cofgen(3,i)=4.75_real64
      cofgen(4,i)=0.0135_real64; cofgen(5,i)=0.365_real64; cofgen(6,i)=1.455_real64
      cofgen(7,i)=1.0_real64-1.0_real64/cofgen(6,i); cofgen(8,i)=cofgen(4,i)
      cofgen(9,i)=0.0_real64; cofgen(10,i)=cofgen(3,i); cofgen(11,i)=0.999_real64
      cofgen(12,i)=0.99_real64*cofgen(3,i); cofgen(22,i)=-1.0e6_real64
      cofgen(23,i)=1.0e-12_real64
    end do

 call initialize_b110_default_mvg_parameters(hp,cofgen)
 allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
 qdra=0.0_real64;qssdi=0.0_real64;qrot=0.0_real64
 call bind_b110_source_sink_provider(source,qdra,qssdi,qrot)
 q%parameters=>params;q%base_state%active_nodes=numnod
 allocate(q%base_state%pressure_head(numnod),q%base_state%water_content(numnod))
 q%boundary%top_mode=FSI_TOP_MODE_DYNAMIC_PROVIDER;q%boundary%bottom_mode=7
 q%boundary%bottom_head=-321.0_real64
 q%numerical%max_iterations=80;q%numerical%max_backtracking=16
 q%numerical%conductivity_implicit_mode=0;q%numerical%conductivity_mean_method=1
 q%numerical%min_step_duration=1e-6_real64
 q%numerical%head_abs_tolerance=1e-12_real64;q%numerical%head_rel_tolerance=1e-12_real64;q%numerical%ponding_tolerance=1e-12_real64
 q%evaluation%constitutive=>hyd;q%evaluation%source_sink=>source;q%evaluation%dynamic_top_boundary=>top
 print '(a)','geometry,bottom_mode,profile,window,stop_code,solver_status,solver_route,steps,completed,iterations,transfer_cm,bottom_cm,storage_change_cm,ledger_residual_cm,max_step_soil_residual_cm,first_transfer_cm,cpu_seconds,history,external_calls,flux_calls,head_calls,evaluations,within_solve_switches,accepted_regime_switches,h_min,h_max,theta_min,theta_max,water_l1_diff_cm,head_inf_diff_cm'
 do bottom_case=1,3
  q%boundary%bottom_mode=bottom_modes(bottom_case)
 do profile=1,3
  continued=.true.
  hstart=heads(profile)
  q%boundary%bottom_head=heads(profile)
  call bind_b110_default_mvg_provider(hyd,hp,0.25_real64)
  call hyd%evaluate(hstart,theta0,cond,cap,dkdh)
  bottom_rate=-cond(1)
  do history=1,3
   window=1
   horizon=0.25_real64
   previous_steps=0
   do level=0,12
    steps=2**level;dt=horizon/real(steps,real64)
    call integrate()
   end do
  end do
 end do
 end do
contains
 subroutine integrate()
  type(reference_richards_legacy_workspace_t)::workspace
  q%base_state%pressure_head=hstart;q%base_state%water_content=theta0
  q%base_state%ponding_depth=0.0_real64
  if(history==1)q%base_state%ponding_depth=0.02_real64
  q%base_state%groundwater_level=-2.25_real64
  storage0=sum(theta0*dz)+q%base_state%ponding_depth
  transfer_cm=0.0_real64;bottom_cm=0.0_real64;resmax=0.0_real64;first_cm=0.0_real64;iters=0;done=0;stop_code=0
  cv_external_total=0.0_real64;cv_surface_resmax=0.0_real64;cv_positive_steps=0;cv_negative_steps=0
  q%step_duration=dt;q%boundary%bottom_flux=bottom_rate
  q%numerical%compartment_balance_tolerance=max(1e-12_real64,1e-12_real64/dt)
  q%numerical%total_balance_tolerance=q%numerical%compartment_balance_tolerance
  call bind_b110_default_mvg_provider(hyd,hp,dt)
  switches=0;external_calls=0;flux_calls=0;head_calls=0;evaluations=0;within_switches=0;last_regime=0
  top%trace=>trace
  call cpu_time(cpu0)
  do j=1,steps
   call hyd%evaluate(q%base_state%pressure_head,theta_eval,cond_eval,cap_eval,dkdh_eval)
   call bind_b110_dynamic_top_boundary_solver_provider(top%delegate,params,hp,1,q%base_state%ponding_depth,dt, &
    0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,1.0_real64,1.0_real64,1.0_real64, &
    fixed_top_node_conductivity=cond_eval(1))
   external_head=0.02_real64
   if(history==3)external_head=0.02_real64*min(1.0_real64,real(j,real64)*dt/0.001953125_real64)
   if(history==4.or.history==5)then
    if(real(j,real64)*dt<=stage_ramp_day)then
     external_head=0.02_real64*real(j,real64)*dt/stage_ramp_day
    else if(real(j,real64)*dt<=stage_recession_start_day)then
     external_head=0.02_real64
    else if(real(j,real64)*dt<=stage_recession_start_day+stage_ramp_day)then
     external_head=0.02_real64*(1.0_real64-(real(j,real64)*dt-stage_recession_start_day)/stage_ramp_day)
    else
     external_head=0.0_real64
    end if
   end if
   if(history==5)external_head=cv_stage_scale*external_head
   top%delegate%external_surface_water_head_supplied=.true.;top%delegate%external_surface_water_head_cm=external_head
   top%delegate%external_flooding_sill_head_cm=0.01_real64
   top%surface_cv_enabled=history==5
   top%surface_cv_external_head_cm=external_head
   if(history==4.and.steps==4096.and.(j>=2047.and.j<=2050.or.j>=2062.and.j<=2066.or.j==2117)) &
    write(*,'(a,i0,5(a,es24.16))') &
    'RECESSION_STATE,',j,',',real(j,real64)*dt,',',external_head,',',q%base_state%ponding_depth,',', &
    q%base_state%pressure_head(1),',',cond_eval(1)
   trace=top03_top_trace_t()
   write(trace%label,'(i0,5(a,i0))')geometry_id,',',q%boundary%bottom_mode,',',profile,',',history,',',steps,',',j
   call solver%solve(q,workspace,r)
   external_calls=external_calls+trace%external_calls;flux_calls=flux_calls+trace%flux_calls
   head_calls=head_calls+trace%head_calls;evaluations=evaluations+trace%calls;within_switches=within_switches+trace%switches
   iters=iters+r%diagnostics%nonlinear_iterations
   if(r%status/=SW_SOLVE_CONVERGED)then
    stop_code=1
    print '(a,7(a,i0),4(a,es24.16))','STOP',',',geometry_id,',',q%boundary%bottom_mode,',',profile,',',window,',',steps,',',j, &
      ',',r%diagnostics%nonlinear_iterations,',',maxval(abs(workspace%richards%residual)), &
      ',',maxval(abs(workspace%state_binding%h-workspace%richards%old_head)), &
      ',',minval(workspace%richards%provider_capacity),',',maxval(workspace%richards%provider_capacity)
    exit
   end if
   if(.not.r%integrated_mass_balance_residual_available)error stop 'missing soil mass oracle'
   resmax=max(resmax,abs(r%integrated_mass_balance_residual_cm))
   if(abs(r%integrated_mass_balance_residual_cm)>1e-10_real64)error stop 'soil mass gate'
   if(r%top_flux>0.0_real64.and.history/=5)then
    stop_code=2
    exit
   end if
   call materialize_fmr_top_surface_exchange(q%base_state%ponding_depth,r%candidate_state%ponding_depth, &
     0.0_real64,0.0_real64,-r%top_flux*dt,0.0_real64,x)
   if(x%status/=FMR_TOP_EXCHANGE_OK.or.abs(x%closure_residual_cm)>1e-12_real64)error stop 'surface closure'
   transfer_cm=transfer_cm+x%signed_swap_to_external_cm
   if(history==5)then
    if(abs(trace%cv_surface_residual)>1e-12_real64)error stop 'surface control-volume residual gate'
    cv_external_total=cv_external_total+trace%cv_external_flux*dt
    cv_surface_resmax=max(cv_surface_resmax,abs(trace%cv_surface_residual))
    if(trace%cv_external_flux>1e-14_real64)cv_positive_steps=cv_positive_steps+1
    if(trace%cv_external_flux< -1e-14_real64)cv_negative_steps=cv_negative_steps+1
    if(abs(trace%cv_surface_storage-r%candidate_state%ponding_depth)>1e-10_real64) &
      error stop 'CV provider storage differs from accepted candidate'
   end if
   if(j==1)first_cm=x%signed_swap_to_external_cm
   bottom_cm=bottom_cm+r%bottom_flux*dt
   regime=trace%last_regime
   if(last_regime/=0.and.regime/=last_regime)switches=switches+1
   last_regime=regime
   q%base_state=r%candidate_state
   done=j
  end do
  call cpu_time(cpu1)
  water_diff=-1.0_real64;head_diff=-1.0_real64
  if(done==steps)then
   if(history==5.and.cv_stage_scale>1.0_real64.and.steps>=64.and.cv_negative_steps==0) &
     error stop 'SCV inundation recession did not return water to external owner'
   if(history==5.and.abs(transfer_cm+cv_external_total)>1e-10_real64) &
     error stop 'SCV external transfer differs from integrated interface flux'
   if(previous_steps*2==steps)then
    water_diff=sum(abs(q%base_state%water_content-previous_theta)*dz)
    head_diff=maxval(abs(q%base_state%pressure_head-previous_head))
   end if
   previous_theta=q%base_state%water_content;previous_head=q%base_state%pressure_head;previous_steps=steps
  end if
  print '(i0,5(a,i0),a,a,3(a,i0),7(a,es24.16),7(a,i0),6(a,es24.16))',geometry_id,',',q%boundary%bottom_mode,',',profile,',',window,',',stop_code,',',r%status,',',trim(r%diagnostics%route),',',steps,',',done,',',iters, &
   ',',transfer_cm,',',bottom_cm,',',sum(q%base_state%water_content*dz)+q%base_state%ponding_depth-storage0, &
   ',',sum(q%base_state%water_content*dz)+q%base_state%ponding_depth-storage0+transfer_cm-bottom_cm, &
   ',',resmax,',',first_cm,',',cpu1-cpu0,',',history,',',external_calls,',',flux_calls,',',head_calls,',',evaluations,',',within_switches,',',switches, &
   ',',minval(q%base_state%pressure_head),',',maxval(q%base_state%pressure_head), &
   ',',minval(q%base_state%water_content),',',maxval(q%base_state%water_content),',',water_diff,',',head_diff
  if(history==5)write(*,*)'SCV_BALANCE',steps,done,cv_external_total,cv_surface_resmax, &
    transfer_cm+cv_external_total,cv_positive_steps,cv_negative_steps
 end subroutine
end program
