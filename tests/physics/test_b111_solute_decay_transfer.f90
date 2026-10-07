program test_b111_solute_decay_transfer
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_solute_mobile_salt_state, only: mobile_salt_state_t, initialize_mobile_salt_state, SOLUTE_OK
  use mod_solute_compartment_state, only: solute_compartment_state_t, initialize_solute_compartment_state, SOLCOMP_OK
  use mod_b111_solute_decay_transfer
  implicit none
  type(mobile_salt_state_t)::m,cm
  type(solute_compartment_state_t)::s,cs
  type(b111_decay_transfer_receipt_t)::r
  integer::status

  call initialize_mobile_salt_state([10.0_real64],[0.2_real64],[1.0_real64],m,status)
  call check(status==SOLUTE_OK,'mobile init')
  call initialize_solute_compartment_state([1.0_real64],0.0_real64,0.0_real64,[0.0_real64],s,status)
  call check(status==SOLCOMP_OK,'companion init')

  call apply_b111_solute_decay_transfer(m,s,[0.2_real64],[10.0_real64],.true.,[20.0_real64],[0.0_real64], &
       [0.2_real64],[1.0_real64],[0.1_real64],[1.0_real64],[0.1_real64],[1.0_real64], &
       1.0_real64,1.0_real64,1.0_real64,cm,cs,r)
  call check(r%status==B111_DECAY_TRANSFER_OK,'decay transfer')
  call near(r%mass_before,3.0_real64,'mass before')
  call near(r%external_decay_output,0.3_real64,'decay sink')
  call near(r%mass_after,2.7_real64,'mass after')
  call near(cm%concentration_mg_cm3(1),0.9_real64,'repartition concentration')
  call near(cm%mass_mg_cm2(1),1.8_real64,'dissolved repartition')
  call near(cs%sorbed_matrix_mass(1),0.9_real64,'sorbed repartition')
  call near(r%balance_residual,0.0_real64,'whole mass balance')
  print '(A)','B111_SOLUTE_DECAY_TRANSFER_PASS'
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
