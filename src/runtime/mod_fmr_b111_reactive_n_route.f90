module mod_fmr_b111_reactive_n_route
 use mod_b111_soil_n_mineral_owner,only:mineral_state_t,MINERAL_OK
 use mod_b111_soil_n_reactive_owner
 use mod_soil_n_historical_activation,only:soil_n_historical_selection_t,soil_n_historical_rates_t, &
   soil_n_historical_initial_t,activate_soil_n_historical,initialize_historical_soil_n_complete, &
   bind_historical_organic_source_profile
 use mod_soil_n_pool_state,only:soil_n_pool_state_t
 use mod_soil_n_amendment_calendar,only:soil_n_amendment_calendar_t
 use mod_soil_n_amendment_input,only:read_soil_n_amendment_tables,N_INPUT_OK
 use mod_soil_n_historical_named_input,only:read_historical_soil_n_named_export,N_NAMED_OK,soil_n_residue_age_t
 use mod_soil_n_unified_input,only:read_soil_n_unified_export,N_UNIFIED_OK
 use iso_fortran_env,only:real64,int64
 use mod_fmr_b111_mineral_route,only:mineral_daily_carrier_t,aggregate_mineral_trace
 use mod_fmr_serialized_reference_backend,only:fmr_water_flux_substep_trace_t
 implicit none
 private
 public::consume_reactive_n_trace,initialize_historical_reactive_n_route,initialize_historical_reactive_n_from_tables,initialize_historical_reactive_n_complete_tables,initialize_historical_reactive_n_named_files,initialize_historical_reactive_n_unified_export
contains
 subroutine initialize_historical_reactive_n_unified_export(selection,template,id,clock,water, &
    path,origin,plan,state,parameters,tcsf,lai,status,error_line,ages,extended_output)
   type(soil_n_historical_selection_t),intent(in)::selection
   type(reactive_parameters_t),intent(in)::template
   integer(int64),intent(in)::id
   real(real64),intent(in)::clock,water
   character(*),intent(in)::path,origin
   type(soil_n_amendment_calendar_t),intent(out)::plan
   type(reactive_state_t),intent(out)::state
   type(reactive_parameters_t),intent(out)::parameters
   real(real64),intent(out)::tcsf,lai
   integer,intent(out)::status,error_line
   type(soil_n_residue_age_t),intent(out),optional::ages
   type(soil_n_residue_age_t)::candidate_ages
   type(soil_n_amendment_calendar_t)::candidate_plan
   type(soil_n_historical_initial_t)::initial
   type(soil_n_historical_rates_t)::rates
   type(reactive_parameters_t)::organic,derived
   type(reactive_state_t)::candidate
   real(real64)::candidate_tcsf,candidate_lai
   integer::code
 logical,intent(out),optional::extended_output
 logical::candidate_output
   plan=soil_n_amendment_calendar_t();state=reactive_state_t()
   parameters=reactive_parameters_t();tcsf=0d0;lai=0d0;status=1;error_line=0
   if(present(ages))ages=soil_n_residue_age_t()
 if(present(extended_output))extended_output=.false.
   if(selection%swcropsnm/=1.or.selection%sw_wofost/=1.or..not.selection%source_parameters_complete)return
 candidate_output=.false.
 if(present(extended_output))then
   call read_soil_n_unified_export(path,origin,candidate_plan,initial,rates,code,error_line,candidate_ages,extended_output=candidate_output)
 else
   call read_soil_n_unified_export(path,origin,candidate_plan,initial,rates,code,error_line,candidate_ages)
 end if
   if(code/=N_UNIFIED_OK)return
   call bind_historical_organic_source_profile(template,organic,code)
   if(code/=0)return
   call initialize_historical_soil_n_complete(selection,rates,initial,organic,id,clock,water, &
       candidate,derived,candidate_tcsf,candidate_lai,code)
   if(code/=0)return
 if(present(extended_output))extended_output=candidate_output
   plan=candidate_plan;state=candidate;parameters=derived
   tcsf=candidate_tcsf;lai=candidate_lai;status=0
   if(present(ages))ages=candidate_ages
 end subroutine
 subroutine initialize_historical_reactive_n_named_files(selection,template,id,clock,water, &
      parameter_path,management_path,origin,plan,state,parameters,tcsf,lai,status,error_line)
   type(soil_n_historical_selection_t),intent(in)::selection
   type(reactive_parameters_t),intent(in)::template
   integer(int64),intent(in)::id
   real(real64),intent(in)::clock,water
   character(*),intent(in)::parameter_path,management_path,origin
   type(soil_n_amendment_calendar_t),intent(out)::plan
   type(reactive_state_t),intent(out)::state
   type(reactive_parameters_t),intent(out)::parameters
   real(real64),intent(out)::tcsf,lai
   integer,intent(out)::status,error_line
   type(soil_n_historical_rates_t)::rates
   type(soil_n_historical_initial_t)::initial
   type(reactive_parameters_t)::historical_organic
   integer::code
   plan=soil_n_amendment_calendar_t();state=reactive_state_t()
   parameters=reactive_parameters_t();tcsf=0d0;lai=0d0;status=1;error_line=0
   if(selection%swcropsnm/=1.or.selection%sw_wofost/=1.or..not.selection%source_parameters_complete)return
   call read_historical_soil_n_named_export(parameter_path,initial,rates,code,error_line)
   if(code/=N_NAMED_OK)return
   call bind_historical_organic_source_profile(template,historical_organic,code)
   if(code/=0)return
   call initialize_historical_reactive_n_complete_tables(selection,rates,initial,historical_organic,id,clock,water, &
      management_path,origin,plan,state,parameters,tcsf,lai,status,error_line)
 end subroutine
 subroutine initialize_historical_reactive_n_complete_tables(selection,rates,initial,template,id,clock,water, &
      path,origin,plan,state,parameters,tcsf,lai,status,error_line)
   type(soil_n_historical_selection_t),intent(in)::selection
   type(soil_n_historical_rates_t),intent(in)::rates
   type(soil_n_historical_initial_t),intent(in)::initial
   type(reactive_parameters_t),intent(in)::template
   integer(int64),intent(in)::id
   real(real64),intent(in)::clock,water
   character(*),intent(in)::path,origin
   type(soil_n_amendment_calendar_t),intent(out)::plan
   type(reactive_state_t),intent(out)::state
   type(reactive_parameters_t),intent(out)::parameters
   real(real64),intent(out)::tcsf,lai
   integer,intent(out)::status,error_line
   type(soil_n_amendment_calendar_t)::parsed
   type(reactive_state_t)::candidate
   type(reactive_parameters_t)::candidate_parameters
   real(real64)::candidate_tcsf,candidate_lai
   integer::code
   plan=soil_n_amendment_calendar_t();state=reactive_state_t();parameters=reactive_parameters_t()
   tcsf=0d0;lai=0d0;status=1;error_line=0
   if(selection%swcropsnm/=1.or.selection%sw_wofost/=1.or..not.selection%source_parameters_complete)return
   call read_soil_n_amendment_tables(path,origin,parsed,code,error_line)
   if(code/=N_INPUT_OK)return
   call initialize_historical_soil_n_complete(selection,rates,initial,template,id,clock,water, &
      candidate,candidate_parameters,candidate_tcsf,candidate_lai,code)
   if(code/=0)return
   plan=parsed;state=candidate;parameters=candidate_parameters
   tcsf=candidate_tcsf;lai=candidate_lai;status=0
 end subroutine
 subroutine initialize_historical_reactive_n_from_tables(selection,p,pools,id,clock,water,path,origin,plan,state,status,error_line)
   type(soil_n_historical_selection_t),intent(in)::selection
   type(reactive_parameters_t),intent(in)::p
   type(soil_n_pool_state_t),intent(in)::pools
   integer(int64),intent(in)::id
   real(real64),intent(in)::clock,water
   character(*),intent(in)::path,origin
   type(soil_n_amendment_calendar_t),intent(out)::plan
   type(reactive_state_t),intent(out)::state
   integer,intent(out)::status,error_line
   type(soil_n_amendment_calendar_t)::parsed
   type(reactive_state_t)::candidate
   integer::reader_status
   state=reactive_state_t();plan=soil_n_amendment_calendar_t();error_line=0
   status=1
   if(selection%swcropsnm/=1.or.selection%sw_wofost/=1)return
   if(.not.selection%source_parameters_complete)return
   call read_soil_n_amendment_tables(path,origin,parsed,reader_status,error_line)
   if(reader_status/=N_INPUT_OK)return
   call activate_soil_n_historical(selection,p,pools,id,clock,water,candidate,status)
   if(status/=0)return
   plan=parsed;state=candidate
 end subroutine
 subroutine initialize_historical_reactive_n_route(selection,p,pools,id,clock,water,state,status)
   type(soil_n_historical_selection_t),intent(in)::selection
   type(reactive_parameters_t),intent(in)::p
   type(soil_n_pool_state_t),intent(in)::pools
   integer(int64),intent(in)::id
   real(real64),intent(in)::clock,water
   type(reactive_state_t),intent(out)::state
   integer,intent(out)::status
   call activate_soil_n_historical(selection,p,pools,id,clock,water,state,status)
 end subroutine
 subroutine consume_reactive_n_trace(state,steps,receipt)
   type(reactive_state_t),intent(inout)::state
   type(fmr_water_flux_substep_trace_t),intent(in)::steps(:)
   type(reactive_receipt_t),intent(out)::receipt
   type(mineral_state_t)::base
   type(mineral_daily_carrier_t)::c
   integer::code
   receipt=reactive_receipt_t()
   if(.not.state%ready())return
   call state%mineral_snapshot(base)
   call aggregate_mineral_trace(base,steps,c,code)
   if(code/=MINERAL_OK)return
   call advance_reactive_day(state,c%t0,c%t1,c%water_end,c%outflow,c%in_bottom,c%in_lateral,c%root_water,receipt)
 end subroutine
end module
