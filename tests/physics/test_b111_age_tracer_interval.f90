program test_b111_age_tracer_interval
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_solute_compartment_state, only: solute_compartment_state_t,initialize_solute_compartment_state,SOLCOMP_OK
  use mod_b111_age_tracer_matrix_substep, only: b111_age_matrix_physics_t
  use mod_b111_age_tracer_interval
  implicit none
  type(solute_compartment_state_t)::s,c
  type(b111_age_matrix_physics_t)::p
  type(b111_age_interval_receipt_t)::r
  real(real64),allocatable::qdra(:,:)
  real(real64)::chem
  integer::status

  call initialize_solute_compartment_state([1.0_real64,2.0_real64],0.5_real64,0.25_real64, &
       [2.0_real64,3.0_real64],s,status,1.0_real64)
  call check(status==SOLCOMP_OK,'state init')
  chem=s%solute_total()

  allocate(p%dispersivity_cm(1),p%theta_sat_left(1),p%face_distance_cm(1), &
       p%face_left_weight(1),p%face_right_weight(1))
  p%molecular_diffusion_cm2_day=0.0_real64
  p%dispersivity_cm=0.0_real64
  p%theta_sat_left=0.45_real64
  p%face_distance_cm=15.0_real64
  p%face_left_weight=0.5_real64
  p%face_right_weight=0.5_real64
  allocate(qdra(0,2))

  call advance_b111_age_tracer_matrix_interval(s,[10.0_real64,20.0_real64], &
       [0.2_real64,0.3_real64],[0.2_real64,0.3_real64], &
       [-0.1_real64,0.0_real64,0.0_real64],[0.0_real64,0.0_real64],qdra, &
       0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.2_real64,0.0_real64,0.0_real64,0.5_real64,p,c,r)
  call check(r%status==B111_AGE_INTERVAL_OK,'age interval')
  call near(r%surface%soil_age_transfer,0.2_real64,'pond to soil transfer')
  call near(r%matrix%top_input,0.2_real64,'matrix top input identity')
  call near(c%pond_age_amount,0.8_real64,'pond age residual')
  call near(c%age_amount(1),3.2_real64,'top node age')
  call near(c%age_amount(2),6.0_real64,'bottom node age')
  call near(r%age_before,6.0_real64,'whole age before')
  call near(r%age_after,10.0_real64,'whole age after')
  call near(r%age_production,4.0_real64,'whole age production')
  call near(r%balance_residual,0.0_real64,'whole age balance')
  call near(c%solute_total(),chem,'chemical mass unchanged')

  print '(A)','B111_AGE_TRACER_INTERVAL_PASS'
contains
  subroutine near(x,y,label)
    real(real64),intent(in)::x,y
    character(len=*),intent(in)::label
    call check(abs(x-y)<=3e-12_real64*max(1.0_real64,abs(x),abs(y)),label)
  end subroutine
  subroutine check(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then
      print '(A)',trim(label)//' failed';error stop 1
    end if
  end subroutine
end program
