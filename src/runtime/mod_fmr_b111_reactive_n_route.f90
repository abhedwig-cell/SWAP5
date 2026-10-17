module mod_fmr_b111_reactive_n_route
 use mod_b111_soil_n_mineral_owner,only:mineral_state_t,MINERAL_OK
 use mod_b111_soil_n_reactive_owner
 use mod_soil_n_historical_activation,only:soil_n_historical_selection_t,activate_soil_n_historical
 use mod_soil_n_pool_state,only:soil_n_pool_state_t
 use iso_fortran_env,only:real64,int64
 use mod_fmr_b111_mineral_route,only:mineral_daily_carrier_t,aggregate_mineral_trace
 use mod_fmr_serialized_reference_backend,only:fmr_water_flux_substep_trace_t
 implicit none
 private
 public::consume_reactive_n_trace,initialize_historical_reactive_n_route
contains
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
