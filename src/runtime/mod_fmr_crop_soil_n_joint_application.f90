module mod_fmr_crop_soil_n_joint_application
  use iso_fortran_env,only:real64,int64
  use ieee_arithmetic,only:ieee_is_finite
  use mod_transaction_reference,only:transaction_state_t
  use mod_canonical_contracts,only:canonical_numerical_config_t
  use mod_fmr_runtime_core,only:fmr_logical_column_t,fmr_template_t,FMR_OPTIONAL_STATE_LAYOUT_BASE, &
       FMR_SOLUTE_STATE_LAYOUT_NONE,FMR_NUMERICAL_CONTINUATION_NONE,FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_kernel_transactions,only:kernel_committed_state_t,kernel_checkpoint_t,kernel_candidate_state_t, &
       kernel_result_t,kernel_diagnostics_t
  use mod_fmr_serialized_reference_backend,only:fmr_serialized_reference_backend_t, &
       fmr_b110_physical_parameters_t,fmr_b110_physical_forcing_t,fmr_serialized_physical_observation_t, &
       fmr_b110_physical_state_t,fmr_b110_temporal_indicator_state_t,fmr_water_flux_substep_trace_t
  use mod_fmr_committed_restart,only:fmr_committed_restart_bundle_t,fmr_export_committed_restart, &
       fmr_restore_committed_restart,FMR_RESTART_OK
  use mod_b111_soil_n_reactive_owner
  use mod_b111_soil_n_mineral_owner,only:MINERAL_OK
  use mod_soil_n_pool_state,only:soil_n_pool_state_t
  use mod_crop_soil_n_day
  use mod_crop_soil_n_configuration
  use mod_wofost81_crop_owner_state,only:wofost81_crop_owner_state_t
  use mod_wofost_one_day_structural_evolution,only:wofost_one_day_forcing_t
  use mod_fmr_b111_mineral_route,only:aggregate_mineral_trace,mineral_daily_carrier_t
  use mod_b111_soil_n_mineral_owner,only:mineral_state_t
  use mod_fmr_b111_reactive_n_joint_application,only:reactive_n_joint_states_match
  use mod_soil_n_day_environment,only:soil_n_day_environment_t
  implicit none
  private
  integer,parameter,public::JOINT_OK=0,JOINT_INVALID=1,JOINT_WATER_REJECTED=2, &
       JOINT_CHEMICAL_REJECTED=3,JOINT_COMMIT_REJECTED=4
  type,public::crop_soil_n_joint_result_t
    integer::status=JOINT_INVALID
    type(kernel_result_t)::water
    type(kernel_diagnostics_t)::diagnostics
    type(crop_soil_receipt_t)::chemical
  end type
  type,public::crop_soil_n_joint_restart_t
    private
    integer::schema=1
    type(fmr_committed_restart_bundle_t)::water
    type(crop_soil_state_t)::chemical
  end type
  public::historical_crop_soil_top_from_trace
  public::run_crop_soil_n_joint_interval,crop_soil_n_joint_states_match,run_crop_soil_n_harvest_boundary
  public::export_crop_soil_n_joint_restart,restore_crop_soil_n_joint_restart
contains
  subroutine run_crop_soil_n_harvest_boundary(water,chemical,consume_pending,result)
    type(kernel_committed_state_t),intent(in)::water
    type(crop_soil_state_t),intent(inout)::chemical
    logical,intent(in)::consume_pending
    type(crop_soil_harvest_receipt_t),intent(out)::result
    type(crop_soil_state_t)::trial
    result=crop_soil_harvest_receipt_t()
    if(.not.crop_soil_n_joint_states_match(water,chemical))return
    trial=chemical
    if(consume_pending)then
      call consume_crop_soil_harvest_pending(trial,result)
    else
      call harvest_crop_soil_boundary(trial,result)
    end if
    if(result%status/=0)return
    if(.not.crop_soil_n_joint_states_match(water,trial))then
      result%status=CROP_SOIL_INVALID;return
    end if
    chemical=trial
  end subroutine
  logical function crop_soil_n_joint_states_match(water,chemical)result(ok)
    type(kernel_committed_state_t),intent(in)::water
    type(crop_soil_state_t),intent(in)::chemical
    type(reactive_state_t)::soil
    type(wofost81_crop_owner_state_t)::crop
    ok=.false.
    if(.not.chemical%ready())return
    call chemical%snapshot(soil,crop)
    ok=reactive_n_joint_states_match(water,soil)
  end function

  logical function bounded_template(t) result(ok)
    type(fmr_template_t),intent(in)::t
    ok=t%optional_state_layout_id==FMR_OPTIONAL_STATE_LAYOUT_BASE.and. &
         t%solute_state_layout_id==FMR_SOLUTE_STATE_LAYOUT_NONE.and. &
         (t%numerical_continuation_layout_id==FMR_NUMERICAL_CONTINUATION_NONE.or. &
          t%numerical_continuation_layout_id==FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY)
  end function

  ! Original management_soil gross input, bounded to dry, snow-free pond_input.
  ! This routine is called only on the backend candidate's accepted trace.
  subroutine historical_crop_soil_top_from_trace(steps,t0,t1,top,status)
    type(fmr_water_flux_substep_trace_t),intent(in)::steps(:)
    real(real64),intent(in)::t0,t1
    real(real64),intent(out)::top
    integer,intent(out)::status
    integer::i
    real(real64)::clock,amount,dt,values(7)
    top=0d0;status=1
    if(.not.all(ieee_is_finite([t0,t1])))return
    if(max(abs(t0),abs(t1))>1d9)return
    if(t1-t0/=1d0.or.size(steps)==0)return
    clock=t0;amount=0d0
    do i=1,size(steps)
      associate(s=>steps(i))
        if(.not.s%pond_storage_available.or..not.s%converged_surface_available.or. &
           .not.s%converged_gross_sources_available)return
        values=[s%t0,s%t1,s%converged_rain_rate_cm_day,s%converged_irrigation_rate_cm_day, &
          s%converged_snowmelt_rate_cm_day,s%converged_runon_rate_cm_day,s%converged_runoff_depth_cm]
        if(.not.all(ieee_is_finite(values)))return
        if(s%t0/=clock.or.s%t1<=s%t0.or.s%t1>t1)return
        if(.not.all(ieee_is_finite([s%pond_start_cm,s%pond_end_cm])))return
        if(s%pond_start_cm/=0d0.or.s%pond_end_cm/=0d0)return
        if(any(values(3:)<0d0).or.any(values(3:)>1d4))return
        ! Melt is not the original gross snowfall/isnrai convention.
        if(s%converged_snowmelt_rate_cm_day/=0d0)return
        dt=s%t1-s%t0
        amount=amount+dt*(s%converged_rain_rate_cm_day+s%converged_irrigation_rate_cm_day+ &
          s%converged_runon_rate_cm_day)-s%converged_runoff_depth_cm
        clock=s%t1
      end associate
    end do
    if(clock/=t1.or.amount<0d0.or.amount>1d4)return
    top=.01d0*amount;status=MINERAL_OK
  end subroutine

  subroutine run_crop_soil_n_joint_interval(backend,column,template,parameters,water,forcing,config,chemical,weather,t0,t1,result,environment,fallow,clean_surface_water,atmospheric_n_surface,historical_top_water,finite_donor_top,nondepleting_top)
    type(fmr_serialized_reference_backend_t),intent(inout)::backend
    type(fmr_logical_column_t),intent(in)::column
    type(fmr_template_t),intent(in)::template
    type(fmr_b110_physical_parameters_t),target,intent(in)::parameters
    type(kernel_committed_state_t),intent(inout)::water
    type(fmr_b110_physical_forcing_t),intent(in)::forcing
    type(canonical_numerical_config_t),intent(in)::config
    type(crop_soil_state_t),intent(inout)::chemical
    type(wofost_one_day_forcing_t),intent(in)::weather
    real(real64),intent(in)::t0,t1
    type(crop_soil_n_joint_result_t),intent(out)::result
    type(soil_n_day_environment_t),intent(in),optional::environment
    logical,intent(in),optional::fallow,clean_surface_water,atmospheric_n_surface
    logical,intent(in),optional::finite_donor_top,nondepleting_top
  real(real64),intent(in),optional::historical_top_water
    type(kernel_checkpoint_t)::checkpoint
    type(kernel_candidate_state_t)::candidate
    type(fmr_serialized_physical_observation_t)::obs
    type(crop_soil_state_t)::chemical_trial
    type(crop_n_configuration_t)::cp
    integer(int64)::id
    logical::ok,did_commit,inactive,admit_atmospheric_n,bounded_top,nondepleting
    integer::status
    real(real64)::clock,gross_top,root_sum,root_error,root_term,root_next
    integer::step
    real(real64),allocatable::top_n_water
    logical::bind_atmosphere
    type(reactive_parameters_t)::np
    integer(int64)::nid
    type(reactive_state_t)::soil
    type(wofost81_crop_owner_state_t)::crop
    type(mineral_state_t)::base
    type(mineral_daily_carrier_t)::carrier
    result=crop_soil_n_joint_result_t()
    inactive=.false.;if(present(fallow))inactive=fallow
    bounded_top=.false.;if(present(finite_donor_top))bounded_top=finite_donor_top
    nondepleting=.false.;if(present(nondepleting_top))nondepleting=nondepleting_top
    if(nondepleting.and.(bounded_top.or.inactive.or..not.present(historical_top_water)))return
    if(bounded_top.and.(.not.inactive.or..not.present(historical_top_water)))return
    if(.not.bounded_template(template))return
    if(inactive)then
      call chemical%snapshot(soil,crop)
      if(.not.crop%harvest_retired())return
      if(.not.all(ieee_is_finite([forcing%root_extraction_sink,forcing%root_potential_transpiration])))return
      if(any(abs(forcing%root_extraction_sink)>0d0).or.abs(forcing%root_potential_transpiration)>0d0)return
    end if
    call chemical%snapshot(soil,crop)
    call soil%configuration(np,nid)
    admit_atmospheric_n=.false.;if(present(atmospheric_n_surface))admit_atmospheric_n=atmospheric_n_surface
    bind_atmosphere=admit_atmospheric_n.and.allocated(forcing%pond_input)
    if(bind_atmosphere)then
      if(present(historical_top_water))return
      if(allocated(forcing%snow).or.allocated(forcing%rutter).or.allocated(forcing%black_evaporation).or. &
         allocated(forcing%boesten_evaporation).or.allocated(forcing%rfm_surface).or. &
         allocated(forcing%macropore_top_input))return
    end if
    if(present(historical_top_water))then
      if(.not.admit_atmospheric_n)return
      if(.not.ieee_is_finite(historical_top_water))return
      if(abs(historical_top_water)>100d0)return
      if(historical_top_water<0d0.and..not.(bounded_top.or.nondepleting))return
      if((bounded_top.or.nondepleting).and.historical_top_water>=0d0)return
      allocate(top_n_water,source=historical_top_water)
    end if
    if(any(abs(np%mineral%c_top)>0d0).and..not.admit_atmospheric_n)return
    if(.not.allocated(np%mineral%dz_cm))return
    if(.not.allocated(parameters%dz))return
    if(size(np%mineral%dz_cm)/=size(parameters%dz))return
    if(any(abs(np%mineral%dz_cm-parameters%dz)>0d0))return
    if(.not.crop_soil_n_joint_states_match(water,chemical))return
    call water%current_time(clock,ok)
    if(.not.ok.or..not.ieee_is_finite(t0).or..not.ieee_is_finite(t1))return
    if(abs(t0-clock)>0.0_real64.or.abs(t1-t0-1d0)>0d0)return
    call water%capture_checkpoint(checkpoint,ok)
    if(.not.ok)return
    call backend%run_trial(column,template,parameters,water,forcing,config,t0,t1,checkpoint, &
         result%water,candidate,result%diagnostics,trace_accepted_water_flux_substeps=.true.)
    result%status=JOINT_WATER_REJECTED
    if(.not.result%water%completed)return
    if(.not.candidate%ready())return
    obs=backend%observation()
    if(.not.obs%accepted_water_flux_trace_available.or..not.allocated(obs%accepted_water_flux_substeps))then
      call backend%discard_trial_candidate(candidate,result%diagnostics)
      return
    end if
    chemical_trial=chemical
    call soil%mineral_snapshot(base)
    call aggregate_mineral_trace(base,obs%accepted_water_flux_substeps,carrier,status,clean_surface_water,atmospheric_n_surface)
    if(status/=MINERAL_OK)then
      result%status=JOINT_CHEMICAL_REJECTED
      call backend%discard_trial_candidate(candidate,result%diagnostics)
      return
    end if
    if(bind_atmosphere)then
      call historical_crop_soil_top_from_trace(obs%accepted_water_flux_substeps,t0,t1,gross_top,status)
      if(status/=MINERAL_OK)then
        result%status=JOINT_CHEMICAL_REJECTED
        call backend%discard_trial_candidate(candidate,result%diagnostics)
        return
      end if
      allocate(top_n_water,source=gross_top)
      ! A dynamic boundary can accept thousands of water substeps per day.
      ! Compensate their root integral before cm/m/cm conversion in the crop
      ! view; naive accumulation can manufacture a tiny drought/death flux.
      ! The accepted root fluxes and the existing eight-rounding bound are
      ! unchanged. Never replace this integral with potential transpiration.
      root_sum=0d0;root_error=0d0
      do step=1,size(obs%accepted_water_flux_substeps)
        associate(s=>obs%accepted_water_flux_substeps(step))
          root_term=(s%t1-s%t0)*sum(s%root_sink)*.01d0-root_error
          root_next=root_sum+root_term
          root_error=(root_next-root_sum)-root_term
          root_sum=root_next
        end associate
      end do
      carrier%root_water=root_sum
    end if
    if(inactive)then
      call advance_crop_soil_fallow_day(chemical_trial,t0,t1,carrier%water_end,carrier%outflow,carrier%in_bottom, &
        carrier%in_lateral,carrier%root_water,forcing%root_potential_transpiration,result%chemical,environment,surface_water=carrier%surface_water,historical_top_water=top_n_water,finite_donor_top=bounded_top)
    else
    call advance_crop_soil_day(chemical_trial,t0,t1,carrier%water_end,carrier%outflow,carrier%in_bottom, &
      carrier%in_lateral,carrier%root_water,forcing%root_potential_transpiration,weather,result%chemical,environment,surface_water=carrier%surface_water,historical_top_water=top_n_water,nondepleting_top=nondepleting)
    end if
    result%status=JOINT_CHEMICAL_REJECTED
    if(result%chemical%status/=CROP_SOIL_OK)then
      call backend%discard_trial_candidate(candidate,result%diagnostics)
      return
    end if
    result%status=JOINT_COMMIT_REJECTED
    call backend%commit_trial_candidate(water,candidate,result%diagnostics,did_commit,status)
    if(.not.did_commit)return
    chemical=chemical_trial
    result%status=JOINT_OK
  end subroutine

  subroutine export_crop_soil_n_joint_restart(column,template,parameter_set_id,water,chemical,payload,status)
    type(fmr_logical_column_t),intent(in)::column
    type(fmr_template_t),intent(in)::template
    integer(int64),intent(in)::parameter_set_id
    type(kernel_committed_state_t),intent(in)::water
    type(crop_soil_state_t),intent(in)::chemical
    type(crop_soil_n_joint_restart_t),intent(out)::payload
    integer,intent(out)::status
    type(crop_soil_n_joint_restart_t)::trial
    logical::ok
    integer::code
    payload=crop_soil_n_joint_restart_t();status=JOINT_INVALID
    if(column%state_handle/=1.or..not.bounded_template(template))return
    if(.not.crop_soil_n_joint_states_match(water,chemical))return
    call fmr_export_committed_restart([column],[template],[water],parameter_set_id,trial%water,ok,code)
    if(.not.ok.or.code/=FMR_RESTART_OK)return
    trial%chemical=chemical
    payload=trial;status=JOINT_OK
  end subroutine

  subroutine restore_crop_soil_n_joint_restart(payload,column,template,water_parameter_id,chemical_parameter_id, &
       water,chemical,status)
    type(crop_soil_n_joint_restart_t),intent(in)::payload
    type(fmr_logical_column_t),intent(in)::column
    type(fmr_template_t),intent(in)::template
    integer(int64),intent(in)::water_parameter_id,chemical_parameter_id
    type(kernel_committed_state_t),intent(inout)::water
    type(crop_soil_state_t),intent(inout)::chemical
    integer,intent(out)::status
    type(kernel_committed_state_t)::water_trial(1)
    type(crop_soil_state_t)::chemical_trial
    type(crop_n_configuration_t)::cp
    integer(int64)::id
    logical::ok
    integer::code
    status=JOINT_INVALID
    if(payload%schema/=1)return
    if(water%ready())return
    if(chemical%ready())return
    if(column%state_handle/=1.or..not.bounded_template(template))return
    call fmr_restore_committed_restart(payload%water,water_parameter_id,[column],[template],water_trial,ok,code)
    if(.not.ok.or.code/=FMR_RESTART_OK)return
    if(.not.payload%chemical%ready())return
    call payload%chemical%configuration(cp,id)
    if(id/=chemical_parameter_id)return
    chemical_trial=payload%chemical
    if(.not.crop_soil_n_joint_states_match(water_trial(1),chemical_trial))return
    water=water_trial(1);chemical=chemical_trial;status=JOINT_OK
  end subroutine
end module
