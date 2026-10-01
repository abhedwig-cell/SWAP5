! Research-only fixed-grid temporal refinement. No kernel acceptance or commit.
program top03_temporal_controller
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
 real(real64)::hstart(numnod),theta0(numnod),bottom_rate,horizon,budget,dt,t,top_sum,bot_sum,storage0,cpu0,cpu1,defect,allowance,water_error,top_error,bot_error
 integer::i,geometry_id,bottom_case,profile,policy,precision,accepted,rejected,trials,iterations,fail_code,reference_steps
 integer,parameter::bottom_modes(3)=[2,5,7]
 type(soil_water_solve_request_t)::origin,full,half,second_half,accepted_state
 real(real64)::full_top,full_bot,half_top,half_bot,a_top,a_bot,b_top,b_bot
 logical::ok1,ok2,ok3
 character(len=8)::geometry_arg
 call get_command_argument(1,geometry_arg)
 read(geometry_arg,*)geometry_id
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

 horizon=0.25_real64
 write(*,'(a)',advance='no')'geometry,bottom_mode,profile,policy,budget_cm,stop_code,accepted,rejected,trials,iterations,top_cm,bottom_cm,storage_cm,ledger_cm,cpu_seconds,time_days,pond_cm'
 do i=1,numnod
 write(*,'(a,i0)',advance='no')',theta',i
 end do
 print *
 do bottom_case=1,3
 q%boundary%bottom_mode=bottom_modes(bottom_case)
 do profile=1,2
 hstart=-123.0_real64
 if(profile==2)hstart=-10.0_real64
 q%boundary%bottom_head=hstart(1)
 call bind_b110_default_mvg_provider(hyd,hp,horizon)
 call hyd%evaluate(hstart,theta0,cond,cap,dkdh)
 bottom_rate=-cond(1)
 do policy=0,2
 do precision=1,3
 if(policy==0.and.precision==3)cycle
 budget=0.01_real64/4.0_real64**(precision-1)
 reference_steps=2048*2**(precision-1)
 call integrate()
 end do
 end do
 end do
 end do
contains
 subroutine advance_trial(input,duration,output,transfer,bottom,ok)
 type(soil_water_solve_request_t),intent(in)::input
 real(real64),intent(in)::duration
 type(soil_water_solve_request_t),intent(out)::output
 real(real64),intent(out)::transfer,bottom
 logical,intent(out)::ok
 type(reference_richards_legacy_workspace_t)::workspace
 q=input;q%step_duration=duration;q%boundary%bottom_flux=bottom_rate
 q%numerical%compartment_balance_tolerance=max(1e-12_real64,1e-12_real64/duration)
 q%numerical%total_balance_tolerance=q%numerical%compartment_balance_tolerance
 call bind_b110_default_mvg_provider(hyd,hp,duration)
 call bind_b110_dynamic_top_boundary_solver_provider(top,params,hp,1,q%base_state%ponding_depth,duration, &
 0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,1.0_real64,1.0_real64,1.0_real64)
 top%external_surface_water_head_supplied=.true.;top%external_surface_water_head_cm=0.02_real64
 top%external_flooding_sill_head_cm=0.01_real64
 call solver%solve(q,workspace,r)
 iterations=iterations+r%diagnostics%nonlinear_iterations
 ok=r%status==SW_SOLVE_CONVERGED
 transfer=0.0_real64;bottom=0.0_real64;output=input
 if(.not.ok)return
 if(.not.r%integrated_mass_balance_residual_available)error stop 'missing mass oracle'
 if(abs(r%integrated_mass_balance_residual_cm)>1e-10_real64)error stop 'soil mass'
 if(r%top_flux>0.0_real64)then
 fail_code=2;ok=.false.;return
 end if
 call materialize_fmr_top_surface_exchange(input%base_state%ponding_depth,r%candidate_state%ponding_depth, &
 0.0_real64,0.0_real64,-r%top_flux*duration,0.0_real64,x)
 if(x%status/=FMR_TOP_EXCHANGE_OK.or.abs(x%closure_residual_cm)>1e-12_real64)error stop 'surface mass'
 transfer=x%signed_swap_to_external_cm;bottom=r%bottom_flux*duration
 output=input;output%base_state=r%candidate_state
 end subroutine
 subroutine integrate()
 q%base_state%pressure_head=hstart;q%base_state%water_content=theta0
 q%base_state%ponding_depth=0.02_real64;q%base_state%groundwater_level=-2.25_real64
 accepted_state=q
 storage0=sum(theta0*dz)+0.02_real64
 accepted=0;rejected=0;trials=0;iterations=0;fail_code=0;t=0.0_real64;top_sum=0.0_real64;bot_sum=0.0_real64
 dt=horizon
 if(policy==0)dt=horizon/real(reference_steps,real64)
 call cpu_time(cpu0)
 do while(t<horizon-1e-14_real64)
 if(trials>=50000)then
 fail_code=4;exit
 end if
 dt=min(dt,horizon-t);origin=accepted_state;trials=trials+1
 call advance_trial(origin,dt,full,full_top,full_bot,ok1)
 if(policy==0)then
 if(.not.ok1)then
 if(fail_code==0)fail_code=1
 exit
 end if
 accepted_state=full;top_sum=top_sum+full_top;bot_sum=bot_sum+full_bot;t=t+dt;accepted=accepted+1
 cycle
 end if
 ok2=.false.;ok3=.false.
 if(ok1)call advance_trial(origin,dt/2.0_real64,half,a_top,a_bot,ok2)
 if(ok2)call advance_trial(half,dt/2.0_real64,second_half,b_top,b_bot,ok3)
 if(ok3)then
 half=second_half;half_top=a_top+b_top;half_bot=a_bot+b_bot
 end if
 if(fail_code==2)exit
 defect=huge(1.0_real64)
 if(ok1.and.ok2.and.ok3)then
 water_error=sum(abs(full%base_state%water_content-half%base_state%water_content)*dz)+ &
 abs(full%base_state%ponding_depth-half%base_state%ponding_depth)
 top_error=abs(full_top-half_top);bot_error=abs(full_bot-half_bot)
 defect=water_error
 if(policy==2)defect=max(water_error,top_error,bot_error)
 end if
 allowance=budget*dt/horizon
 if(trials<=20)then
 write(*,'(a,4(a,i0),a,es24.16,a,i0,4(a,es24.16),3(a,l1))')'TRACE',',',geometry_id,',',bottom_modes(bottom_case),',',profile,',',policy,',',budget,',',trials,',',t,',',dt,',',defect,',',allowance,',',ok1,',',ok2,',',ok3
 end if
 if(defect<=allowance)then
 accepted_state=half;top_sum=top_sum+half_top;bot_sum=bot_sum+half_bot;t=t+dt;accepted=accepted+1
 if(defect<allowance/4.0_real64)dt=min(2.0_real64*dt,horizon-t)
 else
 rejected=rejected+1;dt=dt/2.0_real64
 if(dt<2e-6_real64)then
 fail_code=3;exit
 end if
 end if
 end do
 call cpu_time(cpu1)
 write(*,'(i0,3(a,i0),a,es24.16,5(a,i0),5(a,es24.16))',advance='no')geometry_id,',',bottom_modes(bottom_case),',',profile,',',policy,',',budget,',',fail_code,',',accepted,',',rejected,',',trials,',',iterations, &
 ',',top_sum,',',bot_sum,',',sum(accepted_state%base_state%water_content*dz)+accepted_state%base_state%ponding_depth-storage0, &
 ',',sum(accepted_state%base_state%water_content*dz)+accepted_state%base_state%ponding_depth-storage0+top_sum-bot_sum,',',cpu1-cpu0
 write(*,'(2(a,es24.16))',advance='no')',',t,',',accepted_state%base_state%ponding_depth
 do i=1,numnod
 write(*,'(a,es24.16)',advance='no')',',accepted_state%base_state%water_content(i)
 end do
 print *
 end subroutine
end program
