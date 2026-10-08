program test_b111_solute_sorption_equilibrium_transfer
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_solute_mobile_salt_state, only: mobile_salt_state_t, initialize_mobile_salt_state, SOLUTE_OK
  use mod_solute_compartment_state, only: solute_compartment_state_t, initialize_solute_compartment_state, SOLCOMP_OK
  use mod_b111_solute_sorption_equilibrium_transfer
  implicit none
  type(mobile_salt_state_t)::m,cm
  type(solute_compartment_state_t)::s,cs
  type(b111_sorption_equilibrium_receipt_t)::r
  integer::status

  call initialize_mobile_salt_state([10.0_real64],[0.2_real64],[1.0_real64],m,status)
  call check(status==SOLUTE_OK,'mobile init')
  call initialize_solute_compartment_state([2.0_real64],0.0_real64,0.0_real64,[0.0_real64],s,status)
  call check(status==SOLCOMP_OK,'companion init')

  call apply_b111_sorption_equilibrium(m,s,[0.2_real64],[10.0_real64],[0.1_real64],[1.0_real64], &
       1.0_real64,1.0_real64,cm,cs,r)
  call check(r%status==B111_SORP_TRANSFER_OK,'equilibrium transfer')
  call near(r%mass_before,4.0_real64,'mass before')
  call near(r%mass_after,4.0_real64,'mass after')
  call near(cm%concentration_mg_cm3(1),4.0_real64/3.0_real64,'equilibrium concentration')
  call near(cm%mass_mg_cm2(1),8.0_real64/3.0_real64,'dissolved mass')
  call near(cs%sorbed_matrix_mass(1),4.0_real64/3.0_real64,'sorbed mass')
  call near(r%balance_residual,0.0_real64,'mass residual')
  print '(A)','B111_SOLUTE_SORPTION_EQUILIBRIUM_TRANSFER_PASS'
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
