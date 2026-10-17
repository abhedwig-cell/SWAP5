module mod_fmr_b111_pond_joint_application
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
       fmr_b110_physical_state_t,fmr_b110_temporal_indicator_state_t
  use mod_fmr_committed_restart,only:fmr_committed_restart_bundle_t,fmr_export_committed_restart, &
       fmr_restore_committed_restart,FMR_RESTART_OK
  use mod_fmr_b111_matrix_solute_route,only:matrix_solute_state_t,matrix_solute_restart_t, &
       matrix_solute_receipt_t,consume_accepted_matrix_trace,export_matrix_solute_restart, &
       restore_matrix_solute_restart,MATRIX_OK
  use mod_solute_mobile_salt_state,only:mobile_salt_state_t
  use mod_solute_compartment_state,only:solute_compartment_state_t
  use mod_fmr_b111_matrix_joint_application,only:matrix_joint_result_t,matrix_joint_states_match, &
    JOINT_OK,JOINT_INVALID,JOINT_WATER_REJECTED,JOINT_CHEMICAL_REJECTED,JOINT_COMMIT_REJECTED
  use mod_b111_persistent_pond
  use mod_fmr_b111_pond_solute_route
  implicit none
  private
  public::run_pond_joint_interval
contains
  logical function bounded_template(t) result(ok)
    type(fmr_template_t),intent(in)::t
    ok=t%optional_state_layout_id==FMR_OPTIONAL_STATE_LAYOUT_BASE.and. &
         t%solute_state_layout_id==FMR_SOLUTE_STATE_LAYOUT_NONE.and. &
         (t%numerical_continuation_layout_id==FMR_NUMERICAL_CONTINUATION_NONE.or. &
          t%numerical_continuation_layout_id==FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY)
  end function

  subroutine run_pond_joint_interval(backend,column,template,parameters,water,forcing,config,chemical,supply,t0,t1,result)
    type(fmr_serialized_reference_backend_t),intent(inout)::backend
    type(fmr_logical_column_t),intent(in)::column
    type(fmr_template_t),intent(in)::template
    type(fmr_b110_physical_parameters_t),target,intent(in)::parameters
    type(kernel_committed_state_t),intent(inout)::water
    type(fmr_b110_physical_forcing_t),intent(in)::forcing
    type(canonical_numerical_config_t),intent(in)::config
    type(matrix_solute_state_t),intent(inout)::chemical
    type(pond_step_t),intent(in)::supply
    real(real64),intent(in)::t0,t1
    type(matrix_joint_result_t),intent(out)::result
    type(kernel_checkpoint_t)::checkpoint
    type(kernel_candidate_state_t)::candidate
    type(fmr_serialized_physical_observation_t)::obs
    type(matrix_solute_state_t)::chemical_trial
    class(transaction_state_t),allocatable::candidate_physical
    logical::ok,did_commit
    integer::status
    real(real64)::clock
    result=matrix_joint_result_t()
    if(.not.all(ieee_is_finite([supply%t0,supply%t1,supply%rain_rate,supply%rain_c, &
      supply%irrigation_rate,supply%irrigation_c,supply%dry_deposition_rate, &
      supply%runon_rate,supply%runon_c])))return
    if(supply%t0/=t0.or.supply%t1/=t1)return
    if(.not.ieee_is_finite(forcing%top_flux))return
    if(allocated(forcing%black_evaporation).or.allocated(forcing%boesten_evaporation).or. &
      allocated(forcing%snow).or.allocated(forcing%rutter).or.allocated(forcing%rfm_surface).or. &
      allocated(forcing%macropore_top_input))return
    if(allocated(forcing%pond_input))then
      if(template%numerical_continuation_layout_id/=FMR_NUMERICAL_CONTINUATION_NONE)return
      if(.not.all(ieee_is_finite([forcing%pond_input%rain_rate_cm_day, &
          forcing%pond_input%irrigation_rate_cm_day])))return
      if(forcing%pond_input%rain_rate_cm_day/=supply%rain_rate.or. &
          forcing%pond_input%irrigation_rate_cm_day/=supply%irrigation_rate)return
    end if
    if(.not.bounded_template(template))return
    if(.not.matrix_joint_states_match(water,chemical))return
    call water%current_time(clock,ok)
    if(.not.ok.or..not.ieee_is_finite(t0).or..not.ieee_is_finite(t1))return
    if(abs(t0-clock)>0.0_real64.or.t1<=t0)return
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
    call candidate%snapshot(candidate_physical,ok)
    if(.not.ok)then
      call backend%discard_trial_candidate(candidate,result%diagnostics)
      return
    end if
    select type(cp=>candidate_physical)
    class is(fmr_b110_physical_state_t)
      if(.not.ieee_is_finite(cp%ponding_depth).or.cp%ponding_depth<0d0)then
        call backend%discard_trial_candidate(candidate,result%diagnostics)
        return
      end if
    class default
      call backend%discard_trial_candidate(candidate,result%diagnostics)
      return
    end select
    chemical_trial=chemical
    call consume_accepted_pond_trace(chemical_trial,obs%accepted_water_flux_substeps,supply,result%chemical)
    result%status=JOINT_CHEMICAL_REJECTED
    if(result%chemical%status/=MATRIX_OK)then
      call backend%discard_trial_candidate(candidate,result%diagnostics)
      return
    end if
    select type(cp=>candidate_physical)
    class is(fmr_b110_physical_state_t)
      if(cp%ponding_depth/=obs%accepted_water_flux_substeps(size(obs%accepted_water_flux_substeps))%pond_end_cm)then
        call backend%discard_trial_candidate(candidate,result%diagnostics)
        return
      end if
    end select
    result%status=JOINT_COMMIT_REJECTED
    call backend%commit_trial_candidate(water,candidate,result%diagnostics,did_commit,status)
    if(.not.did_commit)return
    ! Candidate endpoint must agree before publishing either chemical pool.
    ! This has already been checked by the contiguous trace consumer.
    chemical=chemical_trial
    result%status=JOINT_OK
  end subroutine
end module
