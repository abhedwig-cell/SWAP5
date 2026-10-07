program test_solute_decay_transfer
 use iso_fortran_env, only: real64
 use mod_solute_mobile_salt_state
 use mod_solute_compartment_state
 use mod_solute_decay_transfer
 implicit none
 type(mobile_salt_state_t)::m,mc
 type(solute_compartment_state_t)::s,sc
 type(solute_decay_receipt_t)::r
 integer::status
 real(real64)::water(2),dz(2)
 water=[.25d0,.50d0];dz=[10d0,10d0]
 call initialize_mobile_salt_state(dz,water,[2d0,1d0],m,status)
 call check(status==SOLUTE_OK,'mobile init')
 call initialize_solute_compartment_state([5d0,5d0],0d0,0d0,[0d0,0d0],s,status)
 call check(status==SOLCOMP_OK,'companion init')
 call apply_b111_decay_transfer(m,s,[.1d0,.2d0],water,dz,mc,sc,r)
 call check(r%status==SOLDECAY_OK,'decay status')
 call near(r%removed_mass,.1d0*(5d0+5d0)+.2d0*(5d0+5d0),'removed')
 call near(r%balance_residual,0d0,'combined balance')
 call near(sum(m%mass_mg_cm2),10d0,'committed dissolved immutable')
 call near(sum(s%sorbed_matrix_mass),10d0,'committed sorbed immutable')
 call apply_b111_decay_transfer(m,s,[0d0,0d0],water,dz,mc,sc,r)
 call check(r%status==SOLDECAY_OK,'zero decay')
 call near(r%removed_mass,0d0,'zero removed')
 call apply_b111_decay_transfer(m,s,[1.1d0,0d0],water,dz,mc,sc,r)
 call check(r%status==SOLDECAY_INVALID,'fraction domain')
 print '(A)','SOLUTE_DECAY_TRANSFER_PASS'
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
