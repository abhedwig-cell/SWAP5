program test_n_reference_mineral_trial
 use iso_fortran_env,only:real64,int64
 use mod_fmr_serialized_reference_backend,only:fmr_water_flux_substep_trace_t
 use mod_b111_n_reference_mineral_trial
 use mod_b111_soil_n_mineral_owner
 use mod_soil_n_pool_state
 implicit none
 type(fmr_water_flux_substep_trace_t)::t,steps(2)
 type(mineral_parameters_t)::p
 type(mineral_state_t)::old,new
 type(soil_n_pool_state_t)::pools,check_pools
 type(mineral_receipt_t)::receipt
 type(mineral_receipt_t),allocatable::receipts(:)
 real(real64)::clock,w
 integer(int64)::revision
 integer::status
 p%dz_cm=[30d0]
 p%inventory%depth_m=.3d0
 p%inventory%nfrac_fom=[.01d0]
 p%inventory%nfrac_biomass=.03d0
 p%inventory%nfrac_humus=.04d0
 p%drybd=1300d0
 p%c_top=[.005d0,.015d0]
 call initialize_soil_n_pool_state(p%inventory,[0d0],0d0,0d0,.002d0,.003d0,pools,status)
 if(status/=0)error stop 'init pools'
 call initialize_mineral(p,13_int64,0d0,.3d0,pools,old,status)
 if(status/=MINERAL_OK)error stop 'init mineral'
 t%pond_storage_available=.true.
 t%converged_surface_available=.true.
 t%converged_gross_sources_available=.true.
 t%t0=0d0;t%t1=1d0
 t%top_flux=0d0
 t%converged_rain_rate_cm_day=.4d0
 t%converged_pond_evaporation_cm_day=.4d0
 call trial_mineral_from_reference_gross(old,t,.3d0,0d0,0d0,0d0,0d0,new,receipt,status)
 if(status/=N_TRIAL_OK)error stop 'Reference gross mineral'
 if(abs(receipt%external_in-.004d0*sum(p%c_top))>1d-12)error stop 'external N'
 call old%snapshot(clock,w,check_pools,revision)
 if(revision/=0_int64.or.abs(check_pools%ammonium_n_kg_m2-.002d0)>1d-12) &
   error stop 'original mutated'
 call new%snapshot(clock,w,check_pools,revision)
 if(revision/=1_int64.or.abs(check_pools%ammonium_n_kg_m2-.00202d0)>1d-12) &
   error stop 'candidate NH4'
 if(abs(check_pools%nitrate_n_kg_m2-.00306d0)>1d-12)error stop 'candidate NO3'
 t%converged_runon_rate_cm_day=.1d0
 call trial_mineral_from_reference_gross(old,t,.3d0,0d0,0d0,0d0,0d0,new,receipt,status)
 if(status==N_TRIAL_OK)error stop 'runon without concentration contract accepted'
 call new%snapshot(clock,w,check_pools,revision)
 if(revision/=0_int64)error stop 'rejected candidate committed'
 ! Two source-authorized daily traces stage together or both roll back.
 steps(1)=t
 steps(1)%converged_runon_rate_cm_day=0d0
 steps(2)=steps(1)
 steps(2)%t0=1d0
 steps(2)%t1=2d0
 call trial_mineral_gross_days(old,steps,[.3d0,.3d0],[0d0,0d0], &
     [0d0,0d0],[0d0,0d0],[0d0,0d0],new,receipts,status)
 if(status/=N_TRIAL_OK)error stop 'two gross daily trials'
 call new%snapshot(clock,w,check_pools,revision)
 if(revision/=2_int64.or.abs(check_pools%ammonium_n_kg_m2-.00204d0)>1d-12) &
   error stop 'two-day NH4 inventory'
 if(abs(check_pools%nitrate_n_kg_m2-.00312d0)>1d-12)error stop 'two-day NO3 inventory'
 steps(2)%converged_runon_rate_cm_day=.1d0
 call trial_mineral_gross_days(old,steps,[.3d0,.3d0],[0d0,0d0], &
     [0d0,0d0],[0d0,0d0],[0d0,0d0],new,receipts,status)
 if(status==N_TRIAL_OK)error stop 'late rejection bypassed'
 call new%snapshot(clock,w,check_pools,revision)
 if(revision/=0_int64.or.clock/=0d0)error stop 'late rejection mutated output'
 call old%snapshot(clock,w,check_pools,revision)
 if(revision/=0_int64.or.abs(check_pools%ammonium_n_kg_m2-.002d0)>1d-12) &
   error stop 'late rejection mutated committed state'
 print '(A)','MC_NUT01_REFERENCE_MINERAL_TRIAL=PASS'
end program
