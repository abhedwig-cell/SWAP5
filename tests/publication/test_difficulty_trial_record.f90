program test_difficulty_trial_record
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_difficulty_trial_record, only: difficulty_trial_record_t, DIFF_METHOD_REFERENCE_NEWTON, &
       DIFF_METHOD_CLASS_ITERATIVE_NONLINEAR, capture_difficulty_pretrial, capture_difficulty_solver_outcome, &
       validate_difficulty_record
  implicit none
  type(soil_water_parameter_set_t), target :: p
  type(soil_water_solve_request_t) :: req
  type(soil_water_solve_result_t) :: res
  type(difficulty_trial_record_t) :: rec
  logical :: ok

  p%parameter_set_id=1_int64; p%active_nodes=2
  allocate(p%z(2),p%dz(2),p%node_distance(2)); p%z=[-1.0_real64,-2.0_real64]; p%dz=1.0_real64; p%node_distance=1.0_real64
  req%parameters=>p; req%base_state%active_nodes=2
  allocate(req%base_state%pressure_head(2),req%base_state%water_content(2))
  req%base_state%pressure_head=[-10.0_real64,-20.0_real64]; req%base_state%water_content=[0.3_real64,0.31_real64]
  req%base_state%groundwater_level=-100.0_real64; req%boundary%top_flux=-0.2_real64; req%step_duration=0.25_real64

  rec%identity%experiment_id='DIF-P0'
  rec%identity%checkpoint_id='cp-001'
  rec%identity%counterfactual_group_id='cfg-001'
  rec%identity%method_id=DIFF_METHOD_REFERENCE_NEWTON
  rec%identity%method_class=DIFF_METHOD_CLASS_ITERATIVE_NONLINEAR
  call capture_difficulty_pretrial(rec,req)

  ! Prove record owns a copy rather than an alias into the request.
  req%base_state%pressure_head(1)=-999.0_real64
  call require(rec%pre%pressure_head(1)==-10.0_real64,'pretrial snapshot is immutable copy')

  res%status=SW_SOLVE_CONVERGED
  res%diagnostics%nonlinear_iterations=4
  res%diagnostics%linear_solves=4
  res%diagnostics%route='legacy-reference-bound'
  res%integrated_mass_balance_residual_available=.true.
  res%integrated_mass_balance_residual_cm=1.0e-12_real64
  call capture_difficulty_solver_outcome(rec,res)
  call validate_difficulty_record(rec,ok)
  call require(ok,'record validates')
  call require(rec%outcome%converged,'convergence captured')
  call require(.not.rec%outcome%reliably_solvable,'convergence cannot imply reliable solvability')
  call require(.not.rec%outcome%residual_trajectory_available,'missing residual trajectory explicit')
  call require(.not.rec%outcome%conditioning_proxy_available,'missing conditioning explicit')
  write(*,'(A)') 'DIFFICULTY_P0B_TRIAL_RECORD=PASS'
contains
  subroutine require(c,label)
    logical,intent(in)::c; character(len=*),intent(in)::label
    if(.not.c) then; write(*,'(A,1X,A)') 'DIFFICULTY_P0B_FAIL',trim(label); error stop 1; end if
  end subroutine
end program test_difficulty_trial_record
