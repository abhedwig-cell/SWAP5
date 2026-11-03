 subroutine verify_thermal_receipts()
  type(fmr_serialized_reference_backend_t)::backend
  type(kernel_executor_t)::tx
  type(kernel_committed_state_t)::committed
  type(fmr_logical_column_t)::column
  type(fmr_template_t)::template
  type(fmr_b110_physical_parameters_t)::parameters
  type(fmr_b110_physical_forcing_t)::forcing
  type(canonical_numerical_config_t)::config
  type(fmr_serialized_column_result_t)::output
  type(fmr_column_diagnostics_t)::diagnostic
  type(fmr_serialized_batch_diagnostics_t)::runtime
  type(liquid_water_sensible_enthalpy_parameters_t)::energy_parameters
  type(fixed_flux_top_boundary_provider_t),target::top
  type(kernel_checkpoint_t)::checkpoint
  type(kernel_result_t)::result
  type(kernel_candidate_state_t)::candidate
  type(kernel_diagnostics_t)::kd
  type(fmr_serialized_physical_observation_t)::obs
  class(transaction_state_t),allocatable::snapshot
  real(real64),allocatable::heads(:),water(:),temp(:),saved_head(:),saved_water(:),saved_temp(:),previous_temp(:)
  real(real64)::cursor,storage,flux,local_error,dt
  integer::mode,enabled,active_calls,i,j,code,unit
  logical::ok,trace,committed_ok
  character(1024)::path
  call get_command_argument(1,path);open(newunit=unit,file=trim(path),status='replace')
  do mode=1,2
   do enabled=0,1
    trace=enabled==1
    call initialize_case(backend,top,committed,column,template,parameters,forcing,config,output,diagnostic, &
                         runtime,active_calls,energy_parameters,-1d-10,mode==2)
    forcing%soil_temperature%top_boundary_mode=SOIL_TEMP_TOP_PRESCRIBED_HEAT_FLUX
    forcing%soil_temperature%prescribed_top_heat_flux_j_cm2_day=.03d0
    call committed%capture_checkpoint(checkpoint,ok);call require(ok,'receipt checkpoint')
    call backend%run_trial(column,template,parameters,committed,forcing,config,t0,t1,checkpoint,result,candidate,kd, &
         trace_accepted_water_flux_substeps=trace,trace_accepted_soil_n_heat=trace)
    call require(result%completed.and.candidate%ready(),'real thermal trial completed')
    call require(committed%current_revision()==0_int64,'trial does not publish committed state')
    call candidate%snapshot(snapshot,ok);call require(ok,'candidate snapshot')
    select type(s=>snapshot)
    class is(fmr_b110_physical_state_t)
     heads=s%pressure_head;water=s%water_content
     call copy_soil_temperature_profile(s%soil_temperature,temp,code)
     call require(code==SOIL_TEMP_OK,'candidate real temperature')
    class default
     error stop 'unexpected physical candidate'
    end select
    if(.not.trace)then
     saved_head=heads;saved_water=water;saved_temp=temp
    else
     call require(all(heads==saved_head).and.all(water==saved_water).and.all(temp==saved_temp),'trace off/on exact physical result')
     obs=backend%observation()
     call require(obs%accepted_water_flux_trace_available,'accepted receipt trace available')
     call require(size(obs%accepted_water_flux_substeps)==mode,'only selected single/two-half intervals')
     cursor=t0;previous_temp=spread(9d0,1,size(temp));local_error=0d0
     do i=1,mode
      associate(step=>obs%accepted_water_flux_substeps(i),r=>obs%accepted_water_flux_substeps(i)%thermal)
       call require(r%available.and.r%conductive_profile_available.and.r%independent_boundary_heat,'numeric independent thermal receipt')
       call require(r%t0==step%t0.and.r%t1==step%t1.and.r%t0==cursor,'water and thermal interval identities')
       call require(all(r%water_start==step%water_start).and.all(r%water_end==step%water_end),'exact native water endpoints')
       call require(all(r%temperature_start_c==previous_temp),'selected thermal profile continuity')
       call require(.not.r%gas_transport_available.and..not.r%advective_energy_complete.and. &
                    .not.r%full_energy_balance_complete,'missing physical owners remain unavailable')
       dt=r%t1-r%t0
       do j=1,size(temp)
        storage=r%heat_capacity_average_j_cm3_k(j)*r%dz_cm(j)*(r%temperature_end_c(j)-r%temperature_start_c(j))
        flux=r%conductive_face_energy_j_cm2(j)-r%conductive_face_energy_j_cm2(j+1)
        local_error=max(local_error,abs(storage-flux))
        write(unit,'(a,3(a,i0),6(a,es25.17e3))')'NODE',',',mode,',',i,',',j, &
         ',',r%temperature_start_c(j),',',r%temperature_end_c(j),',',step%water_start(j),',',step%water_end(j),',',storage,',',flux
       end do
       call require(abs(sum(r%conductive_face_energy_j_cm2([1,size(temp)+1])*[1d0,-1d0])- &
                        r%legacy_boundary_energy_j_cm2)<1d-14,'actual boundary heat identity')
       cursor=r%t1;previous_temp=r%temperature_end_c
      end associate
     end do
     call require(cursor==t1.and.all(previous_temp==temp),'selected last receipt equals actual endpoint')
     call require(local_error<1d-10,'independent native nodal conductive budget')
     write(unit,'(a,a,i0,a,es25.17e3)')'ACCEPTED',',',mode,',',local_error
    end if
    call backend%commit_trial_candidate(committed,candidate,kd,committed_ok,code)
    call require(committed_ok.and.committed%current_revision()==1_int64,'one canonical publication')
   end do
  end do
  ! Rejection must not expose accepted data from the preceding successful call.
  call initialize_case(backend,top,committed,column,template,parameters,forcing,config,output,diagnostic, &
                       runtime,active_calls,energy_parameters,-1d-10,.false.)
  parameters%max_iterations=0
  call committed%capture_checkpoint(checkpoint,ok);call require(ok,'rejection checkpoint')
  call backend%run_trial(column,template,parameters,committed,forcing,config,t0,t1,checkpoint,result,candidate,kd, &
       trace_accepted_water_flux_substeps=.true.,trace_accepted_soil_n_heat=.true.)
  obs=backend%observation()
  call require(.not.result%completed.and..not.candidate%ready(),'invalid/rejected thermal transaction')
  call require(.not.obs%accepted_water_flux_trace_available.and..not.allocated(obs%accepted_water_flux_substeps),'no stale accepted thermal trace')
  call require(committed%current_revision()==0_int64,'rejection preserves revision')
  close(unit)
  print '(a)','ACCEPTED_THERMAL_RECEIPTS_SINGLE_TWO_HALF_REJECTION_OFF_ON_PASS_FULL_ENERGY_OPEN'
 end subroutine
