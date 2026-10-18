program test_surface_age_trace_bridge
 use, intrinsic :: iso_fortran_env, only: real64,int64
 use mod_fmr_serialized_reference_backend, only: fmr_water_flux_substep_trace_t
 use mod_b111_surface_age_owner
 use mod_b111_surface_age_budget
 use mod_b111_surface_age_trace_bridge
 implicit none
 type(fmr_water_flux_substep_trace_t)::t
 type(surface_age_owner_t)::base,after
 type(surface_age_source_ages_t)::ages
 type(surface_age_receipt_t)::r
 real(real64)::clock,depth,stock
 integer(int64)::rev
 integer::status
 logical::valid
 call initialize_surface_age_owner(51_int64,0.0_real64,1.0_real64,2.0_real64,base,status)
 if(status/=AGE_OWNER_OK)error stop 'base'
 t%pond_storage_available=.true.
 t%converged_surface_available=.true.
 t%converged_gross_sources_available=.true.
 t%t0=0.0_real64
 t%t1=0.25_real64
 t%pond_start_cm=1.0_real64
 t%pond_end_cm=1.5_real64
 t%top_flux=-1.6_real64
 t%converged_rain_rate_cm_day=2.4_real64
 t%converged_irrigation_rate_cm_day=1.2_real64
 t%converged_runon_rate_cm_day=1.6_real64
 t%converged_snowmelt_rate_cm_day=0.0_real64
 t%converged_runoff_depth_cm=0.2_real64
 t%converged_pond_evaporation_cm_day=0.8_real64
 ages%runon_age_day=2.0_real64
 ages%irrigation_age_day=0.2_real64
 call trial_surface_age_from_accepted_trace(base,t,ages,after,r,status)
 if(status/=AGE_BRIDGE_OK) error stop 'accepted gross trace'
 if(abs(r%residual_cm_day)>1.0e-11_real64)error stop 'age balance'
 if(abs(r%infiltration_age_export_cm_day-r%mixed_age_day*0.4_real64)>1.0e-11_real64) &
   error stop 'age infiltration'
 call snapshot_surface_age_owner(base,clock,depth,stock,rev,valid)
 if(.not.valid.or.rev/=0_int64.or.abs(stock-2.0_real64)>1.0e-12_real64)error stop 'trial mutated owner'
 t%top_flux=1.6_real64
 call trial_surface_age_from_accepted_trace(base,t,ages,after,r,status)
 if(status==AGE_BRIDGE_OK)error stop 'exfiltration accepted'
 t%top_flux=-1.6_real64
 t%converged_snowmelt_rate_cm_day=0.1_real64
 call trial_surface_age_from_accepted_trace(base,t,ages,after,r,status)
 if(status==AGE_BRIDGE_OK)error stop 'melt accepted'
 t%converged_snowmelt_rate_cm_day=0.0_real64
 t%t0=0.1_real64
 call trial_surface_age_from_accepted_trace(base,t,ages,after,r,status)
 if(status==AGE_BRIDGE_OK)error stop 'stale timestamp accepted'
 print *, 'MC_SOL01_REFERENCE_SURFACE_AGE_BRIDGE=PASS'
end program
