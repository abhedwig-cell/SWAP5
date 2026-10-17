program test_surface_loss_real_production
 use iso_fortran_env,only:real64
 use mod_b111_surface_loss_budget
 use mod_b111_pond_solute_exchange,only:b111_pond_solute_result_t,evaluate_b111_pond_solute_exchange,B111_POND_SOL_OK
 implicit none
 type(surface_loss_receipt_t)::candidate
 type(b111_pond_solute_result_t)::accepted
 real(real64),parameter::tol=1d-12
 call evaluate_surface_loss_budget(1d0,2d0,1d0,1d0,0d0,0.5d0,0d0,0d0,3d0,0d0,0d0,candidate)
 call evaluate_b111_pond_solute_exchange(2d0,1d0,3d0,0d0,0d0,-0.5d0,0d0,candidate%depth_end,1d0,accepted)
 if(candidate%status/=SURFACE_LOSS_OK.or.accepted%status/=B111_POND_SOL_OK)error stop 'no-loss status'
 if(abs(candidate%infiltrated_mass-accepted%soil_transfer)>tol)error stop 'no-loss equivalence'
 call evaluate_surface_loss_budget(1d0,2d0,1d0,0d0,0d0,0.25d0,0.5d0,0d0,0d0,0d0,0d0,candidate)
 call evaluate_b111_pond_solute_exchange(2d0,0d0,0d0,0d0,0d0,-0.25d0,0d0,candidate%depth_end,1d0,accepted)
 if(candidate%status/=SURFACE_LOSS_OK.or.accepted%status/=B111_POND_SOL_OK)error stop 'evap status'
 if(abs(candidate%infiltrated_mass-0.5d0)>tol)error stop 'candidate evaporation'
 if(abs(accepted%soil_transfer-1d0)>tol)error stop 'incumbent evaporation'
 if(abs(accepted%soil_transfer-candidate%infiltrated_mass-0.5d0)>tol)error stop 'discriminator'
 print '(a)','SURFACE_LOSS_REAL_PRODUCTION_COMPARE_PASS'
end program
