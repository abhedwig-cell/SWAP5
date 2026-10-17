program test_surface_loss_incumbent
 use iso_fortran_env,only:real64
 use mod_b111_surface_loss_budget
 implicit none
 type(surface_loss_receipt_t)::r
 real(real64)::denom,legacy_soil
 ! Literal equation from admitted mod_b111_pond_solute_exchange.f90;
 ! not a compiled call to that production module.
 call evaluate_surface_loss_budget(1d0,2d0,1d0,1d0,0d0,0.5d0,0d0,0d0,3d0,0d0,0d0,r)
 if(r%status/=SURFACE_LOSS_OK)error stop 'no-loss case'
 denom=r%depth_end+0.5d0
 legacy_soil=5d0/denom*0.5d0
 if(abs(legacy_soil-r%infiltrated_mass)>1d-12)error stop 'zero-loss mismatch'
 call evaluate_surface_loss_budget(1d0,2d0,1d0,0d0,0d0,0.25d0,0.5d0,0d0,0d0,0d0,0d0,r)
 if(r%status/=SURFACE_LOSS_OK)error stop 'evap case'
 denom=r%depth_end+0.25d0
 legacy_soil=2d0/denom*0.25d0
 if(abs(legacy_soil-1d0)>1d-12)error stop 'source expression'
 if(abs(r%infiltrated_mass-0.5d0)>1d-12)error stop 'candidate expression'
 if(abs(legacy_soil-r%infiltrated_mass-0.5d0)>1d-12)error stop 'discriminator'
 print '(a)','SURFACE_LOSS_INCUMBENT_DISCRIMINATOR_PASS'
end program
