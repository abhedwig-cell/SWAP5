! Explicit opt-in startup for the bounded output-day/generation application.
module mod_crop_soil_n_native_output_start
 use iso_fortran_env,only:real64,int64
 use mod_crop_soil_n_historical_project_binding,only:initialize_historical_crop_soil_owner
 use mod_soil_n_historical_activation,only:soil_n_historical_selection_t
 use mod_b111_soil_n_reactive_owner,only:reactive_parameters_t
 use mod_soil_n_amendment_calendar,only:soil_n_amendment_calendar_t
 use mod_crop_soil_n_configuration,only:crop_n_configuration_t
 use mod_crop_soil_n_day,only:crop_soil_state_t
 use mod_wofost81_crop_owner_state,only:wofost81_crop_owner_state_t
 use mod_crop_senescence_residue,only:crop_senescence_policy_t
 use mod_soil_n_crop_extended_output,only:crop_ext_state_t,crop_ext_row_t,initialize_crop_ext,CROP_EXT_OK
 implicit none
 private
 public::initialize_historical_crop_soil_output_owner
contains
 subroutine initialize_historical_crop_soil_output_owner(selection,soil_template,crop_template,crop_owner, &
   soil_id,crop_id,clock,water,path,origin,plan,coupled,senescence,output,dates,rows,status,error_line)
  type(soil_n_historical_selection_t),intent(in)::selection
  type(reactive_parameters_t),intent(in)::soil_template
  type(crop_n_configuration_t),intent(in)::crop_template
  type(wofost81_crop_owner_state_t),intent(in)::crop_owner
  integer(int64),intent(in)::soil_id,crop_id
  real(real64),intent(in)::clock,water
  character(*),intent(in)::path,origin
  type(soil_n_amendment_calendar_t),intent(inout)::plan
  type(crop_soil_state_t),intent(inout)::coupled
  type(crop_senescence_policy_t),intent(inout)::senescence
  type(crop_ext_state_t),intent(inout)::output
  character(10),allocatable,intent(inout)::dates(:)
  type(crop_ext_row_t),allocatable,intent(inout)::rows(:)
  integer,intent(out)::status,error_line
  type(soil_n_amendment_calendar_t)::candidate_plan
  type(crop_soil_state_t)::candidate_coupled
  type(crop_senescence_policy_t)::candidate_policy
  type(crop_ext_state_t)::candidate_output
  character(10),allocatable::candidate_dates(:)
  type(crop_ext_row_t),allocatable::candidate_rows(:)
  integer::code
  logical::requested
  status=1;error_line=0
  ! This adapter only owns a new run, never destructive reinitialization.
  if(coupled%ready().or.allocated(dates).or.allocated(rows))return
  if(crop_owner%harvested().or.crop_owner%harvest_retired())return
  call initialize_crop_ext(clock,candidate_output,code)
  if(code/=CROP_EXT_OK)return
  call initialize_historical_crop_soil_owner(selection,soil_template,crop_template,crop_owner, &
    soil_id,crop_id,clock,water,path,origin,candidate_plan,candidate_coupled,candidate_policy, &
    code,error_line,extended_output=requested)
  if(code/=0.or..not.requested)return
  allocate(candidate_dates(0),candidate_rows(0))
  plan=candidate_plan;coupled=candidate_coupled;senescence=candidate_policy;output=candidate_output
  call move_alloc(candidate_dates,dates);call move_alloc(candidate_rows,rows)
  status=0;error_line=0
 end subroutine
end module
