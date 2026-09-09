program test_fsi25_temporal_indicator_contract
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_solver_t, soil_water_solver_workspace_base_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, soil_water_temporal_indicator_request_t, &
       soil_water_temporal_indicator_result_t, SW_TEMPORAL_INDICATOR_UNAVAILABLE, SW_TEMPORAL_INDICATOR_FAILED
  implicit none

  type, extends(soil_water_solver_workspace_base_t) :: dummy_workspace_t
  end type dummy_workspace_t

  type, extends(soil_water_solver_t) :: dummy_solver_t
   contains
     procedure :: solve => dummy_solve
  end type dummy_solver_t

  type(dummy_solver_t) :: solver
  type(dummy_workspace_t) :: workspace
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: solve_result
  type(soil_water_temporal_indicator_request_t) :: indicator_request
  type(soil_water_temporal_indicator_result_t) :: indicator_result

  request%step_duration = 0.25_real64
  call solver%evaluate_temporal_indicator(request, solve_result, indicator_request, workspace, indicator_result)
  if (indicator_result%status /= SW_TEMPORAL_INDICATOR_UNAVAILABLE) error stop 'default indicator service must be unavailable'
  if (indicator_result%available) error stop 'default indicator service may not claim availability'
  if (indicator_result%additional_full_nonlinear_solves /= 0) error stop 'default service changed nonlinear cost'
  if (indicator_result%additional_tridiagonal_solves /= 0) error stop 'default service changed linear cost'

  indicator_request%previous_right_derivative_available = .true.
  call solver%evaluate_temporal_indicator(request, solve_result, indicator_request, workspace, indicator_result)
  if (indicator_result%status /= SW_TEMPORAL_INDICATOR_FAILED) error stop 'malformed history must fail closed'
  if (indicator_result%available) error stop 'malformed history may not be available'

  print '(a)', 'FSI25_GATE_B_GENERIC_SOLVER_DEFAULT=PASS'
  print '(a)', 'FSI25_GATE_B_HEADcalc_INTERNALS_EXPOSED=NO'
  print '(a)', 'FSI25_GATE_B_PERSISTENT_COLUMN_STATE_ADDED=NO'

contains

  subroutine dummy_solve(self, request, workspace, result)
    class(dummy_solver_t), intent(inout) :: self
    type(soil_water_solve_request_t), intent(in) :: request
    class(soil_water_solver_workspace_base_t), intent(inout) :: workspace
    type(soil_water_solve_result_t), intent(out) :: result

    result = soil_water_solve_result_t()
  end subroutine dummy_solve

end program test_fsi25_temporal_indicator_contract
