module mod_reference_richards_accepted_step_directional_service
  use mod_soil_water_solver_contract, only: soil_water_solver_t, soil_water_solver_workspace_base_t, &
       soil_water_solve_request_t, soil_water_solve_result_t
  use mod_soil_water_accepted_step_direction_contract, only: &
       soil_water_accepted_step_direction_request_t, soil_water_accepted_step_direction_result_t, &
       SW_STEP_DIRECTION_NOT_RUN
  implicit none
  private
  public :: solve_with_accepted_step_direction
contains
  subroutine solve_with_accepted_step_direction(solver, request, workspace, direction_request, &
                                                 solve_result, direction_result)
    class(soil_water_solver_t), intent(inout) :: solver
    type(soil_water_solve_request_t), intent(in) :: request
    class(soil_water_solver_workspace_base_t), intent(inout) :: workspace
    type(soil_water_accepted_step_direction_request_t), intent(in) :: direction_request
    type(soil_water_solve_result_t), intent(out) :: solve_result
    type(soil_water_accepted_step_direction_result_t), intent(out) :: direction_result

    ! D2 never requests accepted-trajectory directional sensitivity. This
    ! test-only module satisfies the current backend's link-time dependency
    ! without importing the unrelated dynamic-top/tangent implementation.
    ! If the D2 route ever starts requesting it, fail loudly rather than
    ! silently changing the experiment.
    if (direction_request%requested) error stop 'PUB-ME D2 unexpected directional-service route'

    call solver%solve(request, workspace, solve_result)
    direction_result = soil_water_accepted_step_direction_result_t()
    direction_result%status = SW_STEP_DIRECTION_NOT_RUN
    direction_result%route = 'pub-me-d2-not-requested'
  end subroutine solve_with_accepted_step_direction
end module mod_reference_richards_accepted_step_directional_service
