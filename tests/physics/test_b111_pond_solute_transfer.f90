program test_b111_pond_solute_transfer
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_solute_mobile_salt_state, only: mobile_salt_state_t, initialize_mobile_salt_state, SOLUTE_OK
  use mod_solute_compartment_state, only: solute_compartment_state_t, initialize_solute_compartment_state, SOLCOMP_OK
  use mod_b111_pond_solute_transfer
  implicit none
  type(mobile_salt_state_t)::m,candm
  type(solute_compartment_state_t)::s,cands
  type(b111_pond_transfer_receipt_t)::r
  real(real64)::dz(2),theta(2),before
  integer::status

  dz=[10.0_real64,10.0_real64]
  theta=[0.2_real64,0.2_real64]
  call initialize_mobile_salt_state(dz,theta,[1.0_real64,1.0_real64],m,status)
  call check(status==SOLUTE_OK,'mobile init')
  call initialize_solute_compartment_state([0.0_real64,0.0_real64],0.5_real64,0.0_real64, &
       [0.0_real64,0.0_real64],s,status)
  call check(status==SOLCOMP_OK,'companion init')
  before=sum(m%mass_mg_cm2)+s%solute_total()

  call apply_b111_pond_solute_transfer(m,s,theta,dz,0.1_real64,2.0_real64,0.05_real64,4.0_real64, &
       -0.2_real64,0.0_real64,0.3_real64,1.0_real64,candm,cands,r)
  call check(r%status==B111_POND_TRANSFER_OK,'infiltration transfer')
  call near(sum(candm%mass_mg_cm2)+cands%solute_total(),before+r%external_input,'whole solute balance')
  call check(r%internal_to_top>0.0_real64,'pond to soil internal transfer')
  call near(candm%mass_mg_cm2(2),m%mass_mg_cm2(2),'only top node receives pond solute')

  call apply_b111_pond_solute_transfer(m,s,theta,dz,0.1_real64,2.0_real64,0.05_real64,4.0_real64, &
       0.0_real64,0.0_real64,0.3_real64,1.0_real64,candm,cands,r)
  call check(r%status==B111_POND_TRANSFER_OK,'no infiltration transfer')
  call near(r%internal_to_top,0.0_real64,'no internal transfer')
  call near(sum(candm%mass_mg_cm2),sum(m%mass_mg_cm2),'mobile unchanged without infiltration')
  call near(cands%pond_mass,s%pond_mass+r%external_input,'pond retains external input')

  print '(A)','B111_POND_SOLUTE_TRANSFER_PASS'
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
