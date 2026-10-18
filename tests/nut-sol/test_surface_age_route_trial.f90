program test_surface_age_route_trial
 use, intrinsic :: iso_fortran_env, only: real64,int64
 use mod_fmr_serialized_reference_backend, only: fmr_water_flux_substep_trace_t
 use mod_b111_age_tracer_substep, only: b111_age_tracer_substep_forcing_t
 use mod_fmr_b111_age_route, only: age_state_t,age_receipt_t,initialize_age, & 
      consume_accepted_age_trace,AGE_OK
 use mod_b111_surface_age_owner, only: surface_age_owner_t,initialize_surface_age_owner, &
      snapshot_surface_age_owner,AGE_OWNER_OK
 use mod_b111_surface_age_trace_bridge, only: surface_age_source_ages_t
 implicit none
 type(fmr_water_flux_substep_trace_t)::trace(1)
 type(b111_age_tracer_substep_forcing_t)::p
 type(age_state_t)::soil
 type(surface_age_owner_t)::surface
 type(surface_age_source_ages_t)::ages
 type(age_receipt_t)::receipt
 real(real64)::clock,depth,stock
 integer(int64)::revision
 integer::code
 logical::valid
 p%dz_cm=[1.0_real64]
 p%face_left_weight=[real(real64)::]
 p%face_right_weight=[real(real64)::]
 p%face_distance_cm=[real(real64)::]
 p%theta_sat_left=[real(real64)::]
 p%dispersivity_cm=[real(real64)::]
 p%molecular_diffusion_cm2_day=0.0_real64
 call initialize_age(p,17_int64,0.0_real64,[0.30_real64],[1.0_real64],soil,code)
 if(code/=AGE_OK)error stop 'soil init'
 call initialize_surface_age_owner(19_int64,0.0_real64,1.0_real64,2.0_real64,surface,code)
 if(code/=AGE_OWNER_OK)error stop 'surface init'
 trace(1)%t0=0.0_real64
 trace(1)%t1=0.1_real64
 trace(1)%top_flux=-0.5_real64
 trace(1)%bottom_flux=0.0_real64
 trace(1)%water_start=[0.30_real64]
 trace(1)%water_end=[0.35_real64]
 trace(1)%root_sink=[0.0_real64]
 trace(1)%net_node_source=[0.0_real64]
 allocate(trace(1)%drainage_sink_by_level(0,1))
 trace(1)%pond_storage_available=.true.
 trace(1)%converged_surface_available=.true.
 trace(1)%converged_gross_sources_available=.true.
 trace(1)%pond_start_cm=1.0_real64
 trace(1)%pond_end_cm=0.95_real64
 trace(1)%converged_rain_rate_cm_day=0.0_real64
 trace(1)%converged_irrigation_rate_cm_day=0.0_real64
 trace(1)%converged_runon_rate_cm_day=0.0_real64
 trace(1)%converged_snowmelt_rate_cm_day=0.0_real64
 trace(1)%converged_runoff_depth_cm=0.0_real64
 trace(1)%converged_pond_evaporation_cm_day=0.0_real64
 ! Default age route must reject all top flux and not mutate the soil owner.
 call consume_accepted_age_trace(soil,trace,receipt)
 if(receipt%status==AGE_OK)error stop 'unqualified default top accepted'
 call consume_accepted_age_trace(soil,trace,receipt,surface,ages)
 if(receipt%status/=AGE_OK)error stop 'opt-in route rejected valid transfer'
 if(abs(receipt%residual)>1.0e-10_real64)error stop 'soil age not conserved'
 if(receipt%external_in<=0.0_real64)error stop 'infiltration not delivered to soil'
 call snapshot_surface_age_owner(surface,clock,depth,stock,revision,valid)
 if(.not.valid.or.abs(clock-0.1_real64)>1.0e-12_real64)error stop 'time'
 if(abs(depth-0.95_real64)>1.0e-12_real64)error stop 'surface water depth'
 if(revision/=1_int64)error stop 'surface revision'
 if(stock<=0.0_real64)error stop 'surface stock'
 print *, 'MC_SOL01_SURFACE_SOIL_ACCEPTED_TRACE=PASS'
end program
