module mod_b111_surface_n_reference_bridge
 use iso_fortran_env, only: real64
 use ieee_arithmetic, only: ieee_is_finite
 use mod_fmr_serialized_reference_backend, only: fmr_water_flux_substep_trace_t
 use mod_b111_surface_n_gross_budget
 implicit none
 private
 integer,parameter,public::NBRIDGE_OK=0,NBRIDGE_REJECT=1
 public::surface_n_from_reference
contains
 subroutine surface_n_from_reference(t,rain_c,irrigation_c,runon_c,pond_n,dry_n,r,status)
  type(fmr_water_flux_substep_trace_t),intent(in)::t
  real(real64),intent(in)::rain_c(2),irrigation_c(2),runon_c(2),pond_n(2),dry_n(2)
  type(surface_n_gross_receipt_t),intent(out)::r
  integer,intent(out)::status
  type(surface_n_gross_request_t)::f
  real(real64)::dt
  status=NBRIDGE_REJECT
  r=surface_n_gross_receipt_t()
  if(.not.t%pond_storage_available.or..not.t%converged_surface_available.or. &
     .not.t%converged_gross_sources_available)return
  if(.not.all(ieee_is_finite([t%t0,t%t1,t%top_flux,t%pond_start_cm,t%pond_end_cm, &
     t%converged_rain_rate_cm_day,t%converged_irrigation_rate_cm_day, &
     t%converged_runon_rate_cm_day,t%converged_snowmelt_rate_cm_day, &
     t%converged_runoff_depth_cm,t%converged_pond_evaporation_cm_day, &
     rain_c,irrigation_c,runon_c,pond_n,dry_n])))return
  if(t%t1<=t%t0.or.t%top_flux>0.0_real64.or. &
     abs(t%converged_snowmelt_rate_cm_day)>0.0_real64)return
  if(any([rain_c,irrigation_c,runon_c]<0.0_real64))return
  dt=t%t1-t%t0
  f%pond_start_cm=t%pond_start_cm
  f%pond_end_cm=t%pond_end_cm
  f%gross_rain_cm=t%converged_rain_rate_cm_day*dt
  f%gross_irrigation_cm=t%converged_irrigation_rate_cm_day*dt
  f%gross_runon_cm=t%converged_runon_rate_cm_day*dt
  f%infiltration_cm=-t%top_flux*dt
  f%runoff_cm=t%converged_runoff_depth_cm
  f%evaporation_cm=t%converged_pond_evaporation_cm_day*dt
  f%rain_n_kg_m2=0.01_real64*f%gross_rain_cm*rain_c
  f%irrigation_n_kg_m2=0.01_real64*f%gross_irrigation_cm*irrigation_c
  f%runon_n_kg_m2=0.01_real64*f%gross_runon_cm*runon_c
  f%pond_n_initial_kg_m2=pond_n
  f%dry_n_initial_kg_m2=dry_n
  call evaluate_surface_n_gross_budget(f,r)
  if(r%status==SURFACE_N_OK)status=NBRIDGE_OK
 end subroutine
end module
