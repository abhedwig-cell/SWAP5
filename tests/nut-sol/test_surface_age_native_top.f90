program test_surface_age_native_top
 use, intrinsic :: iso_fortran_env, only: real64
 use mod_solute_compartment_state
 use mod_b111_age_tracer_substep
 implicit none
 type(solute_compartment_state_t)::s,c
 type(b111_age_tracer_substep_forcing_t)::f
 type(b111_age_tracer_substep_receipt_t)::r
 integer::status
 real(real64)::initial
 call initialize_solute_compartment_state([0.0_real64],0.0_real64,0.0_real64,[2.0_real64],s,status)
 if(status/=SOLCOMP_OK)error stop 'init'
 f%dt_day=0.1_real64
 f%theta_previous=[0.30_real64]
 f%theta=[0.35_real64]
 f%dz_cm=[1.0_real64]
 f%q_face_up_cm_day=[-0.5_real64,0.0_real64]
 f%root_sink_cm_day=[0.0_real64]
 allocate(f%qdra_cm_day(0,1))
 f%accepted_surface_age_available=.true.
 f%accepted_surface_age_input_cm_day=0.08_real64
 initial=sum(s%age_amount)
 call advance_b111_age_tracer_substep(s,f,c,r)
 if(r%status/=B111_AGE_SUBSTEP_OK)error stop 'top age process'
 if(abs(r%pond_to_soil_cm_day-0.08_real64)>1.0e-12_real64)error stop 'top flux'
 if(abs(sum(c%age_amount)-initial-r%production_amount_cm_day- &
    r%pond_to_soil_cm_day)>1.0e-12_real64)error stop 'soil balance'
 if(abs(r%balance_residual_cm_day)>1.0e-12_real64)error stop 'native balance'
 if(abs(sum(s%age_amount)-initial)>1.0e-12_real64)error stop 'committed mutated'
 f%accepted_surface_age_input_cm_day=-1.0_real64
 call advance_b111_age_tracer_substep(s,f,c,r)
 if(r%status==B111_AGE_SUBSTEP_OK)error stop 'negative accepted age'
 print *, 'MC_SOL01_NATIVE_AGE_TOP_BOUNDARY=PASS'
end program
