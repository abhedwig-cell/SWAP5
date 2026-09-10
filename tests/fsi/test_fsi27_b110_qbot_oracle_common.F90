program test_fsi27_b110_qbot_oracle_common
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_fsi27_b110_oracle_fixture, only: fsi27_oracle_constitutive_t, fsi27_oracle_source_sink_t, &
       fsi27_oracle_root_sink_t, fsi27_oracle_top_t
  implicit none

  integer, parameter :: n = 4
  character(len=128) :: arg
  integer :: stat
  real(real64) :: prescribed_qbot
  type(soil_water_parameter_set_t), target :: parameters
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: result
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  type(fsi27_oracle_constitutive_t), target :: constitutive
  type(fsi27_oracle_source_sink_t), target :: source_sink
  type(fsi27_oracle_root_sink_t), target :: root_sink
  type(fsi27_oracle_top_t), target :: top_boundary

  if (command_argument_count() /= 1) error stop 'F-SI27 common B1.10 oracle requires qbot argument'
  call get_command_argument(1,arg)
  read(arg,*,iostat=stat) prescribed_qbot
  if (stat /= 0) error stop 'F-SI27 common B1.10 oracle bad qbot argument'

  parameters%active_nodes = n
  allocate(parameters%z(n), parameters%dz(n), parameters%node_distance(n))
  parameters%z = [-0.25_real64, -0.75_real64, -1.50_real64, -2.50_real64]
  parameters%dz = [0.50_real64, 0.50_real64, 1.00_real64, 1.00_real64]
  parameters%node_distance = 1.00_real64

  request%parameters => parameters
  request%base_state%active_nodes = n
  allocate(request%base_state%pressure_head(n), request%base_state%water_content(n))
  request%base_state%pressure_head = -75.0_real64
  request%base_state%water_content = 0.30_real64
  request%base_state%ponding_depth = 0.0_real64
  request%base_state%groundwater_level = -2.0_real64

  request%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
  request%boundary%bottom_mode = 2
  request%boundary%top_flux = -1.0_real64
  request%boundary%bottom_flux = prescribed_qbot
  request%boundary%bottom_head = 987654.321_real64
  request%physical%macropore_active = .false.

  request%numerical%max_iterations = 16
  request%numerical%max_backtracking = 8
  request%numerical%conductivity_implicit_mode = 0
  request%numerical%conductivity_mean_method = 1
  request%numerical%min_step_duration = 1.0e-6_real64
  request%numerical%compartment_balance_tolerance = 1.0e-12_real64
  request%numerical%total_balance_tolerance = 1.0e-12_real64
  request%numerical%head_abs_tolerance = 1.0e-12_real64
  request%numerical%head_rel_tolerance = 1.0e-12_real64
  request%numerical%ponding_tolerance = 1.0e-12_real64
  request%step_duration = 0.25_real64

  request%evaluation%constitutive => constitutive
  request%evaluation%source_sink => source_sink
  request%evaluation%root_sink => root_sink
  request%evaluation%top_boundary => top_boundary

  call solver%solve(request, workspace, result)
  if (result%status /= SW_SOLVE_CONVERGED) error stop 'F-SI27 common B1.10 mode2 oracle did not converge'

  write(*,'(A,4(1X,Z16.16))') 'H_BITS', transfer(result%candidate_state%pressure_head(1),0_int64), &
       transfer(result%candidate_state%pressure_head(2),0_int64), transfer(result%candidate_state%pressure_head(3),0_int64), &
       transfer(result%candidate_state%pressure_head(4),0_int64)
  write(*,'(A,4(1X,Z16.16))') 'THETA_BITS', transfer(result%candidate_state%water_content(1),0_int64), &
       transfer(result%candidate_state%water_content(2),0_int64), transfer(result%candidate_state%water_content(3),0_int64), &
       transfer(result%candidate_state%water_content(4),0_int64)
  write(*,'(A,1X,Z16.16)') 'QBOT_BITS', transfer(result%bottom_flux,0_int64)
  write(*,'(A,1X,I0)') 'ITER', result%diagnostics%nonlinear_iterations
end program test_fsi27_b110_qbot_oracle_common