! Explicit accepted-temperature composition for a physically retired crop.
module mod_fmr_crop_soil_n_thermal_fallow
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_canonical_contracts,only:canonical_numerical_config_t
 use mod_fmr_runtime_core
 use mod_kernel_transactions,only:kernel_committed_state_t,kernel_checkpoint_t,kernel_candidate_state_t
 use mod_fmr_serialized_reference_backend
 use mod_fmr_crop_soil_n_thermal_application,only:soil_n_thermal_template,thermal_crop_soil_states_match
 use mod_fmr_crop_soil_n_material_application,only:material_joint_result_t
 use mod_fmr_crop_soil_n_joint_application,only:JOINT_OK,JOINT_WATER_REJECTED,JOINT_CHEMICAL_REJECTED,JOINT_COMMIT_REJECTED
 use mod_fmr_b111_mineral_route,only:aggregate_mineral_trace,mineral_daily_carrier_t
 use mod_fmr_soil_n_accepted_temperature,only:sample_accepted_soil_n_environment
 use mod_b111_soil_n_mineral_owner,only:mineral_state_t,MINERAL_OK
 use mod_b111_soil_n_reactive_owner,only:reactive_state_t,reactive_parameters_t
 use mod_b111_soil_n_addition,only:b111_soil_n_split_parameters_t
 use mod_crop_soil_n_day,only:crop_soil_state_t,advance_crop_soil_fallow_day
 use mod_crop_soil_n_material_day
 use mod_wofost81_crop_owner_state,only:wofost81_crop_owner_state_t
 use mod_soil_n_day_environment,only:soil_n_day_environment_t
 implicit none
 private
 public::run_crop_soil_n_thermal_fallow_interval
contains
 subroutine run_crop_soil_n_thermal_fallow_interval(backend,column,template,parameters,water,forcing,config, &
   chemical,t0,t1,items,split,result)
  type(fmr_serialized_reference_backend_t),intent(inout)::backend
  type(fmr_logical_column_t),intent(in)::column
  type(fmr_template_t),intent(in)::template
  type(fmr_b110_physical_parameters_t),target,intent(in)::parameters
  type(kernel_committed_state_t),intent(inout)::water
  type(fmr_b110_physical_forcing_t),intent(in)::forcing
  type(canonical_numerical_config_t),intent(in)::config
  type(crop_soil_state_t),intent(inout)::chemical
  real(real64),intent(in)::t0,t1
  type(soil_n_material_input_t),intent(in)::items(:)
  type(b111_soil_n_split_parameters_t),intent(in)::split
  type(material_joint_result_t),intent(out)::result
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
  result=material_joint_result_t()
  if(.not.soil_n_thermal_template(template))return
  if(.not.thermal_crop_soil_states_match(water,chemical))return
  if(.not.all(ieee_is_finite([t0,t1])))return
  if(max(abs(t0),abs(t1))>1d8)return
  call water%current_time(clock,ok);if(.not.ok)return
  if(clock/=t0.or.t1-t0/=1d0)return
  call chemical%snapshot(soil,crop)
  if(.not.crop%harvest_retired())return
  if(.not.allocated(forcing%root_extraction_sink))return
  if(.not.all(ieee_is_finite([forcing%root_extraction_sink,forcing%root_potential_transpiration])))return
  if(any(forcing%root_extraction_sink/=0d0).or.forcing%root_potential_transpiration/=0d0)return
  call soil%configuration(p,id)
  if(any(p%mineral%c_top/=0d0))return ! no implicit atmospheric carrier contract
  if(.not.allocated(parameters%dz).or..not.allocated(p%mineral%dz_cm))return
  if(size(p%mineral%dz_cm)/=size(parameters%dz))return
  if(any(p%mineral%dz_cm/=parameters%dz))return
  call stage_crop_soil_materials(chemical,t0,items,split,n,result%materials)
  if(result%materials%status/=MATERIAL_OK)return
  w=water
  call w%capture_checkpoint(checkpoint,ok);if(.not.ok)return
  call backend%run_trial(column,template,parameters,w,forcing,config,t0,t1,checkpoint, &
   result%joint%water,candidate,result%joint%diagnostics,trace_accepted_water_flux_substeps=.true., &
   trace_accepted_soil_n_heat=.true.)
  result%status=JOINT_WATER_REJECTED
  if(.not.result%joint%water%completed.or..not.candidate%ready())return
  obs=backend%observation()
  if(.not.obs%accepted_water_flux_trace_available.or..not.allocated(obs%accepted_water_flux_substeps))then
   call backend%discard_trial_candidate(candidate,result%joint%diagnostics);return
  end if
  result%status=JOINT_COMMIT_REJECTED
  call backend%commit_trial_candidate(w,candidate,result%joint%diagnostics,committed,code)
  if(.not.committed)return
  result%status=JOINT_CHEMICAL_REJECTED
  call sample_accepted_soil_n_environment(w,w%current_lineage_id(),w%current_revision(),t0,t1, &
   p%mineral%inventory%depth_m,environment,depth,code)
  if(code/=0)return
  call n%snapshot(soil,crop);call soil%mineral_snapshot(base)
  call aggregate_mineral_trace(base,obs%accepted_water_flux_substeps,carrier,code)
  if(code/=MINERAL_OK)return
  call advance_crop_soil_fallow_day(n,t0,t1,carrier%water_end,carrier%outflow,carrier%in_bottom, &
   carrier%in_lateral,carrier%root_water,forcing%root_potential_transpiration,result%joint%chemical,environment, &
   surface_water=carrier%surface_water)
  if(result%joint%chemical%status/=0)return
  call check_crop_soil_material_day(n,result%joint%chemical,result%materials)
  if(result%materials%status/=MATERIAL_OK)return
  if(.not.thermal_crop_soil_states_match(w,n))return
  water=w;chemical=n;result%status=JOINT_OK;result%joint%status=JOINT_OK
 end subroutine
end module
