program test_b111_reactive_solute_substep
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_solute_mobile_salt_state, only: mobile_salt_state_t,initialize_mobile_salt_state,SOLUTE_OK
  use mod_solute_compartment_state, only: solute_compartment_state_t,initialize_solute_compartment_state,SOLCOMP_OK
  use mod_b111_reactive_solute_substep
  implicit none
  type(mobile_salt_state_t)::m,cm
  type(solute_compartment_state_t)::s,cs
  type(b111_reactive_dispersion_t)::p
  type(b111_reactive_substep_receipt_t)::r
  real(real64),allocatable::qdra(:,:)
  integer::status
  real(real64)::total0,total1

  call initialize_mobile_salt_state([10.0_real64],[0.2_real64],[1.0_real64],m,status)
  call check(status==SOLUTE_OK,'mobile init')
  call initialize_solute_compartment_state([1.0_real64],0.5_real64,0.0_real64,[0.0_real64],s,status)
  call check(status==SOLCOMP_OK,'companion init')
  allocate(p%dispersivity_cm(0),p%theta_sat_left(0),p%face_distance_cm(0),p%face_left_weight(0),p%face_right_weight(0))
  allocate(qdra(0,1))

  total0=sum(m%mass_mg_cm2)+s%solute_total()
  call advance_b111_reactive_solute_substep(m,s,[10.0_real64],[0.2_real64],[-0.1_real64,0.0_real64], &
       [0.0_real64],qdra,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.2_real64,0.0_real64,0.0_real64,0.0_real64, &
       .true.,[20.0_real64],[0.0_real64],[0.2_real64],[1.0_real64],[0.0_real64],[1.0_real64], &
       [0.1_real64],[1.0_real64],1.0_real64,1.0_real64,1.0_real64,p,cm,cs,r)
  call check(r%status==B111_REACTIVE_OK,'pond+sorption substep')
  total1=sum(cm%mass_mg_cm2)+cs%solute_total()
  call near(total1,total0,'whole mass conserved')
  call near(cs%pond_mass,1.0_real64/3.0_real64,'pond residual')
  call near(cm%concentration_mg_cm3(1),19.0_real64/18.0_real64,'linear Freundlich concentration')
  call near(r%balance_residual,0.0_real64,'pond+sorption balance')

  ! Add 10%/day decay at T=20 and unit moisture factor.
  s=cs;m=cm;total0=sum(m%mass_mg_cm2)+s%solute_total()
  call advance_b111_reactive_solute_substep(m,s,[10.0_real64],[0.2_real64],[-0.1_real64,0.0_real64], &
       [0.0_real64],qdra,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.2_real64,0.0_real64,0.0_real64,0.0_real64, &
       .true.,[20.0_real64],[0.0_real64],[0.2_real64],[1.0_real64],[0.1_real64],[1.0_real64], &
       [0.1_real64],[1.0_real64],1.0_real64,1.0_real64,1.0_real64,p,cm,cs,r)
  call check(r%status==B111_REACTIVE_OK,'decay substep')
  call check(r%decay_output>0.0_real64,'positive decay sink')
  call near(sum(cm%mass_mg_cm2)+cs%solute_total(),total0-r%decay_output,'decay external loss closure')
  call near(r%balance_residual,0.0_real64,'decay balance')

  print '(A)','B111_REACTIVE_SOLUTE_SUBSTEP_PASS'
contains
  subroutine near(x,y,label)
    real(real64),intent(in)::x,y
    character(len=*),intent(in)::label
    call check(abs(x-y)<=5e-11_real64*max(1.0_real64,abs(x),abs(y)),label)
  end subroutine
  subroutine check(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      print '(A)',trim(label)//' failed';error stop 1
    end if
  end subroutine
end program
