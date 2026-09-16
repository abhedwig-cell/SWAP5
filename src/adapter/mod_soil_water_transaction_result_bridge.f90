module mod_soil_water_transaction_result_bridge
  use mod_soil_water_solver_contract, only: soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_transaction_reference, only: trial_outcome_t, transaction_interface_sensitivity_t
  implicit none
  private

  public :: map_soil_water_interface_sensitivity_to_trial

contains

  subroutine map_soil_water_interface_sensitivity_to_trial(solve_result, trial_outcome)
    type(soil_water_solve_result_t), intent(in) :: solve_result
    type(trial_outcome_t), intent(inout) :: trial_outcome

    ! F-KT14 is a result-transport owner, not a second hydraulic authority.
    ! Always clear the destination first so a retry/failure or an unavailable
    ! producer result can never inherit a tangent from an earlier attempt.
    trial_outcome%interface_sensitivity = transaction_interface_sensitivity_t()

    ! Only a converged solver result may enter the transaction acceptance
    ! machinery as a candidate sensitivity. Retry-advised and failed solves
    ! remain fail-closed even if a malformed caller left source metadata set.
    if (solve_result%status /= SW_SOLVE_CONVERGED) return
    if (.not. solve_result%interface_sensitivity%available) return

    trial_outcome%interface_sensitivity%available = .true.
    trial_outcome%interface_sensitivity%dh_bottom_dq_bottom = &
         solve_result%interface_sensitivity%dh_bottom_dq_bottom
    trial_outcome%interface_sensitivity%method = solve_result%interface_sensitivity%method

    ! Temporal provenance and semantic ownership deliberately stay unset here.
    ! execute_reference_interval owns accepted-route identity and assigns the
    ! exact accepted [origin_t0,origin_t1] only after a route is accepted.
    ! No SWAP-to-MODFLOW sign conversion occurs in this bridge.
  end subroutine map_soil_water_interface_sensitivity_to_trial

end module mod_soil_water_transaction_result_bridge
