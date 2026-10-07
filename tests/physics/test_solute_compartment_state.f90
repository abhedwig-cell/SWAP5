program test_solute_compartment_state
 use iso_fortran_env, only: real64
 use mod_solute_compartment_state
 implicit none
 type(solute_compartment_state_t)::s,c
 type(solute_compartment_transfer_t)::t
 type(solute_compartment_receipt_t)::r
 integer::status

 call initialize_solute_compartment_state([2d0,3d0],5d0,7d0,[10d0,20d0],s,status)
 call check(status==SOLCOMP_OK,'init')
 call check(abs(s%solute_total()-17d0)<1d-12,'solute total excludes age')

 allocate(t%sorbed_matrix_delta(2),t%age_amount_delta(2))
 t%sorbed_matrix_delta=[1d0,0d0]
 t%pond_delta=-1d0
 t%aquifer_delta=0d0
 t%age_amount_delta=[.5d0,1d0]
 call apply_solute_compartment_transfer(s,t,c,r)
 call check(r%status==SOLCOMP_OK,'internal transfer')
 call check(abs(r%solute_balance_residual)<1d-12,'internal solute balance')
 call check(abs(c%solute_total()-s%solute_total())<1d-12,'solute conserved')
 call check(abs(sum(c%age_amount)-31.5d0)<1d-12,'age independently updated')
 call check(abs(sum(s%age_amount)-30d0)<1d-12,'committed age unmutated')

 t%sorbed_matrix_delta=0d0
 t%pond_delta=2d0
 t%age_amount_delta=0d0
 t%external_solute_input=2d0
 call apply_solute_compartment_transfer(s,t,c,r)
 call check(r%status==SOLCOMP_OK,'external input')
 call check(abs(c%solute_total()-19d0)<1d-12,'input stored')

 t%external_solute_input=0d0
 call apply_solute_compartment_transfer(s,t,c,r)
 call check(r%status==SOLCOMP_BALANCE,'unbooked creation rejected')
 call check(abs(c%solute_total()-s%solute_total())<1d-12,'balance rollback')

 t%pond_delta=-100d0
 t%external_solute_output=100d0
 call apply_solute_compartment_transfer(s,t,c,r)
 call check(r%status==SOLCOMP_NEGATIVE,'overdraw rejected')
 call check(abs(c%solute_total()-s%solute_total())<1d-12,'negative rollback')

 print '(A)','SOLUTE_COMPARTMENT_STATE_PASS'
contains
 subroutine check(ok,label)
  logical,intent(in)::ok
  character(len=*),intent(in)::label
  if(.not.ok) then
    print '(A)',trim(label)//' failed'
    error stop 1
  end if
 end subroutine
end program
