program test_b111_surface_n_gross_budget
 use, intrinsic :: iso_fortran_env, only: real64
 use mod_b111_surface_n_gross_budget
 implicit none
 type(surface_n_gross_request_t)::f
 type(surface_n_gross_receipt_t)::r
 real(real64),parameter::eps=1.0e-12_real64
 ! Same net-zero hydraulic endpoint, different gross chemical input.
 f%gross_rain_cm=0.4_real64
 f%evaporation_cm=0.4_real64
 f%rain_n_kg_m2=[2.0e-5_real64,6.0e-5_real64]
 call evaluate_surface_n_gross_budget(f,r)
 if(r%status/=SURFACE_N_OK)error stop 'gross rain with equal evaporation'
 if(maxval(abs(r%dry_n_final_kg_m2-f%rain_n_kg_m2))>eps)error stop 'N mass lost with evaporation'
 if(maxval(abs(r%soil_n_input_kg_m2))>eps)error stop 'unqualified dry soil injection'
 if(maxval(abs(r%n_residual_kg_m2))>eps)error stop 'gross dry mass closure'
 ! A later accepted wet interval transfers the retained deposit exactly once.
 f=surface_n_gross_request_t()
 f%dry_n_initial_kg_m2=r%dry_n_final_kg_m2
 f%gross_rain_cm=0.4_real64
 f%infiltration_cm=0.2_real64
 f%runoff_cm=0.1_real64
 f%pond_end_cm=0.1_real64
 call evaluate_surface_n_gross_budget(f,r)
 if(r%status/=SURFACE_N_OK)error stop 'wet deposition transfer'
 if(maxval(abs(r%soil_n_input_kg_m2-0.5_real64*f%dry_n_initial_kg_m2))>eps) &
   error stop 'N infiltration handoff'
 if(maxval(abs(r%runoff_n_export_kg_m2-0.25_real64*f%dry_n_initial_kg_m2))>eps) &
   error stop 'N runoff export'
 if(maxval(abs(r%pond_n_final_kg_m2-0.25_real64*f%dry_n_initial_kg_m2))>eps) &
   error stop 'N pond persistence'
 if(maxval(abs(r%n_residual_kg_m2))>eps)error stop 'wet mass closure'
 ! Gross is not a signed replacement for the hydrologic net carrier.
 f%pond_end_cm=0.3_real64
 call evaluate_surface_n_gross_budget(f,r)
 if(r%status/=SURFACE_N_WATER_BALANCE)error stop 'fabricated water admitted'
 f=surface_n_gross_request_t()
 f%pond_n_initial_kg_m2(1)=1.0_real64
 call evaluate_surface_n_gross_budget(f,r)
 if(r%status==SURFACE_N_OK)error stop 'orphan dissolved pond stock'
 print '(A)','MC_NUT01_GROSS_NET_SURFACE_N_BUDGET=PASS'
end program
