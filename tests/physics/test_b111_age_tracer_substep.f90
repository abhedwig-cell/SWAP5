program test_b111_age_tracer_substep
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_solute_compartment_state, only: solute_compartment_state_t,initialize_solute_compartment_state,SOLCOMP_OK
  use mod_b111_age_tracer_substep
  implicit none

  type(solute_compartment_state_t)::s,c
  type(b111_age_tracer_substep_forcing_t)::f
  type(b111_age_tracer_substep_receipt_t)::r
  integer::status
  real(real64)::chem_before

  call initialize_solute_compartment_state([1.0_real64],0.5_real64,0.25_real64,[0.0_real64],s,status, &
       age_pond_previous_concentration=0.0_real64)
  call check(status==SOLCOMP_OK,'state init')
  chem_before=s%solute_total()

  f%dt_day=1.0_real64
  f%theta=[0.2_real64]
  f%theta_previous=[0.2_real64]
  f%dz_cm=[10.0_real64]
  f%q_face_up_cm_day=[0.0_real64,0.0_real64]
  f%root_sink_cm_day=[0.0_real64]
  allocate(f%qdra_cm_day(0,1))
  f%pond_previous_cm=0.0_real64
  f%pond_end_cm=0.0_real64

  call advance_b111_age_tracer_substep(s,f,c,r)
  call check(r%status==B111_AGE_SUBSTEP_OK,'pure ageing')
  call near(r%production_amount_cm_day,2.0_real64,'pure ageing production')
  call near(c%age_amount(1),2.0_real64,'pure ageing amount')
  call near(c%solute_total(),chem_before,'chemical mass unchanged')
  call near(r%balance_residual_cm_day,0.0_real64,'pure ageing balance')

  ! Previous accepted pond age is an age input to the soil when infiltration occurs.
  s%age_amount=[0.0_real64]
  s%age_pond_previous_concentration=3.0_real64
  f%pond_previous_cm=0.5_real64
  f%pond_end_cm=0.5_real64
  f%q_face_up_cm_day(1)=-0.1_real64
  call advance_b111_age_tracer_substep(s,f,c,r)
  call check(r%status==B111_AGE_SUBSTEP_OK,'pond age transfer')
  call near(r%pond_to_soil_cm_day,0.25_real64,'pond-to-soil age amount')
  call near(r%pond_age_end_day,2.5_real64,'new pond age concentration')
  call near(c%age_pond_previous_concentration,2.5_real64,'persisted pond age continuation')
  call near(c%age_amount(1),2.25_real64,'pond plus production')
  call near(c%solute_total(),chem_before,'pond age leaves chemical mass unchanged')
  call near(r%balance_residual_cm_day,0.0_real64,'pond age balance')

  ! Root uptake exports age amount while zero-order ageing continues.
  s%age_amount=[2.0_real64]
  s%age_pond_previous_concentration=0.0_real64
  f%pond_previous_cm=0.0_real64
  f%pond_end_cm=0.0_real64
  f%q_face_up_cm_day=0.0_real64
  f%root_sink_cm_day=[0.1_real64]
  call advance_b111_age_tracer_substep(s,f,c,r)
  call check(r%status==B111_AGE_SUBSTEP_OK,'root age export')
  call near(r%root_export_cm_day,0.1_real64,'root age export amount')
  call near(c%age_amount(1),3.9_real64,'root export plus ageing')
  call near(r%balance_residual_cm_day,0.0_real64,'root age balance')
  call near(c%solute_total(),chem_before,'root age leaves chemical mass unchanged')

  print '(A)','B111_AGE_TRACER_SUBSTEP_PASS'

contains
  subroutine near(x,y,label)
    real(real64),intent(in)::x,y
    character(len=*),intent(in)::label
    call check(abs(x-y)<=1.0e-11_real64*max(1.0_real64,abs(x),abs(y)),label)
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
