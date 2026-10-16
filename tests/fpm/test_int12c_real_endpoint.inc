  ! Qualification-only fixed-flux receiver. This is a real committed FMR
  ! endpoint witness, not the broader dynamic-top/crop application admission.
  subroutine verify_int12c_real_endpoint(certificate_profile, refined_profile)
    use mod_pmdirect_swetr0_process
    use mod_fmr_interception_source_window_binding
    logical, intent(in) :: certificate_profile
    logical, intent(in), optional :: refined_profile
    type(pmdirect_swetr0_weather_t) :: weather
    type(pmdirect_swetr0_site_t) :: site
    type(pmdirect_swetr0_canopy_t) :: canopy
    type(pmdirect_swetr0_daily_result_t) :: daily
    type(pmdirect_swetr0_interval_result_t) :: interval
    type(pmdirect_swetr0_diagnostics_t) :: process_diag
    type(fmr_interception_source_window_t) :: owner, restored
    type(fmr_interception_source_window_restart_t) :: restart
    type(kernel_committed_state_t) :: committed
    type(fmr_serialized_column_result_t) :: result
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(fmr_column_diagnostics_t) :: diag
    type(fmr_b110_physical_parameters_t) :: p
    type(fmr_b110_physical_forcing_t) :: forcing
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(canonical_numerical_config_t) :: config
    type(fmr_serialized_reference_backend_t) :: backend
    type(fmr_serialized_physical_observation_t) :: observation
    type(kernel_executor_t) :: tx
    type(fixed_flux_top_boundary_provider_t), target :: top
    real(real64) :: endpoints(4), t0, request_amount, accepted_amount, accepted_t, accepted_sum
    real(real64) :: source_amount, net_input, before_amount, reported_time
    integer :: status, i, physical_calls
    integer(int64) :: initial_revision
    logical :: ok, complete
    weather=pmdirect_swetr0_weather_t(161,1.2450e7_real64,11.0_real64,18.1_real64, &
         1.315514_real64,4.92_real64,0.47_real64)
    site%latitude_degrees=52.0_real64;site%altitude_m=10.0_real64
    site%wind_measurement_height_m=10.0_real64;site%humidity_measurement_height_m=1.5_real64
    site%angstrom_a=0.25_real64;site%angstrom_b=0.5_real64;site%wind_function_factor=1.0_real64
    site%soil_surface_resistance_s_m=600.0_real64
    canopy=pmdirect_swetr0_canopy_t(.true.,3.12683333333333335_real64, &
         0.755141552325116483_real64,0.25_real64,0.23_real64,70.0_real64,0.0_real64,1.0_real64)
    call evaluate_pmdirect_swetr0_daily(weather,site,canopy,daily,process_diag)
    call require(process_diag%daily_result_produced,'real endpoint admitted daily source')
    call apply_swinter1_daily_interval(weather,canopy,daily,interval,process_diag)
    call require(process_diag%interval_result_produced,'real endpoint admitted SWINTER1 source')
    call require(abs(interval%net_rain_cm_per_day-0.405938742948784959_real64)<1.0e-14_real64, &
         'real endpoint exact admitted net rain')
    endpoints=[0.002_real64,0.004_real64,0.007_real64,0.01_real64]
    source_amount=interval%interception_rate_cm_per_day*endpoints(4)
    call initialize_fmr_interception_source_window(column_id,10091009_int64,0.0_real64, &
         endpoints(4),source_amount,owner,status)
    call require(status==FMR_INTWIN_OK,'real endpoint source owner initialized')
    call initialize_parameters(p,2)
    if(certificate_profile)then
      call initialize_temporal_committed(committed,p,.true.,ok)
    else
      call initialize_committed(committed,p,.false.,ok)
    end if
    call require(ok,'real endpoint physical origin initialized')
    template%template_id=440001_int64;template%physics_topology_id=440002_int64
    template%vertical_layout_id=440003_int64;template%state_layout_id=440004_int64
    template%solver_interface_id=440005_int64;template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    column%column_id=column_id;column%template_id=template%template_id
    column%parameter_ref=1_int64;column%state_handle=1_int64;column%forcing_handle=1_int64
    column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    config%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    config%transaction%temporal_tolerance=1.0e-6_real64
    config%transaction%mass_tolerance=hard_mass_gate
    config%transaction%max_retries=8;config%transaction%retry_scale=0.5_real64
    config%max_committed_substeps=32;config%progress_tolerance=0.0_real64
    if(certificate_profile)then
      template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
      config%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
      config%transaction%temporal_tolerance=0.0_real64
      config%model_temporal_indicator_budget_available=.true.
      ! Explicit test-only budget. This is not an application accuracy default.
      config%model_temporal_indicator_budget=1.0e-6_real64
    end if
    if (present(refined_profile)) then
      if (refined_profile) then
        call require(certificate_profile,'refinement requires unchanged certificate accuracy')
        config%transaction%max_retries=24
        config%max_committed_substeps=4096
        p%min_step_duration=1.0e-12_real64
      end if
    end if
    call initialize_forcing(forcing,-interval%net_rain_cm_per_day,0.0_real64,-999.0_real64)
    t0=0.0_real64;accepted_sum=0.0_real64;net_input=0.0_real64
    do i=1,4
      call prepare_fmr_interception_source_window_trial(owner,endpoints(i),request_amount,status)
      call require(status==FMR_INTWIN_OK,'real endpoint prepare')
      if(i==1)then
        ! Actual preflight rejection with the unchanged committed state.
        p%bottom_mode=4
        initial_revision=committed%current_revision()
        result=fmr_serialized_column_result_t();diag=fmr_column_diagnostics_t()
        result%column_id=column_id;result%requested_t0=t0;result%requested_t1=endpoints(i)
        diag%column_id=column_id
        runtime=fmr_serialized_batch_diagnostics_t();physical_calls=0
        call backend%initialize(top)
        call fmr_execute_serialized_resolved_physical_column(backend,tx,column,template,p,forcing,committed, &
             config,t0,endpoints(i),result,diag,runtime,physical_calls)
        call require(.not.result%committed,'real rejected physical result unexpectedly committed')
        call accept_fmr_interception_source_window_result(owner,result%column_id,result%requested_t0, &
             result%requested_t1,result%committed,result%accepted_substeps,result%initial_revision, &
             result%final_revision,result%final_committed_time,result%final_committed_time_bound,accepted_amount,status)
        call require(status==FMR_INTWIN_NO_ACCEPTED_COMMIT,'real rejected result advanced interception')
        call fmr_interception_source_window_progress(owner,accepted_t,before_amount,complete,status)
        call require(same_bits(accepted_t,0.0_real64).and.same_bits(before_amount,0.0_real64), &
             'real rejection changed source progress')
        call require(committed%current_revision()==0_int64,'real rejection changed physical revision')
        write(*,'(A)') 'INT12C_REAL_PREFLIGHT_REJECTION_ZERO_PROGRESS=PASS'
        p%bottom_mode=2
        call prepare_fmr_interception_source_window_trial(owner,endpoints(i),request_amount,status)
        call require(status==FMR_INTWIN_OK,'real rejected physical retry preparation')
      end if
      initial_revision=committed%current_revision()
        result=fmr_serialized_column_result_t();diag=fmr_column_diagnostics_t()
        result%column_id=column_id;result%requested_t0=t0;result%requested_t1=endpoints(i)
        diag%column_id=column_id
        runtime=fmr_serialized_batch_diagnostics_t();physical_calls=0
        call backend%initialize(top)
        call fmr_execute_serialized_resolved_physical_column(backend,tx,column,template,p,forcing,committed, &
             config,t0,endpoints(i),result,diag,runtime,physical_calls)
      write(*,'(A,I2,2L2,I5,2I5)') 'INT12C_REAL_ENDPOINT_STATUS=',i,result%completed,result%committed, &
           result%kernel_status,result%accepted_substeps,result%solver_rejections
      write(*,'(A,A,A,6I8)') 'INT12C_REAL_DIAGNOSTICS=',trim(result%admission_status), &
           ' attempts/retries/temporal/mass/headcalc/solver-status=',diag%attempts,diag%retries, &
           result%temporal_rejections,result%mass_rejections,result%solver_headcalc_calls,result%solver_status
      ! Observe the real attempted certificate before a failed positive gate.
      ! Read-only diagnostics distinguish unavailable history from budget excess.
      observation=backend%observation()
      write(*,'(A,I2,5L2,I6,3(1X,ES23.15),2A)') 'INT12C_REAL_CERTIFICATE_ATTEMPT=',i, &
           observation%temporal_indicator_enabled,observation%temporal_previous_derivative_available, &
           observation%temporal_indicator_available,observation%temporal_head_budget_valid, &
           observation%temporal_certificate_available,observation%temporal_indicator_status, &
           observation%temporal_head_inf_bound,observation%temporal_head_budget, &
           observation%temporal_normalized_indicator,' reason=', &
           trim(observation%temporal_certificate_unavailable_reason)
      if(.not.result%committed)then
        call accept_fmr_interception_source_window_result(owner,result%column_id,result%requested_t0, &
             result%requested_t1,result%committed,result%accepted_substeps,result%initial_revision, &
             result%final_revision,result%final_committed_time,result%final_committed_time_bound,accepted_amount,status)
        call require(status==FMR_INTWIN_NO_ACCEPTED_COMMIT,'failed endpoint advanced source adapter')
        call fmr_interception_source_window_progress(owner,accepted_t,before_amount,complete,status)
        call require(same_bits(accepted_t,t0).and.same_bits(before_amount,accepted_sum), &
             'failed endpoint changed source progress')
        call require(committed%current_revision()==initial_revision,'failed endpoint changed physical revision')
        call committed%current_time(reported_time,ok)
        call require(ok.and.same_bits(reported_time,t0),'failed endpoint changed physical time')
        write(*,'(A)') 'INT12C_REAL_FAILED_ENDPOINT_ZERO_PROGRESS=PASS'
      end if
      call require(result%completed.and.result%committed,'real physical endpoint completed and committed')
      call require(result%solver_headcalc_calls>0,'real physical endpoint actually executed HeadCalc')
      call require(result%mass%complete.and.abs(result%mass%residual)<=hard_mass_gate,'real endpoint hard mass')
      call require(result%final_revision>initial_revision,'real endpoint actual revision advanced')
      if(certificate_profile)then
        observation=backend%observation()
        call require(observation%temporal_certificate_available,'real endpoint certificate available')
        call require(observation%temporal_head_budget_valid,'real endpoint certificate budget valid')
        call require(observation%temporal_normalized_indicator<=1.0_real64,'real endpoint certificate within budget')
        call require(observation%temporal_additional_full_nonlinear_solves==0,'certificate added nonlinear trajectory')
        write(*,'(A,I2,2(1X,ES23.15))') 'INT12C_REAL_CERTIFICATE=',i, &
             observation%temporal_head_inf_bound,observation%temporal_normalized_indicator
      end if
      call committed%current_time(reported_time,ok)
      call require(ok.and.same_bits(reported_time,result%final_committed_time),'real endpoint reported time matches kernel')
      call accept_fmr_interception_source_window_result(owner,result%column_id,result%requested_t0, &
             result%requested_t1,result%committed,result%accepted_substeps,result%initial_revision, &
             result%final_revision,result%final_committed_time,result%final_committed_time_bound,accepted_amount,status)
      call require(status==FMR_INTWIN_OK,'real physical result rejected by source adapter')
      accepted_sum=accepted_sum+accepted_amount
      call require(abs(accepted_amount-interval%interception_rate_cm_per_day*(endpoints(i)-t0))<1.0e-14_real64, &
           'real endpoint source allocation mismatch')
      call require(abs(result%mass%total_in-interval%net_rain_cm_per_day*(endpoints(i)-t0))<1.0e-12_real64, &
           'real physical net rain input mismatch')
      net_input=net_input+result%mass%total_in
      write(*,'(A,I2,5(1X,ES23.15))') 'INT12C_REAL_ENDPOINT=',i,reported_time,accepted_amount, &
           result%mass%total_in,result%mass%storage_change,result%mass%residual
      if(i==2)then
        call export_fmr_interception_source_window_restart(owner,reported_time,restart,status)
        call require(status==FMR_INTWIN_OK,'real endpoint companion export')
        call restore_fmr_interception_source_window(restart,restored,status)
        call require(status==FMR_INTWIN_OK,'real endpoint companion restore')
        owner=restored
      end if
      t0=endpoints(i)
    end do
    call fmr_interception_source_window_progress(owner,accepted_t,before_amount,complete,status)
    call require(status==FMR_INTWIN_OK.and.complete,'real endpoint source window complete')
    call require(same_bits(before_amount,source_amount),'real endpoint final aggregate bitwise')
    call require(abs(accepted_sum-source_amount)<1.0e-14_real64,'real accepted interception once')
    call require(abs(net_input+accepted_sum-weather%gross_rain_cm_d*endpoints(4))<1.0e-12_real64, &
         'real combined gross canopy soil source mass')
    write(*,'(A)') 'INT12C_REAL_FMR_COMMITTED_ENDPOINTS=PASS'
    write(*,'(A)') 'INT12C_REAL_PREFLIGHT_REJECT_RETRY_PROGRESS=PASS'
    write(*,'(A)') 'INT12C_REAL_COMPANION_PROGRESS_RESTORE=PASS'
    write(*,'(A)') 'INT12C_REAL_NET_RAIN_AND_INTERCEPTION_ACCOUNTING=PASS'
  end subroutine verify_int12c_real_endpoint
