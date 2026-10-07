program test_b111_age_tracer_transfer
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_solute_compartment_state, only: solute_compartment_state_t, initialize_solute_compartment_state, SOLCOMP_OK
  use mod_b111_age_tracer_transfer
  implicit none
  type(solute_compartment_state_t)::s,c
  type(b111_age_transfer_receipt_t)::r
  integer::status

  call initialize_solute_compartment_state([1.0_real64,2.0_real64],0.5_real64,0.25_real64, &
       [3.0_real64,4.0_real64],s,status)
  call check(status==SOLCOMP_OK,'state init')
  call apply_b111_age_production_transfer(s,[0.2_real64,0.3_real64],[0.4_real64,0.5_real64], &
       [10.0_real64,20.0_real64],2.0_real64,c,r)
  call check(r%status==B111_AGE_TRANSFER_OK,'age transfer')
  call near(r%chemical_mass_after,r%chemical_mass_before,'chemical mass unchanged')
  call near(r%age_after-r%age_before,r%age_production,'age production balance')
  call check(all(c%age_amount>s%age_amount),'persistent age increases')
  print '(A)','B111_AGE_TRACER_TRANSFER_PASS'
contains
  subroutine near(x,y,label)
    real(real64),intent(in)::x,y
    character(len=*),intent(in)::label
    call check(abs(x-y)<=1e-12_real64*max(1.0_real64,abs(x),abs(y)),label)
  end subroutine
  subroutine check(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then
      print '(A)',trim(label)//' failed'
      error stop 1
    end if
  end subroutine
end program
