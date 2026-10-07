program test_b111_age_tracer_matrix_substep
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_solute_compartment_state, only: solute_compartment_state_t,initialize_solute_compartment_state,SOLCOMP_OK
  use mod_b111_age_tracer_matrix_substep
  implicit none
  type(solute_compartment_state_t)::s,c
  type(b111_age_matrix_physics_t)::p
  type(b111_age_matrix_receipt_t)::r
  real(real64)::before_chem
  real(real64),allocatable::qdra(:,:)
  integer::status

  call initialize_solute_compartment_state([1.0_real64,2.0_real64],0.5_real64,0.25_real64, &
       [2.0_real64,3.0_real64],s,status,0.75_real64)
  call check(status==SOLCOMP_OK,'state init')
  before_chem=s%solute_total()

  allocate(p%dispersivity_cm(1),p%theta_sat_left(1),p%face_distance_cm(1), &
       p%face_left_weight(1),p%face_right_weight(1))
  p%molecular_diffusion_cm2_day=0.0_real64
  p%dispersivity_cm=0.0_real64
  p%theta_sat_left=0.45_real64
  p%face_distance_cm=15.0_real64
  p%face_left_weight=0.5_real64
  p%face_right_weight=0.5_real64
  allocate(qdra(0,2))

  call advance_b111_age_matrix_substep(s,[10.0_real64,20.0_real64], &
       [0.2_real64,0.3_real64],[0.2_real64,0.3_real64], &
       [0.0_real64,0.0_real64,0.0_real64],[0.01_real64,0.0_real64],qdra, &
       0.0_real64,0.0_real64,0.0_real64,0.5_real64,p,c,r)
  call check(r%status==B111_AGE_MATRIX_OK,'matrix substep')
  call near(r%age_before,5.0_real64,'age before')
  call near(r%age_production,4.0_real64,'zero-order production')
  call near(r%root_output,0.005_real64,'root age export')
  call near(r%age_after,8.995_real64,'age after')
  call near(r%balance_residual,0.0_real64,'age balance')
  call near(c%solute_total(),before_chem,'chemical mass unchanged')
  call near(c%pond_age_amount,s%pond_age_amount,'pond age unchanged by matrix substep')

  print '(A)','B111_AGE_TRACER_MATRIX_SUBSTEP_PASS'
contains
  subroutine near(x,y,label)
    real(real64),intent(in)::x,y
    character(len=*),intent(in)::label
    call check(abs(x-y)<=2e-12_real64*max(1.0_real64,abs(x),abs(y)),label)
  end subroutine
  subroutine check(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then
      print '(A)',trim(label)//' failed';error stop 1
    end if
  end subroutine
end program
