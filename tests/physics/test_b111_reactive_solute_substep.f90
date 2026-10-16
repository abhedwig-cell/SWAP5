program test_b111_reactive_solute_substep
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_solute_mobile_salt_state, only: mobile_salt_state_t,initialize_mobile_salt_state,SOLUTE_OK
  use mod_solute_compartment_state, only: solute_compartment_state_t,initialize_solute_compartment_state,SOLCOMP_OK
  use mod_b111_reactive_solute_substep
  implicit none

  type(mobile_salt_state_t)::m,cm
  type(solute_compartment_state_t)::s,cs
  type(b111_reactive_solute_substep_forcing_t)::f
  type(b111_reactive_solute_substep_receipt_t)::r
  integer::status
  real(real64)::before

  call initialize_mobile_salt_state([10.0_real64],[0.2_real64],[1.0_real64],m,status)
  call check(status==SOLUTE_OK,'mobile init')
  call initialize_solute_compartment_state([1.0_real64],0.5_real64,0.25_real64,[0.0_real64],s,status)
  call check(status==SOLCOMP_OK,'companion init')

  f%dt_day=1.0_real64
  f%theta=[0.2_real64]
  f%dz_cm=[10.0_real64]
  f%q_face_up_cm_day=[0.0_real64,0.0_real64]
  f%root_sink_cm_day=[0.0_real64]
  allocate(f%qdra_cm_day(0,1))
  f%cdrain_mg_cm3=0.0_real64
  f%cseep_mg_cm3=0.0_real64
  f%tscf=1.0_real64
  f%macropore_area_fraction=0.0_real64
  f%pond_end_cm=0.5_real64
  f%molecular_diffusion_cm2_day=0.0_real64
  f%temperature_active=.false.
  f%temperature_c=[20.0_real64]
  f%gampar=[0.0_real64]
  f%rtheta=[0.2_real64]
  f%bexp=[1.0_real64]
  f%decpot=[0.0_real64]
  f%fdepth=[1.0_real64]
  f%bulk_density=[0.1_real64]
  f%kf=[1.0_real64]
  f%cref_mg_cm3=1.0_real64
  f%frexp=1.0_real64

  ! Equilibrium manifold: theta*C*dz=2 and bdens*kf*C*dz=1.
  before=sum(m%mass_mg_cm2)+s%solute_total()
  call advance_b111_reactive_solute_substep(m,s,f,cm,cs,r)
  call check(r%status==B111_REACTIVE_OK,'no-op substep')
  call near(sum(cm%mass_mg_cm2)+cs%solute_total(),before,'no-op total mass')
  call near(cm%mass_mg_cm2(1),m%mass_mg_cm2(1),'no-op dissolved')
  call near(cs%sorbed_matrix_mass(1),s%sorbed_matrix_mass(1),'no-op sorbed')
  call near(cs%pond_mass,s%pond_mass,'no-op pond')

  ! Rain plus irrigation are external; infiltration is internal pond->matrix.
  f%rain_rate_cm_day=0.1_real64
  f%rain_c_mg_cm3=2.0_real64
  f%irrigation_rate_cm_day=0.05_real64
  f%irrigation_c_mg_cm3=4.0_real64
  f%q_face_up_cm_day(1)=-0.2_real64
  before=sum(m%mass_mg_cm2)+s%solute_total()
  call advance_b111_reactive_solute_substep(m,s,f,cm,cs,r)
  call check(r%status==B111_REACTIVE_OK,'pond infiltration substep')
  call check(r%pond_to_soil_mg_cm2>0.0_real64,'pond internal transfer positive')
  call near(r%external_input_mg_cm2,0.4_real64,'rain irrigation input')
  call near(r%external_output_mg_cm2,0.0_real64,'pond case no external output')
  call near(sum(cm%mass_mg_cm2)+cs%solute_total(),before+0.4_real64,'pond whole mass')
  call near(r%balance_residual_mg_cm2,0.0_real64,'pond balance residual')

  ! Source semantics: with temperature active and rate 0.1/day, decay removes
  ! 10% of total matrix storage over this single source substep.
  f%rain_rate_cm_day=0.0_real64;f%rain_c_mg_cm3=0.0_real64
  f%irrigation_rate_cm_day=0.0_real64;f%irrigation_c_mg_cm3=0.0_real64
  f%q_face_up_cm_day=0.0_real64
  f%temperature_active=.true.
  f%decpot=[0.1_real64]
  before=sum(m%mass_mg_cm2)+s%solute_total()
  call advance_b111_reactive_solute_substep(m,s,f,cm,cs,r)
  call check(r%status==B111_REACTIVE_OK,'decay substep')
  call near(r%decay_output_mg_cm2,0.3_real64,'decay output')
  call near(sum(cm%mass_mg_cm2)+cs%solute_total(),before-0.3_real64,'decay whole mass')
  call near(cm%concentration_mg_cm3(1),0.9_real64,'decay repartition concentration')
  call near(cm%mass_mg_cm2(1),1.8_real64,'decay dissolved')
  call near(cs%sorbed_matrix_mass(1),0.9_real64,'decay sorbed')
  call near(r%balance_residual_mg_cm2,0.0_real64,'decay balance residual')

  print '(A)','B111_REACTIVE_SOLUTE_SUBSTEP_PASS'

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
