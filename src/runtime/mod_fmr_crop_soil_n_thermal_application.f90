module mod_fmr_crop_soil_n_thermal_application
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_canonical_contracts,only:canonical_numerical_config_t
 use mod_fmr_runtime_core
 use mod_kernel_transactions,only:kernel_committed_state_t,kernel_checkpoint_t,kernel_candidate_state_t
 use mod_kernel_committed_persistence
 use mod_fmr_serialized_reference_backend
 use mod_fmr_committed_restart,only:fmr_restart_template_identity_matches,fmr_committed_restart_bundle_t, &
  fmr_export_committed_restart,FMR_RESTART_OK
 use mod_fmr_crop_soil_n_joint_application,only:JOINT_OK,JOINT_INVALID,JOINT_WATER_REJECTED, &
   JOINT_CHEMICAL_REJECTED,JOINT_COMMIT_REJECTED
 use mod_fmr_crop_soil_n_senescence_application,only:senescence_joint_result_t
 use mod_fmr_b111_reactive_n_joint_application,only:reactive_n_thermal_states_match
 use mod_fmr_b111_mineral_route,only:aggregate_mineral_trace,mineral_daily_carrier_t
 use mod_fmr_soil_n_accepted_temperature
 use mod_b111_soil_n_mineral_owner,only:mineral_state_t,MINERAL_OK
 use mod_b111_soil_n_reactive_owner
 use mod_b111_soil_n_addition,only:b111_soil_n_split_parameters_t
 use mod_crop_soil_n_configuration
 use mod_crop_soil_n_day
 use mod_crop_soil_n_material_day,only:soil_n_material_input_t
 use mod_crop_soil_n_senescence_day
 use mod_crop_senescence_residue,only:crop_senescence_policy_t
 use mod_wofost81_crop_owner_state,only:wofost81_crop_owner_state_t
 use mod_wofost_one_day_structural_evolution,only:wofost_one_day_forcing_t
 use mod_soil_n_day_environment,only:soil_n_day_environment_t
 implicit none
 private
 type,public::crop_soil_n_thermal_restart_t
  private
  type(kernel_persistence_snapshot_t)::water
  type(crop_soil_state_t)::chemical
  type(fmr_logical_column_t)::column
  type(fmr_template_t)::template
  integer(int64)::parameter_set_id=0
 end type
 public::run_crop_soil_n_thermal_interval,thermal_crop_soil_states_match,soil_n_thermal_template
 public::export_crop_soil_n_thermal_restart,restore_crop_soil_n_thermal_restart
contains
 logical function soil_n_thermal_template(t)result(ok)
  type(fmr_template_t),intent(in)::t
  ok=t%optional_state_layout_id==FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE.and. &
   t%solute_state_layout_id==FMR_SOLUTE_STATE_LAYOUT_NONE.and. &
   (t%numerical_continuation_layout_id==FMR_NUMERICAL_CONTINUATION_NONE.or. &
    t%numerical_continuation_layout_id==FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY)
 end function
 logical function thermal_crop_soil_states_match(water,chemical)result(ok)
  type(kernel_committed_state_t),intent(in)::water
  type(crop_soil_state_t),intent(in)::chemical
  type(reactive_state_t)::soil
  type(wofost81_crop_owner_state_t)::crop
  ok=.false.;if(.not.chemical%ready())return
  call chemical%snapshot(soil,crop)
  ok=reactive_n_thermal_states_match(water,soil).and.pending_incorporation_valid(chemical)
 end function

 subroutine run_crop_soil_n_thermal_interval(backend,column,template,parameters,water,forcing,config, &
   chemical,weather,t0,t1,items,split,policy,result)
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
  type(soil_n_material_input_t),intent(in)::items(:)
  type(b111_soil_n_split_parameters_t),intent(in)::split
  type(crop_senescence_policy_t),intent(in)::policy
  type(senescence_joint_result_t),intent(out)::result
  type(kernel_committed_state_t)::w
  type(crop_soil_state_t)::n
  type(kernel_checkpoint_t)::checkpoint
  type(kernel_candidate_state_t)::candidate
  type(fmr_serialized_physical_observation_t)::obs
  type(reactive_state_t)::soil
  type(reactive_parameters_t)::p
  type(wofost81_crop_owner_state_t)::crop
  type(mineral_state_t)::base
  type(mineral_daily_carrier_t)::carrier
  type(soil_n_day_environment_t)::environment
  integer(int64)::id
  real(real64)::clock,depth
  integer::code
  logical::ok,committed
  result=senescence_joint_result_t()
  if(.not.soil_n_thermal_template(template))return
  if(.not.thermal_crop_soil_states_match(water,chemical))return
  if(.not.ieee_is_finite(t0).or..not.ieee_is_finite(t1))return
  if(max(abs(t0),abs(t1))>1d9)return
  call water%current_time(clock,ok);if(.not.ok)return
  if(clock/=t0.or.t1-t0/=1d0)return
  call chemical%snapshot(soil,crop);call soil%configuration(p,id)
  if(.not.allocated(parameters%dz))return
  if(size(p%mineral%dz_cm)/=size(parameters%dz))return
  if(any(p%mineral%dz_cm/=parameters%dz))return
  w=water;n=chemical
  call w%capture_checkpoint(checkpoint,ok);if(.not.ok)return
  call backend%run_trial(column,template,parameters,w,forcing,config,t0,t1,checkpoint, &
   result%joint%joint%water,candidate,result%joint%joint%diagnostics,trace_accepted_water_flux_substeps=.true., &
   trace_accepted_soil_n_heat=.true.)
  result%status=JOINT_WATER_REJECTED
  if(.not.result%joint%joint%water%completed.or..not.candidate%ready())return
  obs=backend%observation()
  if(.not.obs%accepted_water_flux_trace_available.or..not.allocated(obs%accepted_water_flux_substeps))then
   call backend%discard_trial_candidate(candidate,result%joint%joint%diagnostics);return
  end if
  result%status=JOINT_COMMIT_REJECTED
  call backend%commit_trial_candidate(w,candidate,result%joint%joint%diagnostics,committed,code)
  if(.not.committed)return
  result%status=JOINT_CHEMICAL_REJECTED
  call sample_accepted_soil_n_environment(w,w%current_lineage_id(),w%current_revision(),t0,t1, &
   p%mineral%inventory%depth_m,environment,depth,code)
  if(code/=0)return
  call soil%mineral_snapshot(base)
  call aggregate_mineral_trace(base,obs%accepted_water_flux_substeps,carrier,code)
  if(code/=MINERAL_OK)return
  call advance_crop_soil_senescence_day(n,t0,t1,carrier%water_end,carrier%outflow,carrier%in_bottom, &
   carrier%in_lateral,carrier%root_water,forcing%root_potential_transpiration,weather,items,split,policy, &
   result%senescence,environment)
  result%joint%materials=result%senescence%materials
  result%joint%joint%chemical=result%senescence%materials%day
  if(result%senescence%status/=0)return
  if(.not.thermal_crop_soil_states_match(w,n))return
  water=w;chemical=n;result%status=JOINT_OK
  result%joint%status=JOINT_OK;result%joint%joint%status=JOINT_OK
 end subroutine

 subroutine export_crop_soil_n_thermal_restart(column,template,parameter_set_id,water,chemical,payload,status)
  type(fmr_logical_column_t),intent(in)::column
  type(fmr_template_t),intent(in)::template
  integer(int64),intent(in)::parameter_set_id
  type(kernel_committed_state_t),intent(in)::water
  type(crop_soil_state_t),intent(in)::chemical
  type(crop_soil_n_thermal_restart_t),intent(out)::payload
  integer,intent(out)::status
  type(crop_soil_n_thermal_restart_t)::p
  type(fmr_committed_restart_bundle_t)::validated
  logical::ok
  integer::code
  payload=crop_soil_n_thermal_restart_t();status=JOINT_INVALID
  if(column%state_handle/=1.or.parameter_set_id<=0)return
  if(.not.soil_n_thermal_template(template))return
  if(.not.thermal_crop_soil_states_match(water,chemical))return
  call fmr_export_committed_restart([column],[template],[water],parameter_set_id,validated,ok,code)
  if(.not.ok.or.code/=FMR_RESTART_OK)return
  call export_kernel_committed_state(water,template%state_layout_id,p%water,ok,code)
  if(.not.ok.or.code/=KERNEL_PERSISTENCE_OK)return
  p%chemical=chemical;p%column=column;p%template=template;p%parameter_set_id=parameter_set_id
  payload=p;status=JOINT_OK
 end subroutine
 subroutine restore_crop_soil_n_thermal_restart(payload,column,template,water_parameter_id,crop_parameter_id, &
   water,chemical,status)
  type(crop_soil_n_thermal_restart_t),intent(in)::payload
  type(fmr_logical_column_t),intent(in)::column
  type(fmr_template_t),intent(in)::template
  integer(int64),intent(in)::water_parameter_id,crop_parameter_id
  type(kernel_committed_state_t),intent(inout)::water
  type(crop_soil_state_t),intent(inout)::chemical
  integer,intent(out)::status
  type(kernel_committed_state_t)::w
  type(crop_n_configuration_t)::cp
  integer(int64)::id
  logical::ok
  integer::code
  status=JOINT_INVALID
  if(water%ready().or.chemical%ready())return
  if(column%state_handle/=1.or.water_parameter_id/=payload%parameter_set_id)return
  if(.not.soil_n_thermal_template(template))return
  if(.not.fmr_restart_template_identity_matches(template,payload%template))return
  if(column%column_id/=payload%column%column_id.or.column%parameter_ref/=payload%column%parameter_ref.or. &
   column%forcing_handle/=payload%column%forcing_handle.or.column%backend_id/=payload%column%backend_id.or. &
   column%template_id/=payload%column%template_id)return
  call payload%chemical%configuration(cp,id);if(id/=crop_parameter_id)return
  call restore_kernel_committed_state(payload%water,template%state_layout_id,w,ok,code)
  if(.not.ok.or.code/=KERNEL_PERSISTENCE_OK)return
  if(.not.thermal_crop_soil_states_match(w,payload%chemical))return
  water=w;chemical=payload%chemical;status=JOINT_OK
 end subroutine
end module
