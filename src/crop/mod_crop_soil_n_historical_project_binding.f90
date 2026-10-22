! One project-start transaction for source-bound Soil-N and existing crop policies.
! No second crop/soil owner; caller initializes existing coupled owner using outputs.
module mod_crop_soil_n_historical_project_binding
 use iso_fortran_env,only:real64,int64
 use mod_fmr_b111_reactive_n_route,only:initialize_historical_reactive_n_unified_export
 use mod_soil_n_historical_activation,only:soil_n_historical_selection_t
 use mod_b111_soil_n_reactive_owner,only:reactive_parameters_t,reactive_state_t
 use mod_soil_n_amendment_calendar,only:soil_n_amendment_calendar_t
 use mod_crop_soil_n_configuration,only:crop_n_configuration_t
 use mod_crop_soil_n_day,only:crop_soil_state_t,initialize_crop_soil
 use mod_wofost81_crop_owner_state,only:wofost81_crop_owner_state_t
 use mod_crop_senescence_residue,only:crop_senescence_policy_t
 use mod_crop_soil_n_residue_age_binding,only:bind_historical_residue_ages,RESIDUE_AGE_BIND_OK
 use mod_soil_n_historical_named_input,only:soil_n_residue_age_t
 implicit none
 private
 public::initialize_historical_crop_soil_project,initialize_historical_crop_soil_owner
contains
 subroutine initialize_historical_crop_soil_owner(selection,soil_template,crop_template,crop_owner, &
   soil_id,crop_id,clock,water,path,origin,plan,coupled,senescence,status,error_line,extended_output)
 type(soil_n_historical_selection_t),intent(in)::selection
 type(reactive_parameters_t),intent(in)::soil_template
 type(crop_n_configuration_t),intent(in)::crop_template
 type(wofost81_crop_owner_state_t),intent(in)::crop_owner
 integer(int64),intent(in)::soil_id,crop_id
 real(real64),intent(in)::clock,water
 character(*),intent(in)::path,origin
 type(soil_n_amendment_calendar_t),intent(out)::plan
 type(crop_soil_state_t),intent(out)::coupled
 type(crop_senescence_policy_t),intent(out)::senescence
 integer,intent(out)::status,error_line
 type(soil_n_amendment_calendar_t)::candidate_plan
 type(crop_soil_state_t)::candidate_coupled
 type(reactive_state_t)::soil
 type(reactive_parameters_t)::parameters
 type(crop_n_configuration_t)::configuration
 type(crop_senescence_policy_t)::candidate_senescence
 integer::code
 logical,intent(out),optional::extended_output
 logical::candidate_output
 plan=soil_n_amendment_calendar_t();coupled=crop_soil_state_t()
 senescence=crop_senescence_policy_t();status=1;error_line=0
 if(present(extended_output))extended_output=.false.
 candidate_output=.false.
 if(present(extended_output))then
 call initialize_historical_crop_soil_project(selection,soil_template,crop_template,soil_id,clock,water, &
   path,origin,candidate_plan,soil,parameters,configuration,candidate_senescence,code,error_line,extended_output=candidate_output)
 else
 call initialize_historical_crop_soil_project(selection,soil_template,crop_template,soil_id,clock,water, &
   path,origin,candidate_plan,soil,parameters,configuration,candidate_senescence,code,error_line)
 end if
 if(code/=0)return
 call initialize_crop_soil(soil,crop_owner,configuration,crop_id,candidate_coupled,code)
 if(code/=0.or..not.candidate_coupled%ready())return
 if(present(extended_output))extended_output=candidate_output
 plan=candidate_plan;coupled=candidate_coupled;senescence=candidate_senescence
 status=0;error_line=0
 end subroutine
 subroutine initialize_historical_crop_soil_project(selection,soil_template,crop_template, &
   id,clock,water,path,origin,plan,soil,soil_parameters,crop,senescence,status,error_line,extended_output)
 type(soil_n_historical_selection_t),intent(in)::selection
 type(reactive_parameters_t),intent(in)::soil_template
 type(crop_n_configuration_t),intent(in)::crop_template
 integer(int64),intent(in)::id
 real(real64),intent(in)::clock,water
 character(*),intent(in)::path,origin
 type(soil_n_amendment_calendar_t),intent(out)::plan
 type(reactive_state_t),intent(out)::soil
 type(reactive_parameters_t),intent(out)::soil_parameters
 type(crop_n_configuration_t),intent(out)::crop
 type(crop_senescence_policy_t),intent(out)::senescence
 integer,intent(out)::status,error_line
 type(soil_n_amendment_calendar_t)::candidate_plan
 type(reactive_state_t)::candidate_soil
 type(reactive_parameters_t)::candidate_parameters
 type(crop_n_configuration_t)::candidate_crop
 type(crop_senescence_policy_t)::candidate_policy
 type(soil_n_residue_age_t)::ages
 real(real64)::tcsf,lai
 integer::code
 logical,intent(out),optional::extended_output
 logical::candidate_output
 plan=soil_n_amendment_calendar_t();soil=reactive_state_t()
 soil_parameters=reactive_parameters_t();crop=crop_template
 senescence=crop_senescence_policy_t();status=1;error_line=0
 if(present(extended_output))extended_output=.false.
 candidate_output=.false.
 if(present(extended_output))then
 call initialize_historical_reactive_n_unified_export(selection,soil_template,id,clock,water, &
   path,origin,candidate_plan,candidate_soil,candidate_parameters,tcsf,lai,code,error_line,ages,extended_output=candidate_output)
 else
 call initialize_historical_reactive_n_unified_export(selection,soil_template,id,clock,water, &
   path,origin,candidate_plan,candidate_soil,candidate_parameters,tcsf,lai,code,error_line,ages)
 end if
 if(code/=0)return
 call bind_historical_residue_ages(ages,crop_template,candidate_policy,candidate_crop,code)
 if(code/=RESIDUE_AGE_BIND_OK)return
 candidate_crop%tcsf_n=tcsf
 candidate_crop%lai_crit_nupt=lai
 if(present(extended_output))extended_output=candidate_output
 plan=candidate_plan;soil=candidate_soil;soil_parameters=candidate_parameters
 crop=candidate_crop;senescence=candidate_policy;status=0;error_line=0
 end subroutine
end module
