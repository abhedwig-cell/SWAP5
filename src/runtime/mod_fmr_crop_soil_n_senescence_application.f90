module mod_fmr_crop_soil_n_senescence_application
 use iso_fortran_env,only:real64
 use mod_canonical_contracts,only:canonical_numerical_config_t
 use mod_fmr_runtime_core,only:fmr_logical_column_t,fmr_template_t
 use mod_kernel_transactions,only:kernel_committed_state_t
 use mod_fmr_serialized_reference_backend,only:fmr_serialized_reference_backend_t, &
   fmr_b110_physical_parameters_t,fmr_b110_physical_forcing_t
 use mod_fmr_crop_soil_n_joint_application
 use mod_fmr_crop_soil_n_material_application
 use mod_crop_soil_n_material_day
 use mod_crop_soil_n_senescence_day
 use mod_crop_soil_n_day,only:crop_soil_state_t
 use mod_crop_senescence_residue
 use mod_b111_soil_n_addition,only:b111_soil_n_split_parameters_t
 use mod_wofost_one_day_structural_evolution,only:wofost_one_day_forcing_t
 use mod_soil_n_day_environment,only:soil_n_day_environment_t
 implicit none
 private
 type,public::senescence_joint_result_t
  integer::status=JOINT_INVALID
  type(material_joint_result_t)::joint
  type(senescence_day_receipt_t)::senescence
 end type
 public::run_crop_soil_n_senescence_interval
contains
 subroutine run_crop_soil_n_senescence_interval(backend,column,template,parameters,water,forcing,config, &
     chemical,weather,t0,t1,items,split,policy,result,environment,clean_surface_water,atmospheric_n_surface,historical_top_water)
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
  type(soil_n_day_environment_t),optional,intent(in)::environment
  logical,optional,intent(in)::clean_surface_water,atmospheric_n_surface
  real(real64),intent(in),optional::historical_top_water
  type(crop_soil_state_t)::trial,completed
  type(kernel_committed_state_t)::water_trial
  result=senescence_joint_result_t()
  call prepare_senescence_day(chemical,t0,trial,result%senescence)
  if(result%senescence%status/=0)return
  water_trial=water
  call run_crop_soil_n_material_interval(backend,column,template,parameters,water_trial,forcing,config, &
    trial,weather,t0,t1,items,split,result%joint,environment,clean_surface_water=clean_surface_water,atmospheric_n_surface=atmospheric_n_surface,historical_top_water=historical_top_water)
  result%status=result%joint%status;if(result%status/=JOINT_OK)return
  result%senescence%materials=result%joint%materials
  call finish_senescence_day(trial,t1,policy,result%senescence,completed)
  if(result%senescence%status/=0)then;result%status=JOINT_CHEMICAL_REJECTED;return;end if
  water=water_trial;chemical=completed
 end subroutine
end module
