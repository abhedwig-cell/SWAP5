module mod_fmr_b111_reactive_n_route
 use mod_b111_soil_n_mineral_owner,only:mineral_state_t,MINERAL_OK
 use mod_b111_soil_n_reactive_owner
 use mod_fmr_b111_mineral_route,only:mineral_daily_carrier_t,aggregate_mineral_trace
 use mod_fmr_serialized_reference_backend,only:fmr_water_flux_substep_trace_t
 implicit none
 private
 public::consume_reactive_n_trace
contains
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
