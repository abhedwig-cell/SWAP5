module mod_fmr_crop_soil_n_calendar_application
 use iso_fortran_env,only:real64
 use mod_canonical_contracts,only:canonical_numerical_config_t
 use mod_fmr_runtime_core,only:fmr_logical_column_t,fmr_template_t
 use mod_kernel_transactions,only:kernel_committed_state_t
 use mod_fmr_serialized_reference_backend,only:fmr_serialized_reference_backend_t, &
   fmr_b110_physical_parameters_t,fmr_b110_physical_forcing_t
 use mod_fmr_crop_soil_n_material_application
 use mod_crop_soil_n_calendar_day,only:select_calendar_materials
 use mod_crop_soil_n_material_day,only:soil_n_material_input_t
 use mod_crop_soil_n_day,only:crop_soil_state_t
 use mod_b111_amendment_calendar,only:amendment_calendar_t,AMCAL_OK
 use mod_b111_soil_n_addition,only:b111_soil_n_split_parameters_t
 use mod_soil_n_day_environment,only:soil_n_day_environment_t
 use mod_wofost_one_day_structural_evolution,only:wofost_one_day_forcing_t
 implicit none
 private
 public::run_crop_soil_n_calendar_interval
contains
 subroutine run_crop_soil_n_calendar_interval(backend,column,template,parameters,water,forcing,config, &
     chemical,weather,t0,t1,calendar,split,result,environment)
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
  type(amendment_calendar_t),intent(in)::calendar
  type(b111_soil_n_split_parameters_t),intent(in)::split
  type(material_joint_result_t),intent(out)::result
  type(soil_n_day_environment_t),intent(in),optional::environment
  type(soil_n_material_input_t),allocatable::items(:)
  integer::code
  result=material_joint_result_t()
  call select_calendar_materials(calendar,t0,t1,items,code)
  if(code/=AMCAL_OK)return
  call run_crop_soil_n_material_interval(backend,column,template,parameters,water,forcing,config, &
    chemical,weather,t0,t1,items,split,result,environment)
 end subroutine
end module
