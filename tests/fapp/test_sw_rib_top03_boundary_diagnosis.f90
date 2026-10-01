! Research-only fixed-grid temporal refinement. No kernel acceptance or commit.
program top03_boundary_diagnosis
 use,intrinsic::iso_fortran_env,only:int64,real64
 use MOD_grid,only:numnod,z,dz,disnod
 use mod_soil_water_solver_contract,only:soil_water_parameter_set_t,soil_water_solve_request_t,soil_water_solve_result_t,SW_SOLVE_CONVERGED
 use mod_reference_richards_legacy_binding,only:reference_richards_legacy_solver_t,reference_richards_legacy_workspace_t
 use mod_reference_richards_state_binding,only:FSI_TOP_MODE_DYNAMIC_PROVIDER
 use mod_b110_default_mvg_provider,only:b110_default_mvg_parameters_t,b110_default_mvg_provider_t,initialize_b110_default_mvg_parameters,bind_b110_default_mvg_provider
 use mod_b110_source_sink_provider,only:b110_source_sink_provider_t,bind_b110_source_sink_provider
 use mod_b110_dynamic_top_boundary_solver_adapter,only:b110_dynamic_top_boundary_solver_provider_t,bind_b110_dynamic_top_boundary_solver_provider
 use mod_fmr_top_surface_exchange,only:fmr_top_surface_exchange_t,materialize_fmr_top_surface_exchange,FMR_TOP_EXCHANGE_OK
 implicit none
 type(soil_water_parameter_set_t),target::params
 type(b110_default_mvg_parameters_t),target::hp
 type(b110_default_mvg_provider_t),target::hyd
 type(b110_source_sink_provider_t),target::source
 type(b110_dynamic_top_boundary_solver_provider_t),target::top
 type(reference_richards_legacy_solver_t)::solver
 type(soil_water_solve_request_t)::q
 type(soil_water_solve_result_t)::r
 type(fmr_top_surface_exchange_t)::x
 real(real64),allocatable,target::qdra(:,:),qssdi(:),qrot(:)
 real(real64)::cofgen(24,numnod),cond(numnod),cap(numnod),dkdh(numnod)
 real(real64)::heads(3),hstart(numnod),theta0(numnod),dt,transfer_cm,bottom_cm,resmax,cpu0,cpu1,first_cm,storage0,bottom_rate,horizon,water_diff,head_diff,previous_theta(numnod),previous_head(numnod)
 integer::i,profile,level,steps,j,iters,done,window,stop_code,bottom_case,geometry_id,previous_steps
 integer,parameter::bottom_modes(3)=[7,2,5]
 logical::continued,valid
 character(len=8)::geometry_arg
 call get_command_argument(1,geometry_arg)
 read(geometry_arg,*)geometry_id
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
 print '(a)','geometry,bottom_mode,profile,window,stop_code,solver_status,solver_route,steps,completed,iterations,transfer_cm,bottom_cm,storage_change_cm,ledger_residual_cm,max_step_soil_residual_cm,first_transfer_cm,cpu_seconds,h_min,h_max,theta_min,theta_max,water_l1_diff_cm,head_inf_diff_cm'
 do bottom_case=1,3
  q%boundary%bottom_mode=bottom_modes(bottom_case)
 do profile=1,3
  continued=.true.
  hstart=heads(profile)
  q%boundary%bottom_head=heads(profile)
  call bind_b110_default_mvg_provider(hyd,hp,0.25_real64)
  call hyd%evaluate(hstart,theta0,cond,cap,dkdh)
  bottom_rate=-cond(1)
  do window=1,2
   horizon=0.25_real64
   if(window==2)horizon=0.001953125_real64
   previous_steps=0
   do level=0,9
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
  if(continued)q%base_state%ponding_depth=0.02_real64
  q%base_state%groundwater_level=-2.25_real64
  storage0=sum(theta0*dz)+q%base_state%ponding_depth
  transfer_cm=0.0_real64;bottom_cm=0.0_real64;resmax=0.0_real64;first_cm=0.0_real64;iters=0;done=0;stop_code=0
  q%step_duration=dt;q%boundary%bottom_flux=bottom_rate
  q%numerical%compartment_balance_tolerance=max(1e-12_real64,1e-12_real64/dt)
  q%numerical%total_balance_tolerance=q%numerical%compartment_balance_tolerance
  call bind_b110_default_mvg_provider(hyd,hp,dt)
  call cpu_time(cpu0)
  do j=1,steps
   call bind_b110_dynamic_top_boundary_solver_provider(top,params,hp,1,q%base_state%ponding_depth,dt, &
    0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,1.0_real64,1.0_real64,1.0_real64)
   top%external_surface_water_head_supplied=.true.;top%external_surface_water_head_cm=0.02_real64
   top%external_flooding_sill_head_cm=0.01_real64
   call solver%solve(q,workspace,r)
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
   if(r%top_flux>0.0_real64)then
    stop_code=2
    exit
   end if
   call materialize_fmr_top_surface_exchange(q%base_state%ponding_depth,r%candidate_state%ponding_depth, &
     0.0_real64,0.0_real64,-r%top_flux*dt,0.0_real64,x)
   if(x%status/=FMR_TOP_EXCHANGE_OK.or.abs(x%closure_residual_cm)>1e-12_real64)error stop 'surface closure'
   transfer_cm=transfer_cm+x%signed_swap_to_external_cm
   if(j==1)first_cm=x%signed_swap_to_external_cm
   bottom_cm=bottom_cm+r%bottom_flux*dt
   q%base_state=r%candidate_state
   done=j
  end do
  call cpu_time(cpu1)
  water_diff=-1.0_real64;head_diff=-1.0_real64
  if(done==steps)then
   if(previous_steps*2==steps)then
    water_diff=sum(abs(q%base_state%water_content-previous_theta)*dz)
    head_diff=maxval(abs(q%base_state%pressure_head-previous_head))
   end if
   previous_theta=q%base_state%water_content;previous_head=q%base_state%pressure_head;previous_steps=steps
  end if
  print '(i0,5(a,i0),a,a,3(a,i0),13(a,es24.16))',geometry_id,',',q%boundary%bottom_mode,',',profile,',',window,',',stop_code,',',r%status,',',trim(r%diagnostics%route),',',steps,',',done,',',iters, &
   ',',transfer_cm,',',bottom_cm,',',sum(q%base_state%water_content*dz)+q%base_state%ponding_depth-storage0, &
   ',',sum(q%base_state%water_content*dz)+q%base_state%ponding_depth-storage0+transfer_cm-bottom_cm, &
   ',',resmax,',',first_cm,',',cpu1-cpu0, &
   ',',minval(q%base_state%pressure_head),',',maxval(q%base_state%pressure_head), &
   ',',minval(q%base_state%water_content),',',maxval(q%base_state%water_content),',',water_diff,',',head_diff
 end subroutine
end program
