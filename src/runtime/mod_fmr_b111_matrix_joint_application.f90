module mod_fmr_b111_matrix_joint_application
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
       fmr_b110_physical_state_t,fmr_b110_temporal_indicator_state_t,fmr_b110_boesten_evaporation_state_t
  use mod_fmr_committed_restart,only:fmr_committed_restart_bundle_t,fmr_export_committed_restart, &
       fmr_restore_committed_restart,FMR_RESTART_OK
  use mod_fmr_b111_matrix_solute_route,only:matrix_solute_state_t,matrix_solute_restart_t, &
       matrix_solute_receipt_t,consume_accepted_matrix_trace,export_matrix_solute_restart, &
       restore_matrix_solute_restart,MATRIX_OK
  use mod_solute_mobile_salt_state,only:mobile_salt_state_t
  use mod_solute_compartment_state,only:solute_compartment_state_t
  implicit none
  private
  integer,parameter,public::JOINT_OK=0,JOINT_INVALID=1,JOINT_WATER_REJECTED=2, &
       JOINT_CHEMICAL_REJECTED=3,JOINT_COMMIT_REJECTED=4
  type,public::matrix_joint_result_t
    integer::status=JOINT_INVALID
    type(kernel_result_t)::water
    type(kernel_diagnostics_t)::diagnostics
    type(matrix_solute_receipt_t)::chemical
  end type
  type,public::matrix_joint_restart_t
    private
    integer::schema=1
    type(fmr_committed_restart_bundle_t)::water
    type(matrix_solute_restart_t)::chemical
  end type
  public::run_matrix_joint_interval,matrix_joint_states_match
  public::export_matrix_joint_restart,restore_matrix_joint_restart
contains
  logical function matrix_joint_states_match(water,chemical) result(ok)
    type(kernel_committed_state_t),intent(in)::water
    type(matrix_solute_state_t),intent(in)::chemical
    class(transaction_state_t),allocatable::physical
    type(mobile_salt_state_t)::m
    type(solute_compartment_state_t)::s
    real(real64),allocatable::theta(:)
    real(real64)::t,wt
    integer(int64)::revision
    logical::available
    ok=.false.
    if(.not.water%ready())return
    if(.not.chemical%ready())return
    call water%current_time(wt,available)
    if(.not.available)return
    call chemical%snapshot(t,theta,m,s,revision)
    if(abs(t-wt)>0.0_real64)return
    call water%snapshot(physical,available)
    if(.not.available)return
    select type(p=>physical)
    type is(fmr_b110_physical_state_t)
      ok=bounded_physical(p,theta)
    type is(fmr_b110_boesten_evaporation_state_t)
      ok=bounded_physical(p,theta)
      if(.not.all(ieee_is_finite([p%boesten_evaporation%spev,p%boesten_evaporation%saev])))then
        ok=.false.
      else
        ok=ok.and.min(p%boesten_evaporation%spev,p%boesten_evaporation%saev)>=0d0
      end if
    type is(fmr_b110_temporal_indicator_state_t)
      ok=bounded_physical(p,theta)
    end select
  end function

  logical function bounded_physical(p,theta) result(ok)
    class(fmr_b110_physical_state_t),intent(in)::p
    real(real64),intent(in)::theta(:)
    real(real64)::scale
    ok=.false.
    if(allocated(p%salt).or.allocated(p%macropore).or.allocated(p%snow).or. &
         allocated(p%soil_temperature).or.allocated(p%rutter))return
    if(.not.allocated(p%water_content).or..not.allocated(p%pressure_head))return
    if(p%active_nodes/=size(theta).or.size(p%water_content)/=size(theta).or.size(p%pressure_head)/=size(theta))return
    if(.not.all(ieee_is_finite(p%water_content)).or..not.all(ieee_is_finite(p%pressure_head)))return
    if(.not.all(ieee_is_finite([p%ponding_depth,p%groundwater_level])).or.p%ponding_depth<0.0_real64)return
    scale=max(1.0_real64,maxval(abs(theta)))
    ok=all(abs(p%water_content-theta)<=1024.0_real64*epsilon(1.0_real64)*scale)
  end function

  logical function bounded_template(t) result(ok)
    type(fmr_template_t),intent(in)::t
    ok=t%optional_state_layout_id==FMR_OPTIONAL_STATE_LAYOUT_BASE.and. &
         t%solute_state_layout_id==FMR_SOLUTE_STATE_LAYOUT_NONE.and. &
         (t%numerical_continuation_layout_id==FMR_NUMERICAL_CONTINUATION_NONE.or. &
          t%numerical_continuation_layout_id==FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY)
  end function

  subroutine run_matrix_joint_interval(backend,column,template,parameters,water,forcing,config,chemical,t0,t1,result)
    type(fmr_serialized_reference_backend_t),intent(inout)::backend
    type(fmr_logical_column_t),intent(in)::column
    type(fmr_template_t),intent(in)::template
    type(fmr_b110_physical_parameters_t),target,intent(in)::parameters
    type(kernel_committed_state_t),intent(inout)::water
    type(fmr_b110_physical_forcing_t),intent(in)::forcing
    type(canonical_numerical_config_t),intent(in)::config
    type(matrix_solute_state_t),intent(inout)::chemical
    real(real64),intent(in)::t0,t1
    type(matrix_joint_result_t),intent(out)::result
    type(kernel_checkpoint_t)::checkpoint
    type(kernel_candidate_state_t)::candidate
    type(fmr_serialized_physical_observation_t)::obs
    type(matrix_solute_state_t)::chemical_trial
    logical::ok,did_commit
    integer::status
    real(real64)::clock
    result=matrix_joint_result_t()
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
    chemical_trial=chemical
    call consume_accepted_matrix_trace(chemical_trial,obs%accepted_water_flux_substeps,result%chemical)
    result%status=JOINT_CHEMICAL_REJECTED
    if(result%chemical%status/=MATRIX_OK)then
      call backend%discard_trial_candidate(candidate,result%diagnostics)
      return
    end if
    result%status=JOINT_COMMIT_REJECTED
    call backend%commit_trial_candidate(water,candidate,result%diagnostics,did_commit,status)
    if(.not.did_commit)return
    chemical=chemical_trial
    result%status=JOINT_OK
  end subroutine

  subroutine export_matrix_joint_restart(column,template,parameter_set_id,water,chemical,payload,status)
    type(fmr_logical_column_t),intent(in)::column
    type(fmr_template_t),intent(in)::template
    integer(int64),intent(in)::parameter_set_id
    type(kernel_committed_state_t),intent(in)::water
    type(matrix_solute_state_t),intent(in)::chemical
    type(matrix_joint_restart_t),intent(out)::payload
    integer,intent(out)::status
    type(matrix_joint_restart_t)::trial
    logical::ok
    integer::code
    payload=matrix_joint_restart_t();status=JOINT_INVALID
    if(column%state_handle/=1.or..not.bounded_template(template))return
    if(.not.matrix_joint_states_match(water,chemical))return
    call fmr_export_committed_restart([column],[template],[water],parameter_set_id,trial%water,ok,code)
    if(.not.ok.or.code/=FMR_RESTART_OK)return
    call export_matrix_solute_restart(chemical,trial%chemical,code)
    if(code/=MATRIX_OK)return
    payload=trial;status=JOINT_OK
  end subroutine

  subroutine restore_matrix_joint_restart(payload,column,template,water_parameter_id,chemical_parameter_id, &
       water,chemical,status)
    type(matrix_joint_restart_t),intent(in)::payload
    type(fmr_logical_column_t),intent(in)::column
    type(fmr_template_t),intent(in)::template
    integer(int64),intent(in)::water_parameter_id,chemical_parameter_id
    type(kernel_committed_state_t),intent(inout)::water
    type(matrix_solute_state_t),intent(inout)::chemical
    integer,intent(out)::status
    type(kernel_committed_state_t)::water_trial(1)
    type(matrix_solute_state_t)::chemical_trial
    logical::ok
    integer::code
    status=JOINT_INVALID
    if(payload%schema/=1)return
    if(water%ready())return
    if(chemical%ready())return
    if(column%state_handle/=1.or..not.bounded_template(template))return
    call fmr_restore_committed_restart(payload%water,water_parameter_id,[column],[template],water_trial,ok,code)
    if(.not.ok.or.code/=FMR_RESTART_OK)return
    call restore_matrix_solute_restart(payload%chemical,chemical_parameter_id,chemical_trial,code)
    if(code/=MATRIX_OK)return
    if(.not.matrix_joint_states_match(water_trial(1),chemical_trial))return
    water=water_trial(1);chemical=chemical_trial;status=JOINT_OK
  end subroutine
end module
