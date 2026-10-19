module mod_b111_n_reference_joint_application
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_transaction_reference,only:transaction_state_t
 use mod_canonical_contracts,only:canonical_numerical_config_t
 use mod_fmr_runtime_core,only:fmr_logical_column_t,fmr_template_t, &
   FMR_OPTIONAL_STATE_LAYOUT_BASE,FMR_SOLUTE_STATE_LAYOUT_NONE
 use mod_kernel_transactions,only:kernel_committed_state_t,kernel_checkpoint_t, &
   kernel_candidate_state_t,kernel_result_t,kernel_diagnostics_t
 use mod_fmr_serialized_reference_backend,only:fmr_serialized_reference_backend_t, &
   fmr_b110_physical_parameters_t,fmr_b110_physical_forcing_t, &
   fmr_serialized_physical_observation_t,fmr_b110_physical_state_t
 use mod_b111_soil_n_mineral_owner,only:mineral_state_t,mineral_parameters_t, &
   mineral_receipt_t
 use mod_soil_n_pool_state,only:soil_n_pool_state_t
 use mod_b111_n_reference_mineral_trial,only:trial_mineral_from_reference_gross,N_TRIAL_OK
 implicit none
 private
 integer,parameter,public::N_JOINT_OK=0,N_JOINT_REJECT=1
 type,public::n_joint_result_t
  integer::status=N_JOINT_REJECT
  type(kernel_result_t)::water
  type(kernel_diagnostics_t)::diagnostics
  type(mineral_receipt_t)::nitrogen
 end type
 public::run_reference_mineral_gross_joint
contains
 subroutine run_reference_mineral_gross_joint(backend,column,template,parameters, &
   water,forcing,config,nitrogen,t0,t1,result)
  type(fmr_serialized_reference_backend_t),intent(inout)::backend
  type(fmr_logical_column_t),intent(in)::column
  type(fmr_template_t),intent(in)::template
  type(fmr_b110_physical_parameters_t),target,intent(in)::parameters
  type(kernel_committed_state_t),intent(inout)::water
  type(fmr_b110_physical_forcing_t),intent(in)::forcing
  type(canonical_numerical_config_t),intent(in)::config
  type(mineral_state_t),intent(inout)::nitrogen
  real(real64),intent(in)::t0,t1
  type(n_joint_result_t),intent(out)::result
  type(kernel_checkpoint_t)::checkpoint
  type(kernel_candidate_state_t)::candidate
  type(kernel_committed_state_t)::water_trial
  type(mineral_state_t)::nitrogen_trial
  type(mineral_parameters_t)::np
  type(soil_n_pool_state_t)::pools
  type(fmr_serialized_physical_observation_t)::obs
  class(transaction_state_t),allocatable::physical
  real(real64)::nt,nwater,wt,theta
  integer(int64)::revision,nidentity
  logical::ok,committed
  integer::status,ncode
  result=n_joint_result_t()
  if(template%optional_state_layout_id/=FMR_OPTIONAL_STATE_LAYOUT_BASE.or. &
     template%solute_state_layout_id/=FMR_SOLUTE_STATE_LAYOUT_NONE)return
  if(.not.water%ready().or..not.nitrogen%ready())return
  call water%current_time(wt,ok)
  if(.not.ok)return
  call nitrogen%snapshot(nt,nwater,pools,revision)
  if(.not.all(ieee_is_finite([t0,t1,wt,nt,nwater])))return
  if(abs(wt-t0)>0d0.or.abs(nt-t0)>0d0.or.abs(t1-t0-1d0)>0d0)return
  call nitrogen%configuration(np,nidentity)
  if(.not.allocated(np%dz_cm))return
  if(size(np%dz_cm)/=1)return
  call water%snapshot(physical,ok)
  if(.not.ok)return
  select type(p=>physical)
  class is(fmr_b110_physical_state_t)
    if(.not.allocated(p%water_content))return
    if(size(p%water_content)/=1.or.p%active_nodes/=1)return
    if(abs(p%water_content(1)-nwater)>1d-12)return
    if(abs(p%ponding_depth)>0d0)return
  class default
    return
  end select
  call water%capture_checkpoint(checkpoint,ok)
  if(.not.ok)return
  call backend%run_trial(column,template,parameters,water,forcing,config,t0,t1, &
    checkpoint,result%water,candidate,result%diagnostics, &
    trace_accepted_water_flux_substeps=.true.)
  if(.not.result%water%completed.or..not.candidate%ready())return
  obs=backend%observation()
  if(.not.obs%accepted_water_flux_trace_available.or. &
     .not.allocated(obs%accepted_water_flux_substeps))then
    call backend%discard_trial_candidate(candidate,result%diagnostics)
    return
  end if
  if(size(obs%accepted_water_flux_substeps)/=1)then
    call backend%discard_trial_candidate(candidate,result%diagnostics)
    return
  end if
  if(.not.allocated(obs%accepted_water_flux_substeps(1)%water_end))then
    call backend%discard_trial_candidate(candidate,result%diagnostics)
    return
  end if
  if(size(obs%accepted_water_flux_substeps(1)%water_end)/=1)then
    call backend%discard_trial_candidate(candidate,result%diagnostics)
    return
  end if
  theta=obs%accepted_water_flux_substeps(1)%water_end(1)
  call trial_mineral_from_reference_gross(nitrogen, &
    obs%accepted_water_flux_substeps(1),theta,0d0,0d0,0d0,0d0, &
    nitrogen_trial,result%nitrogen,status)
  if(status/=N_TRIAL_OK)then
    call backend%discard_trial_candidate(candidate,result%diagnostics)
    return
  end if
  water_trial=water
  call backend%commit_trial_candidate(water_trial,candidate, &
     result%diagnostics,committed,ncode)
  if(.not.committed)return
  call water_trial%snapshot(physical,ok)
  if(.not.ok)return
  select type(p=>physical)
  class is(fmr_b110_physical_state_t)
    if(.not.allocated(p%water_content))return
    if(size(p%water_content)/=1)return
    if(abs(p%water_content(1)-theta)>1d-12)return
  class default
    return
  end select
  water=water_trial
  nitrogen=nitrogen_trial
  result%status=N_JOINT_OK
 end subroutine
end module
