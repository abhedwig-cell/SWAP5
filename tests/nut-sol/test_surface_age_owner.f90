program test_surface_age_owner
 use, intrinsic :: iso_fortran_env, only: real64,int64
 use mod_b111_surface_age_budget
 use mod_b111_surface_age_owner
 implicit none
 type(surface_age_owner_t)::committed,candidate,restored
 type(surface_age_restart_t)::payload
 type(surface_age_request_t)::q
 type(surface_age_receipt_t)::receipt
 integer::status
 integer(int64)::revision
 real(real64)::t,d,stock
 logical::valid
 call initialize_surface_age_owner(12_int64,0.0_real64,1.0_real64,2.0_real64,committed,status)
 if(status/=AGE_OWNER_OK)error stop 'initialize'
 q%dt_day=0.25_real64
 q%pond_start_cm=1.0_real64
 q%pond_end_cm=1.5_real64
 q%rain_depth_cm=1.0_real64
 q%infiltration_depth_cm=0.5_real64
 q%pond_age_stock_cm_day=2.0_real64
 call advance_surface_age_owner(committed,q,candidate,receipt,status)
 if(status/=AGE_OWNER_OK)error stop 'candidate'
 call snapshot_surface_age_owner(committed,t,d,stock,revision,valid)
 if(.not.valid.or.revision/=0_int64)error stop 'trial mutated committed'
 if(abs(t)>1.0e-12_real64.or.abs(d-1.0_real64)>1.0e-12_real64)error stop 'rollback'
 if(abs(stock-2.0_real64)>1.0e-12_real64)error stop 'rollback stock'
 committed=candidate
 call export_surface_age_restart(committed,payload,status)
 if(status/=AGE_OWNER_OK)error stop 'export'
 call restore_surface_age_restart(payload,13_int64,restored,status)
 if(status==AGE_OWNER_OK)error stop 'wrong identity restart accepted'
 call restore_surface_age_restart(payload,12_int64,restored,status)
 if(status/=AGE_OWNER_OK)error stop 'restart'
 call snapshot_surface_age_owner(restored,t,d,stock,revision,valid)
 if(.not.valid.or.revision/=1_int64)error stop 'restart revision'
 if(abs(d-1.5_real64)>1.0e-12_real64)error stop 'restart depth'
 q%pond_start_cm=1.0_real64
 call advance_surface_age_owner(restored,q,candidate,receipt,status)
 if(status==AGE_OWNER_OK)error stop 'inconsistent depth accepted'
 call snapshot_surface_age_owner(restored,t,d,stock,revision,valid)
 if(revision/=1_int64)error stop 'rejected trial mutated state'
 print *, 'MC_SOL01_SURFACE_AGE_OWNER=PASS'
end program
