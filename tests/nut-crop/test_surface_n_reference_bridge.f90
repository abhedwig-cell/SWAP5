program test_surface_n_reference_bridge
 use iso_fortran_env, only: real64
 use mod_fmr_serialized_reference_backend, only: fmr_water_flux_substep_trace_t
 use mod_b111_surface_n_reference_bridge
 use mod_b111_surface_n_gross_budget
 implicit none
 type(fmr_water_flux_substep_trace_t)::t
 type(surface_n_gross_receipt_t)::r
 integer::status
 real(real64)::c(2)
 c=[0.005_real64,0.015_real64]
 t%pond_storage_available=.true.
 t%converged_surface_available=.true.
 t%converged_gross_sources_available=.true.
 t%t0=0.0_real64
 t%t1=0.25_real64
 t%pond_start_cm=0.0_real64
 t%pond_end_cm=0.0_real64
 t%converged_rain_rate_cm_day=1.6_real64
 t%converged_pond_evaporation_cm_day=1.6_real64
 call surface_n_from_reference(t,c,[0.0_real64,0.0_real64], &
   [0.0_real64,0.0_real64],[0.0_real64,0.0_real64], &
   [0.0_real64,0.0_real64],r,status)
 if(status/=NBRIDGE_OK)error stop 'reference gross 4mm zero net'
 if(maxval(abs(r%dry_n_final_kg_m2-[2.0e-5_real64,6.0e-5_real64]))>1.0e-12_real64) &
   error stop 'atmospheric N amount'
 t%converged_pond_evaporation_cm_day=0.0_real64
 t%pond_end_cm=0.1_real64
 t%top_flux=-0.8_real64
 t%converged_runoff_depth_cm=0.1_real64
 call surface_n_from_reference(t,[0.0_real64,0.0_real64], &
   [0.0_real64,0.0_real64],[0.0_real64,0.0_real64], &
   [0.0_real64,0.0_real64],r%dry_n_final_kg_m2,r,status)
 if(status/=NBRIDGE_OK)error stop 'wet gross Source replay'
 if(maxval(abs(r%soil_n_input_kg_m2-[1.0e-5_real64,3.0e-5_real64]))>1.0e-12_real64) &
   error stop 'actual reference age N to soil'
 t%top_flux=0.8_real64
 call surface_n_from_reference(t,c,[0.0_real64,0.0_real64], &
   [0.0_real64,0.0_real64],[0.0_real64,0.0_real64], &
   [0.0_real64,0.0_real64],r,status)
 if(status==NBRIDGE_OK)error stop 'unowned exfiltration'
 print '(A)','MC_NUT01_REFERENCE_GROSS_N_BRIDGE=PASS'
end program
