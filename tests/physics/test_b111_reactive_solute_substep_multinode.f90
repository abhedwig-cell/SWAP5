program test_b111_reactive_solute_substep_multinode
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
  real(real64)::before,node1_before,node2_before,node1_after,node2_after

  call initialize_mobile_salt_state([10.0_real64,10.0_real64],[0.2_real64,0.2_real64], &
       [1.0_real64,2.0_real64],m,status)
  call check(status==SOLUTE_OK,'mobile init')
  call initialize_solute_compartment_state([1.0_real64,2.0_real64],0.0_real64,0.0_real64, &
       [0.0_real64,0.0_real64],s,status)
  call check(status==SOLCOMP_OK,'companion init')

  f%dt_day=0.1_real64
  f%theta=[0.2_real64,0.2_real64]
  f%dz_cm=[10.0_real64,10.0_real64]
  f%q_face_up_cm_day=[0.0_real64,0.0_real64,0.0_real64]
  f%root_sink_cm_day=[0.0_real64,0.0_real64]
  allocate(f%qdra_cm_day(0,2))
  f%cdrain_mg_cm3=0.0_real64
  f%cseep_mg_cm3=0.0_real64
  f%tscf=0.0_real64
  f%pond_end_cm=0.0_real64
  f%face_left_weight=[0.5_real64]
  f%face_right_weight=[0.5_real64]
  f%face_distance_cm=[10.0_real64]
  f%theta_sat_left=[0.4_real64]
  f%dispersivity_cm=[0.0_real64]
  f%molecular_diffusion_cm2_day=0.5_real64
  f%temperature_active=.false.
  f%temperature_c=[20.0_real64,20.0_real64]
  f%gampar=[0.0_real64,0.0_real64]
  f%rtheta=[0.2_real64,0.2_real64]
  f%bexp=[1.0_real64,1.0_real64]
  f%decpot=[0.0_real64,0.0_real64]
  f%fdepth=[1.0_real64,1.0_real64]
  f%bulk_density=[0.1_real64,0.1_real64]
  f%kf=[1.0_real64,1.0_real64]
  f%cref_mg_cm3=1.0_real64
  f%frexp=1.0_real64

  node1_before=m%mass_mg_cm2(1)+s%sorbed_matrix_mass(1)
  node2_before=m%mass_mg_cm2(2)+s%sorbed_matrix_mass(2)
  before=node1_before+node2_before
  call advance_b111_reactive_solute_substep(m,s,f,cm,cs,r)
  call check(r%status==B111_REACTIVE_OK,'multinode reactive substep')
  node1_after=cm%mass_mg_cm2(1)+cs%sorbed_matrix_mass(1)
  node2_after=cm%mass_mg_cm2(2)+cs%sorbed_matrix_mass(2)
  call near(node1_after+node2_after,before,'internal transport conservation')
  call check(node1_after>node1_before,'low concentration node gains mass')
  call check(node2_after<node2_before,'high concentration node loses mass')
  call near(r%external_input_mg_cm2,0.0_real64,'no external input')
  call near(r%external_output_mg_cm2,0.0_real64,'no external output')
  call near(r%balance_residual_mg_cm2,0.0_real64,'multinode balance residual')
  call near(cs%sorbed_matrix_mass(1),0.5_real64*cm%mass_mg_cm2(1),'node1 Freundlich equilibrium')
  call near(cs%sorbed_matrix_mass(2),0.5_real64*cm%mass_mg_cm2(2),'node2 Freundlich equilibrium')

  print '(A)','B111_REACTIVE_SOLUTE_SUBSTEP_MULTINODE_PASS'
contains
  subroutine near(x,y,label)
    real(real64),intent(in)::x,y
    character(len=*),intent(in)::label
    call check(abs(x-y)<=2.0e-11_real64*max(1.0_real64,abs(x),abs(y)),label)
  end subroutine
  subroutine check(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then
      print '(A)',trim(label)//' failed';error stop 1
    end if
  end subroutine
end program
