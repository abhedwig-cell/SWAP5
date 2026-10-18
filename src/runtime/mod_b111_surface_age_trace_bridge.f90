! Reference-only bridge: accepted hydraulic trace to surface-age trial.
! It never mutates the admitted water or legacy soil-age solver.
module mod_b111_surface_age_trace_bridge
 use, intrinsic :: iso_fortran_env, only: real64
 use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
 use mod_fmr_serialized_reference_backend, only: fmr_water_flux_substep_trace_t
 use mod_b111_surface_age_budget
 use mod_b111_surface_age_owner
 implicit none
 private
 integer,parameter,public::AGE_BRIDGE_OK=0,AGE_BRIDGE_REJECT=1
 type,public::surface_age_source_ages_t
  real(real64)::rain_age_day=0.0_real64
  real(real64)::irrigation_age_day=0.0_real64
  real(real64)::runon_age_day=0.0_real64
 end type
 public::trial_surface_age_from_accepted_trace
contains
 subroutine trial_surface_age_from_accepted_trace(committed,trace,ages,candidate,receipt,status)
  type(surface_age_owner_t),intent(in)::committed
  type(fmr_water_flux_substep_trace_t),intent(in)::trace
  type(surface_age_source_ages_t),intent(in)::ages
  type(surface_age_owner_t),intent(out)::candidate
  type(surface_age_receipt_t),intent(out)::receipt
  integer,intent(out)::status
  type(surface_age_request_t)::q
  integer::code
  real(real64)::dt
  candidate=committed;receipt=surface_age_receipt_t();status=AGE_BRIDGE_REJECT
  if(.not.trace%pond_storage_available.or..not.trace%converged_surface_available.or. &
     .not.trace%converged_gross_sources_available)return
  if(.not.all(ieee_is_finite([trace%t0,trace%t1,trace%top_flux,trace%pond_start_cm, &
      trace%pond_end_cm,trace%converged_rain_rate_cm_day, &
      trace%converged_irrigation_rate_cm_day,trace%converged_runon_rate_cm_day, &
      trace%converged_snowmelt_rate_cm_day,trace%converged_runoff_depth_cm, &
      trace%converged_pond_evaporation_cm_day,ages%rain_age_day, &
      ages%irrigation_age_day,ages%runon_age_day])))return
  if(trace%t1<=trace%t0.or.abs(trace%converged_snowmelt_rate_cm_day)>0.0_real64)return
  if(min(ages%rain_age_day,ages%irrigation_age_day,ages%runon_age_day)<0.0_real64)return
  ! Outward qtop is not an admissible infiltration age sink here.
  ! Exfiltration needs an explicit soil-to-surface age source receipt.
  if(trace%top_flux>0.0_real64)return
  dt=trace%t1-trace%t0
  q%dt_day=dt
  q%pond_start_cm=trace%pond_start_cm;q%pond_end_cm=trace%pond_end_cm
  q%rain_depth_cm=trace%converged_rain_rate_cm_day*dt
  q%irrigation_depth_cm=trace%converged_irrigation_rate_cm_day*dt
  q%runon_depth_cm=trace%converged_runon_rate_cm_day*dt
  q%rain_age_day=ages%rain_age_day
  q%irrigation_age_day=ages%irrigation_age_day
  q%runon_age_day=ages%runon_age_day
  q%infiltration_depth_cm=-trace%top_flux*dt
  q%runoff_depth_cm=trace%converged_runoff_depth_cm
  q%evaporation_depth_cm=trace%converged_pond_evaporation_cm_day*dt
  call advance_surface_age_owner(committed,q,candidate,receipt,code)
  if(code/=AGE_OWNER_OK.or.receipt%status/=SURFACE_AGE_OK)return
  status=AGE_BRIDGE_OK
 end subroutine
end module
