module mod_fmr_crop_soil_n_material_application
 use iso_fortran_env,only:real64
 use mod_canonical_contracts,only:canonical_numerical_config_t
 use mod_fmr_runtime_core,only:fmr_logical_column_t,fmr_template_t
 use mod_kernel_transactions,only:kernel_committed_state_t
 use mod_fmr_serialized_reference_backend,only:fmr_serialized_reference_backend_t, &
   fmr_b110_physical_parameters_t,fmr_b110_physical_forcing_t
 use mod_fmr_crop_soil_n_joint_application
 use mod_crop_soil_n_material_day
 use mod_crop_soil_n_day,only:crop_soil_state_t
 use mod_b111_soil_n_addition,only:b111_soil_n_split_parameters_t
 use mod_wofost_one_day_structural_evolution,only:wofost_one_day_forcing_t
 use mod_soil_n_day_environment,only:soil_n_day_environment_t
 implicit none
 private
 type,public::material_joint_result_t
  integer::status=JOINT_INVALID
  type(crop_soil_n_joint_result_t)::joint
  type(material_day_receipt_t)::materials
 end type
 public::run_crop_soil_n_material_interval
contains
 subroutine run_crop_soil_n_material_interval(backend,column,template,parameters,water,forcing,config, &
     chemical,weather,t0,t1,items,split,result,environment,fallow,clean_surface_water,atmospheric_n_surface)
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
  type(material_joint_result_t),intent(out)::result
  type(soil_n_day_environment_t),optional,intent(in)::environment
  logical,optional,intent(in)::fallow,clean_surface_water,atmospheric_n_surface
  type(crop_soil_state_t)::trial
  type(kernel_committed_state_t)::water_trial
  result=material_joint_result_t()
  call stage_crop_soil_materials(chemical,t0,items,split,trial,result%materials)
  if(result%materials%status/=MATERIAL_OK)return
  water_trial=water
  call run_crop_soil_n_joint_interval(backend,column,template,parameters,water_trial,forcing,config, &
    trial,weather,t0,t1,result%joint,environment,fallow,clean_surface_water,atmospheric_n_surface)
  result%status=result%joint%status
  if(result%status/=JOINT_OK)return
  call check_crop_soil_material_day(trial,result%joint%chemical,result%materials)
  if(result%materials%status/=MATERIAL_OK)then;result%status=JOINT_CHEMICAL_REJECTED;return;end if
  water=water_trial;chemical=trial
 end subroutine
end module
