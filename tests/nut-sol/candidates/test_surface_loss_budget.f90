program test_surface_loss_budget
 use iso_fortran_env,only:real64
 use mod_b111_surface_loss_budget
 implicit none
 type(surface_loss_receipt_t)::r
 call evaluate_surface_loss_budget(1d0,2d0,1d0,1d0,0d0,0.5d0,0.25d0,0.25d0,3d0,0d0,0.5d0,r)
 if(r%status/=SURFACE_LOSS_OK)error stop 'wet'
 if(abs(r%depth_end-1d0)>1d-12)error stop 'water'
 if(abs(r%external_mass-3.5d0)>1d-12)error stop 'source'
 if(abs(r%infiltrated_mass-1.375d0)>1d-12)error stop 'infiltration'
 if(abs(r%runoff_mass-0.6875d0)>1d-12)error stop 'runoff'
 if(abs(r%mass_end-3.4375d0)>1d-12)error stop 'retained'
 call evaluate_surface_loss_budget(0d0,2d0,1d0,0d0,0d0,0d0,0d0,0d0,0d0,0d0,1d0,r)
 if(r%status/=SURFACE_LOSS_OK.or.abs(r%mass_end-3d0)>1d-12)error stop 'dry retention'
 call evaluate_surface_loss_budget(0d0,3d0,1d0,1d0,0d0,0.5d0,0d0,0d0,0d0,0d0,0d0,r)
 if(r%status/=SURFACE_LOSS_OK.or.abs(r%infiltrated_mass-1.5d0)>1d-12)error stop 'rewet'
 call evaluate_surface_loss_budget(0d0,0d0,1d0,0d0,0d0,1d0,0d0,0d0,0d0,0d0,0d0,r)
 if(r%status/=SURFACE_LOSS_WATER)error stop 'overdraw'
 print '(a)','SURFACE_LOSS_BUDGET=PASS'
end program
