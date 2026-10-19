program test_n_direct_gross_binding
 use iso_fortran_env,only:real64
 use mod_fmr_serialized_reference_backend,only:fmr_water_flux_substep_trace_t
 use mod_b111_n_gross_direct_binding
 implicit none
 type(fmr_water_flux_substep_trace_t)::t
 real(real64)::gross
 integer::status
 t%pond_storage_available=.true.
 t%converged_surface_available=.true.
 t%converged_gross_sources_available=.true.
 t%t0=0d0;t%t1=1d0
 t%converged_rain_rate_cm_day=.4d0
 t%converged_pond_evaporation_cm_day=.4d0
 call direct_gross_n_rate_from_reference(t,gross,status)
 if(status/=N_DIRECT_OK)error stop 'accepted gross rain with net zero'
 if(abs(gross-.004d0)>1d-14)error stop 'gross rain conversion'
 ! A plausible but water-inconsistent trace must never convey gross N.
 t%top_flux=-.1d0
 call direct_gross_n_rate_from_reference(t,gross,status)
 if(status==N_DIRECT_OK)error stop 'gross chemical source from inconsistent net water'
 t%top_flux=0d0
 t%converged_runon_rate_cm_day=.1d0
 call direct_gross_n_rate_from_reference(t,gross,status)
 if(status==N_DIRECT_OK)error stop 'unsupported mixed source concentrations'
 t%converged_runon_rate_cm_day=0d0
 t%pond_end_cm=.1d0
 call direct_gross_n_rate_from_reference(t,gross,status)
 if(status==N_DIRECT_OK)error stop 'unowned pond store'
 print '(A)','MC_NUT01_GROSS_DIRECT_REFERENCE_BOUNDING=PASS'
end program
