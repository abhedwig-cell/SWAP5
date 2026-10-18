module mod_fmr_b111_reactive_n_joint_application
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
  use mod_b111_soil_n_reactive_owner
  use mod_b111_soil_n_mineral_owner,only:MINERAL_OK
  use mod_soil_n_pool_state,only:soil_n_pool_state_t
  use mod_fmr_b111_reactive_n_route,only:consume_reactive_n_trace
  implicit none
  private
  integer,parameter,public::JOINT_OK=0,JOINT_INVALID=1,JOINT_WATER_REJECTED=2, &
       JOINT_CHEMICAL_REJECTED=3,JOINT_COMMIT_REJECTED=4
  type,public::reactive_n_joint_result_t
    integer::status=JOINT_INVALID
    type(kernel_result_t)::water
    type(kernel_diagnostics_t)::diagnostics
    type(reactive_receipt_t)::chemical
  end type
  type,public::reactive_n_joint_restart_t
    private
    integer::schema=1
    type(fmr_committed_restart_bundle_t)::water
    type(reactive_restart_t)::chemical
  end type
  public::run_reactive_n_joint_interval,reactive_n_joint_states_match
  public::export_reactive_n_joint_restart,restore_reactive_n_joint_restart
  public::reactive_n_thermal_states_match
contains
  logical function reactive_n_joint_states_match(water,chemical) result(ok)
    type(kernel_committed_state_t),intent(in)::water
    type(reactive_state_t),intent(in)::chemical
    ok=states_match(water,chemical,.false.)
  end function

  logical function reactive_n_thermal_states_match(water,chemical) result(ok)
    type(kernel_committed_state_t),intent(in)::water
    type(reactive_state_t),intent(in)::chemical
    ok=states_match(water,chemical,.true.)
  end function

  logical function states_match(water,chemical,thermal) result(ok)
    use mod_kernel_transactions,only:kernel_parameter_identity_t
    use mod_soil_temperature_contract,only:soil_temperature_field_view_t,build_soil_temperature_field_view,SOIL_TEMP_OK
    type(kernel_committed_state_t),intent(in)::water
    type(reactive_state_t),intent(in)::chemical
    logical,intent(in)::thermal
    type(kernel_parameter_identity_t)::identity
    class(transaction_state_t),allocatable::physical
    type(soil_n_pool_state_t)::s
    type(reactive_parameters_t)::parameters
    integer(int64)::id
    real(real64)::theta
    real(real64)::t,wt
    integer(int64)::revision
    logical::available
    ok=.false.
    if(.not.water%ready())return
    if(.not.chemical%ready())return
    call water%current_time(wt,available)
    if(.not.available)return
    call chemical%snapshot(t,theta,s,revision)
    call chemical%configuration(parameters,id)
    if(abs(t-wt)>0.0_real64)return
    if(thermal)then
      call water%certified_parameter_identity(identity,available)
      if(.not.available.or..not.identity%heat_enabled)return
      if(.not.allocated(identity%dz))return
      if(size(identity%dz)/=size(parameters%mineral%dz_cm))return
      if(any(identity%dz/=parameters%mineral%dz_cm))return
    end if
    call water%snapshot(physical,available)
    if(.not.available)return
    select type(p=>physical)
    type is(fmr_b110_physical_state_t)
      call check(p)
    type is(fmr_b110_temporal_indicator_state_t)
      call check(p)
    end select
  contains
    subroutine check(p)
      class(fmr_b110_physical_state_t),intent(in)::p
      type(soil_temperature_field_view_t)::heat
      integer::code
      if(thermal)then
        if(.not.allocated(p%soil_temperature))return
        call build_soil_temperature_field_view(p%soil_temperature,heat,code)
        if(code/=SOIL_TEMP_OK.or.heat%active_nodes/=p%active_nodes)return
        if(.not.all(ieee_is_finite(heat%temperature_c)))return
      end if
      ok=bounded_physical(p,theta,parameters,thermal)
    end subroutine
  end function

  logical function bounded_physical(p,theta,parameters,thermal) result(ok)
    class(fmr_b110_physical_state_t),intent(in)::p
    real(real64),intent(in)::theta
    type(reactive_parameters_t),intent(in)::parameters
    logical,intent(in)::thermal
    integer::n
    real(real64)::scale
    ok=.false.
    if(allocated(p%salt).or.allocated(p%macropore).or.allocated(p%snow).or. &
         allocated(p%rutter))return
    if(.not.thermal.and.allocated(p%soil_temperature))return
    if(.not.allocated(p%water_content).or..not.allocated(p%pressure_head))return
    n=size(parameters%mineral%dz_cm)
    if(p%active_nodes/=n.or.size(p%water_content)/=n.or.size(p%pressure_head)/=n)return
    if(.not.all(ieee_is_finite(p%water_content)).or..not.all(ieee_is_finite(p%pressure_head)))return
    if(.not.all(ieee_is_finite([p%ponding_depth,p%groundwater_level])))return
    if(parameters%mineral%surface_n_enabled)then
      if(p%ponding_depth<0d0.or.p%ponding_depth>1d6)return
    else
      if(abs(p%ponding_depth)>0d0)return
    end if
    if(any(p%water_content<1d-4).or.any(p%water_content>1d0).or.any(abs(p%pressure_head)>1d12))return
    scale=max(1.0_real64,abs(theta))
    ok=abs(sum(parameters%mineral%dz_cm*p%water_content)/sum(parameters%mineral%dz_cm)-theta)<=1024d0*epsilon(1d0)*scale
  end function

  logical function bounded_template(t) result(ok)
    type(fmr_template_t),intent(in)::t
    ok=t%optional_state_layout_id==FMR_OPTIONAL_STATE_LAYOUT_BASE.and. &
         t%solute_state_layout_id==FMR_SOLUTE_STATE_LAYOUT_NONE.and. &
         (t%numerical_continuation_layout_id==FMR_NUMERICAL_CONTINUATION_NONE.or. &
          t%numerical_continuation_layout_id==FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY)
  end function

  subroutine run_reactive_n_joint_interval(backend,column,template,parameters,water,forcing,config,chemical,t0,t1,result)
    type(fmr_serialized_reference_backend_t),intent(inout)::backend
    type(fmr_logical_column_t),intent(in)::column
    type(fmr_template_t),intent(in)::template
    type(fmr_b110_physical_parameters_t),target,intent(in)::parameters
    type(kernel_committed_state_t),intent(inout)::water
    type(fmr_b110_physical_forcing_t),intent(in)::forcing
    type(canonical_numerical_config_t),intent(in)::config
    type(reactive_state_t),intent(inout)::chemical
    real(real64),intent(in)::t0,t1
    type(reactive_n_joint_result_t),intent(out)::result
    type(kernel_checkpoint_t)::checkpoint
    type(kernel_candidate_state_t)::candidate
    type(fmr_serialized_physical_observation_t)::obs
    type(reactive_state_t)::chemical_trial
    logical::ok,did_commit
    integer::status
    real(real64)::clock
    type(reactive_parameters_t)::np
    integer(int64)::nid
    result=reactive_n_joint_result_t()
    if(.not.bounded_template(template))return
    call chemical%configuration(np,nid)
    if(.not.allocated(np%mineral%dz_cm))return
    if(.not.allocated(parameters%dz))return
    if(size(np%mineral%dz_cm)/=size(parameters%dz))return
    if(any(abs(np%mineral%dz_cm-parameters%dz)>0d0))return
    if(.not.reactive_n_joint_states_match(water,chemical))return
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
    call consume_reactive_n_trace(chemical_trial,obs%accepted_water_flux_substeps,result%chemical)
    result%status=JOINT_CHEMICAL_REJECTED
    if(result%chemical%status/=MINERAL_OK)then
      call backend%discard_trial_candidate(candidate,result%diagnostics)
      return
    end if
    result%status=JOINT_COMMIT_REJECTED
    call backend%commit_trial_candidate(water,candidate,result%diagnostics,did_commit,status)
    if(.not.did_commit)return
    chemical=chemical_trial
    result%status=JOINT_OK
  end subroutine

  subroutine export_reactive_n_joint_restart(column,template,parameter_set_id,water,chemical,payload,status)
    type(fmr_logical_column_t),intent(in)::column
    type(fmr_template_t),intent(in)::template
    integer(int64),intent(in)::parameter_set_id
    type(kernel_committed_state_t),intent(in)::water
    type(reactive_state_t),intent(in)::chemical
    type(reactive_n_joint_restart_t),intent(out)::payload
    integer,intent(out)::status
    type(reactive_n_joint_restart_t)::trial
    logical::ok
    integer::code
    payload=reactive_n_joint_restart_t();status=JOINT_INVALID
    if(column%state_handle/=1.or..not.bounded_template(template))return
    if(.not.reactive_n_joint_states_match(water,chemical))return
    call fmr_export_committed_restart([column],[template],[water],parameter_set_id,trial%water,ok,code)
    if(.not.ok.or.code/=FMR_RESTART_OK)return
    call export_reactive_restart(chemical,trial%chemical,code)
    if(code/=MINERAL_OK)return
    payload=trial;status=JOINT_OK
  end subroutine

  subroutine restore_reactive_n_joint_restart(payload,column,template,water_parameter_id,chemical_parameter_id, &
       water,chemical,status)
    type(reactive_n_joint_restart_t),intent(in)::payload
    type(fmr_logical_column_t),intent(in)::column
    type(fmr_template_t),intent(in)::template
    integer(int64),intent(in)::water_parameter_id,chemical_parameter_id
    type(kernel_committed_state_t),intent(inout)::water
    type(reactive_state_t),intent(inout)::chemical
    integer,intent(out)::status
    type(kernel_committed_state_t)::water_trial(1)
    type(reactive_state_t)::chemical_trial
    logical::ok
    integer::code
    status=JOINT_INVALID
    if(payload%schema/=1)return
    if(water%ready())return
    if(chemical%ready())return
    if(column%state_handle/=1.or..not.bounded_template(template))return
    call fmr_restore_committed_restart(payload%water,water_parameter_id,[column],[template],water_trial,ok,code)
    if(.not.ok.or.code/=FMR_RESTART_OK)return
    call restore_reactive_restart(payload%chemical,chemical_parameter_id,chemical_trial,code)
    if(code/=MINERAL_OK)return
    if(.not.reactive_n_joint_states_match(water_trial(1),chemical_trial))return
    water=water_trial(1);chemical=chemical_trial;status=JOINT_OK
  end subroutine
end module
