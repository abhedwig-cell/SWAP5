program test_soil_n_reaction_transfer
 use iso_fortran_env,only:real64
 use mod_soil_n_pool_state
 use mod_soil_n_reaction_transfer
 implicit none
 type(soil_n_inventory_parameters_t)::p
 type(soil_n_pool_state_t)::s,c
 type(soil_n_transfer_t)::t
 type(soil_n_receipt_t)::r
 integer::status
 p%depth_m=.5d0;p%nfrac_fom=[.01d0,.02d0];p%nfrac_biomass=.03d0;p%nfrac_humus=.04d0
 call initialize_soil_n_pool_state(p,[1d0,2d0],3d0,4d0,4d0,10d0,s,status)
 call build_nitrification_transfer(2,1.5d0,t,status)
 call check(status==SOIL_N_REACTION_OK,'nit build')
 call apply_soil_n_transfer(p,s,t,c,r)
 call check(r%status==SOIL_N_OK,'nit apply');call near(c%ammonium_n_kg_m2,2.5d0,'nh4 debit');call near(c%nitrate_n_kg_m2,11.5d0,'no3 credit')
 call build_denitrification_transfer(2,2d0,t,status)
 call apply_soil_n_transfer(p,s,t,c,r)
 call check(r%status==SOIL_N_OK,'den apply');call near(r%external_n_output_kg_m2,2d0,'den output')
 call build_nitrification_transfer(2,100d0,t,status);call apply_soil_n_transfer(p,s,t,c,r)
 call check(r%status==SOIL_N_NEGATIVE,'overdraw rollback')
 print '(A)','SOIL_N_REACTION_TRANSFER_PASS'
contains
 subroutine near(x,y,label)
  real(real64),intent(in)::x,y;character(len=*),intent(in)::label
  call check(abs(x-y)<=1d-12*max(1d0,abs(x),abs(y)),label)
 end subroutine
 subroutine check(ok,label)
  logical,intent(in)::ok;character(len=*),intent(in)::label
  if(.not.ok)then;print '(A)',trim(label)//' failed';error stop 1;end if
 end subroutine
end program
