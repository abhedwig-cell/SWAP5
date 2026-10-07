program test_solute_sorption_transfer
 use iso_fortran_env, only: real64
 use mod_solute_mobile_salt_state
 use mod_solute_compartment_state
 use mod_solute_sorption_transfer
 implicit none
 type(mobile_salt_state_t)::m,mc
 type(solute_compartment_state_t)::s,sc
 type(sorption_transfer_receipt_t)::r
 integer::status
 real(real64)::water(2),dz(2)
 water=[.25d0,.30d0];dz=[10d0,10d0]
 call initialize_mobile_salt_state(dz,water,[2d0,1d0],m,status)
 call check(status==SOLUTE_OK,'mobile init')
 call initialize_solute_compartment_state([1d0,2d0],0d0,0d0,[0d0,0d0],s,status)
 call check(status==SOLCOMP_OK,'companion init')
 call apply_matrix_sorption_transfer(m,s,water,dz,[1d0,-.5d0],mc,sc,r)
 call check(r%status==SORPTION_TRANSFER_OK,'bidirectional transfer')
 call check(abs(r%balance_residual)<1d-12,'combined closure')
 call check(abs(sum(mc%mass_mg_cm2)+sum(sc%sorbed_matrix_mass) - &
                (sum(m%mass_mg_cm2)+sum(s%sorbed_matrix_mass)))<1d-12,'combined mass')
 call check(abs(mc%concentration_mg_cm3(1)-1.6d0)<1d-12,'concentration reconstructed')
 call check(abs(sum(m%mass_mg_cm2)-8d0)<1d-12,'committed mobile unchanged')
 call check(abs(sum(s%sorbed_matrix_mass)-3d0)<1d-12,'committed sorbed unchanged')
 call apply_matrix_sorption_transfer(m,s,water,dz,[100d0,0d0],mc,sc,r)
 call check(r%status==SORPTION_TRANSFER_NEGATIVE,'dissolved overdraw rejected')
 call check(abs(sum(mc%mass_mg_cm2)-sum(m%mass_mg_cm2))<1d-12,'mobile rollback')
 call check(abs(sum(sc%sorbed_matrix_mass)-sum(s%sorbed_matrix_mass))<1d-12,'sorbed rollback')
 call apply_matrix_sorption_transfer(m,s,water,dz,[0d0,-3d0],mc,sc,r)
 call check(r%status==SORPTION_TRANSFER_NEGATIVE,'sorbed overdraw rejected')
 print '(A)','SOLUTE_SORPTION_TRANSFER_PASS'
contains
 subroutine check(ok,label)
  logical,intent(in)::ok;character(len=*),intent(in)::label
  if(.not.ok)then;print '(A)',trim(label)//' failed';error stop 1;end if
 end subroutine
end program
