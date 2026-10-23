! Immutable calendar forcing over the existing saved crop-cycle output owners.
module mod_crop_soil_n_saved_calendar_output
 use iso_fortran_env,only:real64,int64
 use mod_soil_n_amendment_calendar,only:soil_n_amendment_calendar_t,N_CALENDAR_OK
 use mod_crop_soil_n_calendar_day,only:select_calendar_material_batch
 use mod_crop_soil_n_saved_cycle_output,only:run_crop_soil_n_saved_cycle_day
 use mod_crop_soil_n_saved_output,only:run_crop_soil_n_saved_fallow_day
 use mod_crop_soil_n_thermal_saved_output,only:run_crop_soil_n_thermal_saved_fallow_day
 use mod_fmr_crop_soil_n_thermal_application,only:soil_n_thermal_template
 use mod_crop_soil_n_output_day,only:OUTPUT_DAY_INVALID
 use mod_crop_ext_saved_residue,only:crop_ext_saved_residue_t
 use mod_soil_n_crop_extended_output,only:crop_ext_state_t,crop_ext_row_t
 use mod_fmr_crop_soil_n_senescence_application,only:senescence_joint_result_t
 use mod_fmr_crop_soil_n_material_application,only:material_joint_result_t
 use mod_canonical_contracts,only:canonical_numerical_config_t
 use mod_fmr_runtime_core,only:fmr_logical_column_t,fmr_template_t
 use mod_fmr_serialized_reference_backend,only:fmr_serialized_reference_backend_t, &
  fmr_b110_physical_parameters_t,fmr_b110_physical_forcing_t
 use mod_kernel_transactions,only:kernel_committed_state_t
 use mod_crop_soil_n_day,only:crop_soil_state_t
 use mod_crop_soil_n_material_day,only:soil_n_material_input_t
 use mod_crop_senescence_residue,only:crop_senescence_policy_t
 use mod_b111_soil_n_addition,only:b111_soil_n_split_parameters_t
 use mod_wofost_one_day_structural_evolution,only:wofost_one_day_forcing_t
 use mod_soil_n_day_environment,only:soil_n_day_environment_t
 implicit none
 private
 public::run_crop_soil_n_saved_calendar_day,run_crop_soil_n_saved_calendar_fallow_day
contains
 subroutine run_crop_soil_n_saved_calendar_day(path,date,report,water_id,backend,column,template,parameters,water, &
   forcing,config,chemical,weather,t0,t1,plan,split,policy,output,saved,dates,rows,result,status,environment,csv_path)
  character(*),intent(in)::path,date
  logical,intent(in)::report
  integer(int64),intent(in)::water_id
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
  type(soil_n_amendment_calendar_t),intent(in)::plan
  type(b111_soil_n_split_parameters_t),intent(in)::split
  type(crop_senescence_policy_t),intent(in)::policy
  type(crop_ext_state_t),intent(inout)::output
  type(crop_ext_saved_residue_t),intent(inout)::saved
  character(10),allocatable,intent(inout)::dates(:)
  type(crop_ext_row_t),allocatable,intent(inout)::rows(:)
  type(senescence_joint_result_t),intent(out)::result
  integer,intent(out)::status
  type(soil_n_day_environment_t),optional,intent(in)::environment
  character(*),optional,intent(in)::csv_path
  type(soil_n_material_input_t),allocatable::items(:)
  integer::code
  result=senescence_joint_result_t();status=OUTPUT_DAY_INVALID
  call select_calendar_material_batch(plan,t0,t1,items,code)
  if(code/=N_CALENDAR_OK)return
  call run_crop_soil_n_saved_cycle_day(path,date,report,water_id,backend,column,template,parameters,water, &
   forcing,config,chemical,weather,t0,t1,items,split,policy,output,saved,dates,rows,result,status,environment,csv_path)
 end subroutine
 subroutine run_crop_soil_n_saved_calendar_fallow_day(path,date,report,water_id,backend,column,template,parameters, &
   water,forcing,config,chemical,weather,t0,t1,plan,split,output,saved,dates,rows,result,status,environment,csv_path)
  character(*),intent(in)::path,date
  logical,intent(in)::report
  integer(int64),intent(in)::water_id
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
  type(soil_n_amendment_calendar_t),intent(in)::plan
  type(b111_soil_n_split_parameters_t),intent(in)::split
  type(crop_ext_state_t),intent(inout)::output
  type(crop_ext_saved_residue_t),intent(inout)::saved
  character(10),allocatable,intent(inout)::dates(:)
  type(crop_ext_row_t),allocatable,intent(inout)::rows(:)
  type(material_joint_result_t),intent(out)::result
  integer,intent(out)::status
  type(soil_n_day_environment_t),optional,intent(in)::environment
  character(*),optional,intent(in)::csv_path
  type(soil_n_material_input_t),allocatable::items(:)
  integer::code
  result=material_joint_result_t();status=OUTPUT_DAY_INVALID
  call select_calendar_material_batch(plan,t0,t1,items,code)
  if(code/=N_CALENDAR_OK)return
  if(soil_n_thermal_template(template))then
   call run_crop_soil_n_thermal_saved_fallow_day(path,date,report,water_id,backend,column,template,parameters, &
    water,forcing,config,chemical,weather,t0,t1,items,split,output,saved,dates,rows,result,status,environment,csv_path)
  else
   call run_crop_soil_n_saved_fallow_day(path,date,report,water_id,backend,column,template,parameters, &
    water,forcing,config,chemical,weather,t0,t1,items,split,output,saved,dates,rows,result,status,environment,csv_path)
  end if
 end subroutine
end module
