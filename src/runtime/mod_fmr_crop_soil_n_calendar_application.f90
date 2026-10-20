module mod_fmr_crop_soil_n_calendar_application
 use iso_fortran_env,only:real64
 use mod_canonical_contracts,only:canonical_numerical_config_t
 use mod_fmr_runtime_core,only:fmr_logical_column_t,fmr_template_t
 use mod_kernel_transactions,only:kernel_committed_state_t
 use mod_fmr_serialized_reference_backend,only:fmr_serialized_reference_backend_t, &
  fmr_b110_physical_parameters_t,fmr_b110_physical_forcing_t
 use mod_fmr_crop_soil_n_material_application,only:run_crop_soil_n_material_interval
 use mod_fmr_crop_soil_n_senescence_application
 use mod_crop_soil_n_calendar_day,only:select_calendar_material_batch
 use mod_soil_n_amendment_calendar
 use mod_crop_soil_n_material_day,only:soil_n_material_input_t
 use mod_crop_soil_n_day,only:crop_soil_state_t
 use mod_crop_senescence_residue,only:crop_senescence_policy_t
 use mod_b111_soil_n_addition,only:b111_soil_n_split_parameters_t
 use mod_wofost_one_day_structural_evolution,only:wofost_one_day_forcing_t
 use mod_soil_n_day_environment,only:soil_n_day_environment_t
 implicit none
 private
 public::run_crop_soil_n_calendar_interval
contains
 subroutine run_crop_soil_n_calendar_interval(backend,column,template,parameters,water,forcing,config, &
   chemical,weather,t0,t1,plan,split,policy,result,environment,fallow,clean_surface_water,atmospheric_n_surface,historical_top_water)
  type(fmr_serialized_reference_backend_t),intent(inout)::backend
  type(fmr_logical_column_t),intent(in)::column
  type(fmr_template_t),intent(in)::template
  type(fmr_b110_physical_parameters_t),intent(in),target::parameters
  type(kernel_committed_state_t),intent(inout)::water
  type(fmr_b110_physical_forcing_t),intent(in)::forcing
  type(canonical_numerical_config_t),intent(in)::config
  type(crop_soil_state_t),intent(inout)::chemical
  type(wofost_one_day_forcing_t),intent(in)::weather
  real(real64),intent(in)::t0,t1
  type(soil_n_amendment_calendar_t),intent(in)::plan
  type(b111_soil_n_split_parameters_t),intent(in)::split
  type(crop_senescence_policy_t),intent(in)::policy
  type(senescence_joint_result_t),intent(out)::result
  type(soil_n_day_environment_t),intent(in),optional::environment
  logical,intent(in),optional::fallow,clean_surface_water,atmospheric_n_surface
  real(real64),intent(in),optional::historical_top_water
  logical::inactive
  type(soil_n_material_input_t),allocatable::items(:)
  integer::code
  result=senescence_joint_result_t()
  call select_calendar_material_batch(plan,t0,t1,items,code)
  if(code/=N_CALENDAR_OK)return
  inactive=.false.;if(present(fallow))inactive=fallow
  if(inactive)then
   call run_crop_soil_n_material_interval(backend,column,template,parameters,water,forcing,config, &
    chemical,weather,t0,t1,items,split,result%joint,environment,fallow=.true.,clean_surface_water=clean_surface_water,atmospheric_n_surface=atmospheric_n_surface,historical_top_water=historical_top_water)
   result%status=result%joint%status
   return
  end if
  call run_crop_soil_n_senescence_interval(backend,column,template,parameters,water,forcing,config, &
   chemical,weather,t0,t1,items,split,policy,result,environment,clean_surface_water,atmospheric_n_surface,historical_top_water)
 end subroutine
end module
