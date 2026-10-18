program test_surface_age_soil_handoff
 use iso_fortran_env, only: real64
 use mod_b111_surface_age_budget
 use mod_b111_surface_age_soil_handoff
 implicit none
 type(surface_age_request_t)::q
 type(surface_age_receipt_t)::r
 real(real64),allocatable::after(:)
 real(real64)::before(2),transferred
 integer::status
 q%dt_day=0.25_real64
 q%pond_start_cm=1.0_real64
 q%pond_end_cm=1.5_real64
 q%pond_age_stock_cm_day=2.0_real64
 q%rain_depth_cm=1.0_real64
 q%infiltration_depth_cm=0.5_real64
 call advance_surface_age_budget(q,r)
 if(r%status/=SURFACE_AGE_OK)error stop 'surface budget'
 before=[2.0_real64,3.0_real64]
 call trial_infiltrated_age_to_soil(before,r,after,transferred,status)
 if(status/=AGE_HANDOFF_OK)error stop 'handoff'
 if(abs(transferred-r%infiltration_age_export_cm_day)>1.0e-12_real64)error stop 'transfer mismatch'
 if(abs(after(1)-before(1)-transferred)>1.0e-12_real64)error stop 'first cell balance'
 if(abs(after(2)-before(2))>1.0e-12_real64)error stop 'unaffected cell drift'
 if(abs(r%pond_end_stock_cm_day+sum(after)-sum(before)+r%runoff_age_export_cm_day- &
   (q%pond_age_stock_cm_day+r%age_production_cm_day+r%external_age_input_cm_day))>1.0e-12_real64) &
   error stop 'whole age balance'
 before(1)=-1.0_real64
 call trial_infiltrated_age_to_soil(before,r,after,transferred,status)
 if(status==AGE_HANDOFF_OK)error stop 'negative soil amount admitted'
 print *, 'MC_SOL01_SURFACE_AGE_SOIL_HANDOFF=PASS'
end program
