program test_solute_pond_matrix_transfer
 use iso_fortran_env,only:real64
 use mod_solute_mobile_salt_state
 use mod_solute_compartment_state
 use mod_solute_pond_matrix_transfer
 implicit none
 type(mobile_salt_state_t)::m,mc
 type(solute_compartment_state_t)::s,sc
 type(solute_pond_matrix_receipt_t)::r
 integer::status
 real(real64)::water(2),dz(2)
 water=[.25d0,.5d0];dz=[10d0,10d0]
 call initialize_mobile_salt_state(dz,water,[1d0,1d0],m,status)
 call initialize_solute_compartment_state([0d0,0d0],3d0,0d0,[0d0,0d0],s,status)
 call apply_pond_to_matrix_transfer(m,s,1.5d0,water,dz,mc,sc,r)
 call check(r%status==SOLPOND_OK,'transfer status')
 call near(r%balance_residual,0d0,'balance')
 call near(sc%pond_mass,1.5d0,'pond debit')
 call near(mc%mass_mg_cm2(1),4d0,'matrix credit')
 call near(mc%concentration_mg_cm3(1),1.6d0,'matrix concentration')
 call near(s%pond_mass,3d0,'committed pond unchanged')
 call near(m%mass_mg_cm2(1),2.5d0,'committed matrix unchanged')
 call apply_pond_to_matrix_transfer(m,s,4d0,water,dz,mc,sc,r)
 call check(r%status==SOLPOND_OVERDRAW,'overdraw rejected')
 print '(A)','SOLUTE_POND_MATRIX_TRANSFER_PASS'
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
