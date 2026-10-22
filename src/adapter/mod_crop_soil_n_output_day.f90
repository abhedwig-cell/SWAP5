! Explicit bounded daily application: stage science + diagnostics, save, publish.
module mod_crop_soil_n_output_day
 use iso_fortran_env,only:real64,int64
 use mod_soil_n_crop_extended_output
 use mod_crop_n_output_generation
 use mod_crop_ext_csv_file
 use mod_crop_soil_n_output_observation
 use mod_fmr_crop_soil_n_senescence_application
 use mod_fmr_crop_soil_n_thermal_application,only:soil_n_thermal_template,run_crop_soil_n_thermal_interval
 use mod_fmr_crop_soil_n_joint_application,only:JOINT_OK,JOINT_COMMIT_REJECTED
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
 integer,parameter,public::OUTPUT_DAY_OK=0,OUTPUT_DAY_INVALID=1,OUTPUT_DAY_SAVE_FAILED=2,OUTPUT_DAY_VIEW_FAILED=3
 public::run_crop_soil_n_output_day
contains
 subroutine run_crop_soil_n_output_day(path,date,report,water_id,backend,column,template,parameters,water, &
     forcing,config,chemical,weather,t0,t1,items,split,policy,output,dates,rows,result,status,environment,csv_path)
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
  type(soil_n_material_input_t),intent(in)::items(:)
  type(b111_soil_n_split_parameters_t),intent(in)::split
  type(crop_senescence_policy_t),intent(in)::policy
  type(crop_ext_state_t),intent(inout)::output
  character(10),allocatable,intent(inout)::dates(:)
  type(crop_ext_row_t),allocatable,intent(inout)::rows(:)
  type(senescence_joint_result_t),intent(out)::result
  integer,intent(out)::status
  type(soil_n_day_environment_t),intent(in),optional::environment
  character(*),intent(in),optional::csv_path
  type(kernel_committed_state_t)::water_trial
  type(crop_soil_state_t)::chemical_trial
  type(crop_ext_state_t)::output_trial
  type(crop_ext_row_t)::row
  type(crop_ext_row_t),allocatable::rows_trial(:)
  character(10),allocatable::dates_trial(:)
  real(real64)::v(17)
  character(128)::line
  integer::code,n
  logical::ready,thermal
  result=senescence_joint_result_t();status=OUTPUT_DAY_INVALID
  thermal=soil_n_thermal_template(template)
  ! The thermal route owns its accepted profile; explicit day temperature is
  ! not a competing forcing authority for that route.
  if(thermal.and.present(environment))return
  if(.not.allocated(rows).or..not.allocated(dates))return
  if(.not.output_history_valid(dates,rows))return
  call output%snapshot(v(1),v(2:9),v(10:17),ready)
  if(.not.ready.or.v(1)/=t0)return
  if(report)then
   row%emitted=.true.
   call format_crop_ext_row(date,row,line,code);if(code/=0)return
   if(size(dates)>0)then
    if(date<=dates(size(dates)))return
   end if
  end if
  water_trial=water;chemical_trial=chemical;output_trial=output
  if(thermal)then
   call run_crop_soil_n_thermal_interval(backend,column,template,parameters,water_trial,forcing,config, &
     chemical_trial,weather,t0,t1,items,split,policy,result)
  else
   call run_crop_soil_n_senescence_interval(backend,column,template,parameters,water_trial,forcing,config, &
     chemical_trial,weather,t0,t1,items,split,policy,result,environment)
  end if
  if(result%status/=JOINT_OK)return
  call observe_accepted_crop_soil_n_day(output_trial,water,chemical,water_trial,chemical_trial,result,t0,t1, &
    report,row,code,thermal)
  if(code/=0)then;result%status=JOINT_COMMIT_REJECTED;return;end if
  n=size(rows);allocate(dates_trial(n+merge(1,0,report)),rows_trial(n+merge(1,0,report)))
  dates_trial(:n)=dates;rows_trial(:n)=rows
  if(report)then
   dates_trial(n+1)=date;rows_trial(n+1)=row
  end if
  call write_crop_n_output_generation(path,column,template,water_id,water_trial,chemical_trial, &
    output_trial,dates_trial,rows_trial,code)
  if(code/=0)then;result%status=JOINT_COMMIT_REJECTED;status=OUTPUT_DAY_SAVE_FAILED;return;end if
  ! The generation is authoritative before any caller memory is published.
  water=water_trial;chemical=chemical_trial;output=output_trial
  call move_alloc(dates_trial,dates);call move_alloc(rows_trial,rows)
  status=OUTPUT_DAY_OK
  if(present(csv_path))then
   call write_crop_ext_csv_file(csv_path,dates,rows,output,code)
   if(code/=0)status=OUTPUT_DAY_VIEW_FAILED
  end if
 end subroutine
end module
