 subroutine research_retries(origin,interval)
 type(soil_water_solve_request_t),intent(in)::origin
 real(real64),intent(in)::interval
 type(soil_water_solve_request_t)::current,next_state,saved
 real(real64)::duration,total_top,total_bottom,a_top,a_bottom,elapsed,storage_begin,ledger,max_residual
 real(real64)::growth,fractions(5)
 integer::level,parts,k,completed,attempts,rejections,route,stop_reason,iteration_count,step_iterations
 real(real64)::step_residual
 logical::ok
 saved=origin
 storage_begin=sum(origin%base_state%water_content*dz)+origin%base_state%ponding_depth
 fractions=[0.25_real64,1.0_real64/3.0_real64,0.5_real64,2.0_real64/3.0_real64,0.75_real64]
 print '(a)','retry_kind,configuration,requested_days,completed_days,accepted,rejected,attempts,stop_reason,top_cm,bottom_cm,storage_cm,ledger_cm,max_soil_residual_cm,iterations,hbottom_cm'
 do route=1,3
 do level=0,6
 if(route==2.and.level>4)cycle
 if(route==3.and.level>1)cycle
 current=origin;total_top=0;total_bottom=0;elapsed=0;completed=0;attempts=0;rejections=0;stop_reason=0;iteration_count=0;max_residual=0
 parts=2**level
 duration=interval/real(parts,real64)
 growth=1.0_real64+real(level,real64)
 k=0
 do while(elapsed<interval-1e-15_real64)
  if(route==2)then
   if(k==0)duration=interval*fractions(level+1)
   if(k==1)duration=interval*(1.0_real64-fractions(level+1))
  end if
  duration=min(duration,interval-elapsed)
  if(duration<origin%numerical%min_step_duration)then
   stop_reason=2;exit
  end if
  if(attempts>=2000)then
   stop_reason=3;exit
  end if
  attempts=attempts+1
  call retry_step(current,duration,next_state,a_top,a_bottom,ok,step_iterations,step_residual)
  iteration_count=iteration_count+step_iterations;max_residual=max(max_residual,step_residual)
  if(.not.ok)then
   rejections=rejections+1
   if(route==3)then
    duration=duration/2;cycle
   end if
   stop_reason=1;exit
  end if
  current=next_state;total_top=total_top+a_top;total_bottom=total_bottom+a_bottom
  elapsed=elapsed+duration;completed=completed+1;k=k+1
  if(route==3)duration=min(interval,duration*growth)
 end do
 ledger=sum(current%base_state%water_content*dz)+current%base_state%ponding_depth-storage_begin+total_top-total_bottom
 if(abs(ledger)>1e-10_real64)error stop 'retry aggregate mass'
 if(any(origin%base_state%pressure_head/=saved%base_state%pressure_head).or. &
    any(origin%base_state%water_content/=saved%base_state%water_content).or. &
    origin%base_state%ponding_depth/=saved%base_state%ponding_depth)error stop 'retry modified origin'
 write(*,'(*(g0,:,","))')'RETRY',route,level,interval,elapsed,completed,rejections,attempts,stop_reason,total_top,total_bottom, &
   sum(current%base_state%water_content*dz)+current%base_state%ponding_depth-storage_begin,ledger,max_residual,iteration_count,current%base_state%pressure_head(numnod)
 end do
 end do
 end subroutine
 subroutine retry_step(input,step,output,transfer,bottom,accepted,iterations,residual)
 type(soil_water_solve_request_t),intent(in)::input
 real(real64),intent(in)::step
 type(soil_water_solve_request_t),intent(out)::output
 real(real64),intent(out)::transfer,bottom
 logical,intent(out)::accepted
 integer,intent(out)::iterations
 real(real64),intent(out)::residual
 type(soil_water_solve_request_t)::request
 type(soil_water_solve_result_t)::result
 type(reference_richards_legacy_workspace_t)::work
 type(b110_default_mvg_provider_t),target::local_hyd
 type(top03_observed_top_t),target::local_top
 type(fmr_top_surface_exchange_t)::exchange
 request=input;request%step_duration=step
 request%numerical%compartment_balance_tolerance=max(1e-12_real64,1e-12_real64/step)
 request%numerical%total_balance_tolerance=request%numerical%compartment_balance_tolerance
 call bind_b110_default_mvg_provider(local_hyd,hp,step)
 call bind_b110_dynamic_top_boundary_solver_provider(local_top%delegate,params,hp,1,input%base_state%ponding_depth,step, &
   0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,1.0_real64,1.0_real64,1.0_real64)
 local_top%delegate%external_surface_water_head_supplied=.true.
 local_top%delegate%external_surface_water_head_cm=0.02_real64
 local_top%delegate%external_flooding_sill_head_cm=0.01_real64
 request%evaluation%constitutive=>local_hyd;request%evaluation%dynamic_top_boundary=>local_top
 call solver%solve(request,work,result)
 iterations=result%diagnostics%nonlinear_iterations
 accepted=result%status==SW_SOLVE_CONVERGED;output=input;transfer=0;bottom=0;residual=0
 if(.not.accepted)return
 if(.not.result%integrated_mass_balance_residual_available)error stop 'retry missing soil mass'
 if(abs(result%integrated_mass_balance_residual_cm)>1e-10_real64)error stop 'retry soil mass'
 residual=abs(result%integrated_mass_balance_residual_cm)
 if(result%top_flux>0)error stop 'retry exfiltration unqualified'
 call materialize_fmr_top_surface_exchange(input%base_state%ponding_depth,result%candidate_state%ponding_depth, &
   0.0_real64,0.0_real64,-result%top_flux*step,0.0_real64,exchange)
 if(exchange%status/=FMR_TOP_EXCHANGE_OK.or.abs(exchange%closure_residual_cm)>1e-12_real64)error stop 'retry surface mass'
 transfer=exchange%signed_swap_to_external_cm;bottom=result%bottom_flux*step
 output%base_state=result%candidate_state
 end subroutine
