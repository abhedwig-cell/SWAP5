program test_b111_soil_n_addition
 use iso_fortran_env,only:real64
 use mod_soil_n_pool_state
 use mod_b111_soil_n_addition
 implicit none
 type(soil_n_inventory_parameters_t)::ownerp
 type(soil_n_pool_state_t)::s,c
 type(soil_n_transfer_t)::t
 type(soil_n_receipt_t)::r
 type(b111_soil_n_material_t)::m
 type(b111_soil_n_split_parameters_t)::p
 integer::status
 ownerp%depth_m=.5d0
 ownerp%nfrac_fom=[.03d0,.01d0,.03d0,.01d0,.03d0,.01d0,.03d0,.01d0]
 ownerp%nfrac_biomass=.04d0;ownerp%nfrac_humus=.05d0
 call initialize_soil_n_pool_state(ownerp,[0d0,0d0,0d0,0d0,0d0,0d0,0d0,0d0],0d0,0d0,0d0,0d0,s,status)
 p%nfrac_fom_min=.01d0;p%nfrac_fom_max=.03d0;p%nfrac_humus=.05d0;p%asfa_min=.03d0;p%asfa_max=.28d0
 m%application_kg_m2=1d0;m%application_age=1d0;m%organic_matter_fraction=.5d0;m%organic_n_fraction=.025d0
 m%ammonium_n_fraction=.02d0;m%nitrate_n_fraction=.01d0;m%volatilization_fraction=.25d0
 call build_b111_soil_n_addition_transfer(.5d0,m,p,t,status)
 call check(status==B111_NADD_OK,'amend build')
 call apply_soil_n_transfer(ownerp,s,t,c,r)
 call check(r%status==SOIL_N_OK,'amend mass apply')
 call near(r%external_n_input_kg_m2,.02d0+.01d0+.025d0*.5d0,'gross N')
 call near(r%external_n_output_kg_m2,.02d0*.25d0,'volatilized N')
 call near(c%nitrogen_total(ownerp),r%external_n_input_kg_m2-r%external_n_output_kg_m2,'stored N')
 m%volatilization_fraction=0d0;m%application_kg_m2=.4d0
 call build_b111_soil_n_addition_transfer(.5d0,m,p,t,status)
 call apply_soil_n_transfer(ownerp,s,t,c,r)
 call check(r%status==SOIL_N_OK,'residue mass apply')
 call near(r%external_n_output_kg_m2,0d0,'residue no volatilization')
 print '(A)','B111_SOIL_N_ADDITION_PASS'
contains
 subroutine near(x,y,label)
  real(real64),intent(in)::x,y;character(len=*),intent(in)::label
  call check(abs(x-y)<=1d-10*max(1d0,abs(x),abs(y)),label)
 end subroutine
 subroutine check(ok,label)
  logical,intent(in)::ok;character(len=*),intent(in)::label
  if(.not.ok)then;print '(A)',trim(label)//' failed';error stop 1;end if
 end subroutine
end program
