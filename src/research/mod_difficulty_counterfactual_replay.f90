module mod_difficulty_counterfactual_replay
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_solver_t, soil_water_solver_workspace_base_t, &
       soil_water_solve_request_t, soil_water_solve_result_t
  use mod_difficulty_trial_record, only: difficulty_trial_record_t, capture_difficulty_pretrial, &
       capture_difficulty_solver_outcome
  implicit none
  private
  public :: difficulty_replay_one

contains

  subroutine difficulty_replay_one(solver, workspace, request, identity_template, record, result)
    class(soil_water_solver_t), intent(inout) :: solver
    class(soil_water_solver_workspace_base_t), intent(inout) :: workspace
    type(soil_water_solve_request_t), intent(in) :: request
    type(difficulty_trial_record_t), intent(in) :: identity_template
    type(difficulty_trial_record_t), intent(out) :: record
    type(soil_water_solve_result_t), intent(out) :: result

    ! request is intent(in): the replay seam cannot publish a candidate back
    ! into the source checkpoint/request. Each branch receives the same value
    ! state and only its solver-owned workspace is mutable.
    record = identity_template
    call capture_difficulty_pretrial(record, request)
    call solver%solve(request, workspace, result)
    call capture_difficulty_solver_outcome(record, result)
  end subroutine difficulty_replay_one

end module mod_difficulty_counterfactual_replay
