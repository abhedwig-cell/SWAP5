! Bounded direct historical atmospheric N carrier from an accepted Reference trace.
! No new water forcing; only a separate chemical source rate (m/day).
module mod_b111_n_gross_direct_binding
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_fmr_serialized_reference_backend,only:fmr_water_flux_substep_trace_t
 implicit none
 private
 integer,parameter,public::N_DIRECT_OK=0,N_DIRECT_REJECT=1
 public::direct_gross_n_rate_from_reference
contains
 subroutine direct_gross_n_rate_from_reference(trace,gross_m_day,status)
  type(fmr_water_flux_substep_trace_t),intent(in)::trace
  real(real64),intent(out)::gross_m_day
  integer,intent(out)::status
  gross_m_day=0d0;status=N_DIRECT_REJECT
  if(.not.trace%converged_surface_available.or..not.trace%converged_gross_sources_available.or. &
    .not.trace%pond_storage_available)return
  if(.not.all(ieee_is_finite([trace%t0,trace%t1,trace%pond_start_cm,trace%pond_end_cm, &
    trace%top_flux,trace%converged_rain_rate_cm_day,trace%converged_irrigation_rate_cm_day, &
    trace%converged_runon_rate_cm_day,trace%converged_snowmelt_rate_cm_day, &
    trace%converged_runoff_depth_cm,trace%converged_pond_evaporation_cm_day])))return
  if(abs(trace%t1-trace%t0-1d0)>64d0*epsilon(1d0))return
  ! Direct legacy top-input contract has one c_top. Do not silently
  ! blend source-specific rain/irrigation/runon concentrations.
  if(abs(trace%pond_start_cm)>0d0.or.abs(trace%pond_end_cm)>0d0.or. &
    abs(trace%converged_irrigation_rate_cm_day)>0d0.or. &
    abs(trace%converged_runon_rate_cm_day)>0d0.or. &
    abs(trace%converged_snowmelt_rate_cm_day)>0d0.or. &
    abs(trace%converged_runoff_depth_cm)>0d0.or.trace%top_flux>0d0)return
  if(trace%converged_rain_rate_cm_day<0d0.or.trace%converged_pond_evaporation_cm_day<0d0)return
  gross_m_day=0.01d0*trace%converged_rain_rate_cm_day
  status=N_DIRECT_OK
 end subroutine
end module
