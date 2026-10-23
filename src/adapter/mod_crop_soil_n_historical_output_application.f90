! Application dispatch owns no physical state, event cursor or restart schema.
module mod_crop_soil_n_historical_output_application
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_crop_soil_n_native_output_start,only:initialize_historical_crop_soil_output_owner
 use mod_crop_soil_n_saved_calendar_output
 use mod_crop_soil_n_saved_cycle_output,only:run_crop_soil_n_saved_cycle_harvest
 use mod_crop_n_saved_generation,only:write_crop_n_saved_generation
 use mod_crop_ext_saved_residue,only:crop_ext_saved_residue_t,restore_crop_ext_saved_residue
 use mod_soil_n_crop_extended_output,only:crop_ext_state_t,crop_ext_row_t
 use mod_soil_n_historical_activation,only:soil_n_historical_selection_t
 use mod_b111_soil_n_reactive_owner,only:reactive_parameters_t,reactive_state_t
 use mod_crop_soil_n_configuration,only:crop_n_configuration_t
 use mod_crop_soil_n_day,only:crop_soil_state_t,crop_soil_harvest_receipt_t,crop_soil_harvest_observation_t
 use mod_wofost81_crop_owner_state,only:wofost81_crop_owner_state_t,wofost81_harvest_record_t, &
  prepare_wofost81_harvest,WOFOST81_HARVEST_NOT_DUE
 use mod_soil_n_amendment_calendar,only:soil_n_amendment_calendar_t
 use mod_crop_senescence_residue,only:crop_senescence_policy_t
 use mod_crop_soil_n_output_day,only:OUTPUT_DAY_INVALID,OUTPUT_DAY_SAVE_FAILED,OUTPUT_DAY_OK
 use mod_fmr_crop_soil_n_senescence_application,only:senescence_joint_result_t
 use mod_fmr_crop_soil_n_material_application,only:material_joint_result_t
 use mod_canonical_contracts,only:canonical_numerical_config_t
 use mod_fmr_runtime_core,only:fmr_logical_column_t,fmr_template_t
 use mod_fmr_serialized_reference_backend,only:fmr_serialized_reference_backend_t, &
  fmr_b110_physical_parameters_t,fmr_b110_physical_forcing_t
 use mod_kernel_transactions,only:kernel_committed_state_t
 use mod_b111_soil_n_addition,only:b111_soil_n_split_parameters_t
 use mod_wofost_one_day_structural_evolution,only:wofost_one_day_forcing_t
 use mod_soil_n_day_environment,only:soil_n_day_environment_t
 implicit none
 private
 integer,parameter,public::HIST_ACTIVE=1,HIST_HARVEST=2,HIST_INCORPORATE=3,HIST_RETIRE=4,HIST_FALLOW=5
 type,public::historical_output_result_t
  integer::action=0
  type(senescence_joint_result_t)::active
  type(material_joint_result_t)::fallow
  type(crop_soil_harvest_receipt_t)::boundary
 end type
 public::initialize_historical_saved_output,advance_historical_saved_output,historical_output_next_action
contains
 subroutine initialize_historical_saved_output(selection,soil_template,crop_template,crop_owner,soil_id,crop_id, &
   clock,water_fraction,input_path,origin,generation_path,column,template,water_id,water,plan,coupled, &
   senescence,output,saved,dates,rows,status,error_line)
  type(soil_n_historical_selection_t),intent(in)::selection
  type(reactive_parameters_t),intent(in)::soil_template
  type(crop_n_configuration_t),intent(in)::crop_template
  type(wofost81_crop_owner_state_t),intent(in)::crop_owner
  integer(int64),intent(in)::soil_id,crop_id,water_id
  real(real64),intent(in)::clock,water_fraction
  character(*),intent(in)::input_path,origin,generation_path
  type(fmr_logical_column_t),intent(in)::column
  type(fmr_template_t),intent(in)::template
  type(kernel_committed_state_t),intent(in)::water
  type(soil_n_amendment_calendar_t),intent(inout)::plan
  type(crop_soil_state_t),intent(inout)::coupled
  type(crop_senescence_policy_t),intent(inout)::senescence
  type(crop_ext_state_t),intent(inout)::output
  type(crop_ext_saved_residue_t),intent(inout)::saved
  character(10),allocatable,intent(inout)::dates(:)
  type(crop_ext_row_t),allocatable,intent(inout)::rows(:)
  integer,intent(out)::status,error_line
  type(soil_n_amendment_calendar_t)::p
  type(crop_soil_state_t)::c
  type(crop_senescence_policy_t)::policy
  type(crop_ext_state_t)::o
  type(crop_ext_saved_residue_t)::s
  character(10),allocatable::d(:)
  type(crop_ext_row_t),allocatable::r(:)
  real(real64)::time,v(9)
  logical::ready
  integer::code
  status=OUTPUT_DAY_INVALID;error_line=0
  if(coupled%ready().or.allocated(dates).or.allocated(rows))return
  call saved%snapshot(v,ready);if(ready)return
  call water%current_time(time,ready);if(.not.ready)return
  if(.not.ieee_is_finite(clock).or.time/=clock)return
  call initialize_historical_crop_soil_output_owner(selection,soil_template,crop_template,crop_owner, &
    soil_id,crop_id,clock,water_fraction,input_path,origin,p,c,policy,o,d,r,code,error_line)
  if(code/=0)return
  call restore_crop_ext_saved_residue([clock,0d0,0d0,0d0,0d0,0d0,0d0,0d0,0d0],s,code)
  if(code/=0)return
  call write_crop_n_saved_generation(generation_path,column,template,water_id,water,c,o,s,d,r,code)
  if(code/=0)then;status=OUTPUT_DAY_SAVE_FAILED;return;end if
  plan=p;coupled=c;senescence=policy;output=o;saved=s
  call move_alloc(d,dates);call move_alloc(r,rows)
  status=OUTPUT_DAY_OK
 end subroutine

 integer function historical_output_next_action(chemical,clock)result(action)
  type(crop_soil_state_t),intent(in)::chemical
  real(real64),intent(in)::clock
  type(reactive_state_t)::soil
  type(wofost81_crop_owner_state_t)::crop,trial
  type(wofost81_harvest_record_t)::harvest
  type(crop_n_configuration_t)::p
  integer(int64)::identity
  integer::code
  logical::has
  action=0
  if(.not.ieee_is_finite(clock).or..not.chemical%ready())return
  call chemical%snapshot(soil,crop)
  if(crop%harvest_retired())then;action=HIST_FALLOW;return;end if
  if(crop%harvested())then
   call crop%harvest_snapshot(harvest,has);if(.not.has)return
   action=HIST_INCORPORATE;if(harvest%pending_incorporated)action=HIST_RETIRE
   return
  end if
  call chemical%configuration(p,identity)
  if(allocated(p%harvest))then
   ! Ask the scientific owner, including its original maturity/clock predicate.
   call prepare_wofost81_harvest(crop,clock,int(p%harvest%crop_identity,int64),p%harvest%crop_end, &
    p%harvest%sw_harv,p%harvest%sw_wofost,p%update%development_stage_end,p%harvest%policy,trial,code)
   if(code==0)then;action=HIST_HARVEST;return;end if
   if(code/=WOFOST81_HARVEST_NOT_DUE)return
   if(clock>p%harvest%crop_end+1d0)return
  end if
  action=HIST_ACTIVE
 end function

 subroutine advance_historical_saved_output(path,date,report,water_id,backend,column,template,parameters,water, &
   forcing,config,chemical,weather,t0,t1,plan,split,policy,output,saved,dates,rows,result,status, &
   environment,csv_path,observation)
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
  type(historical_output_result_t),intent(out)::result
  integer,intent(out)::status
  type(soil_n_day_environment_t),optional,intent(in)::environment
  character(*),optional,intent(in)::csv_path
  type(crop_soil_harvest_observation_t),optional,intent(in)::observation
  real(real64)::clock
  logical::ready
  result=historical_output_result_t();status=OUTPUT_DAY_INVALID
  if(.not.all(ieee_is_finite([t0,t1])))return
  call water%current_time(clock,ready);if(.not.ready)return
  if(clock/=t0)return
  result%action=historical_output_next_action(chemical,clock)
  select case(result%action)
  case(HIST_ACTIVE)
   call run_crop_soil_n_saved_calendar_day(path,date,report,water_id,backend,column,template,parameters,water, &
    forcing,config,chemical,weather,t0,t1,plan,split,policy,output,saved,dates,rows,result%active,status,environment,csv_path)
  case(HIST_FALLOW)
   call run_crop_soil_n_saved_calendar_fallow_day(path,date,report,water_id,backend,column,template,parameters,water, &
    forcing,config,chemical,weather,t0,t1,plan,split,output,saved,dates,rows,result%fallow,status,environment,csv_path)
  case(HIST_HARVEST:HIST_RETIRE)
   if(t1/=t0.or.report)return
   if(result%action==HIST_RETIRE.and..not.present(observation))return
   call run_crop_soil_n_saved_cycle_harvest(path,result%action-1,column,template,water_id,water,chemical, &
    output,saved,dates,rows,result%boundary,status,observation)
  end select
 end subroutine
end module
