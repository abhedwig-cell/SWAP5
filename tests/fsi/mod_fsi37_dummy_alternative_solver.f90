module mod_fsi37_dummy_alternative_solver
  use mod_soil_water_solver_contract, only: soil_water_solver_t, soil_water_solver_workspace_base_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  implicit none
  private

  type, extends(soil_water_solver_workspace_base_t), public :: dummy_alternative_workspace_t
  end type dummy_alternative_workspace_t

  type, extends(soil_water_solver_t), public :: dummy_alternative_solver_t
   contains
     procedure :: solve => dummy_alternative_solve
  end type dummy_alternative_solver_t

contains

  subroutine dummy_alternative_solve(self, request, workspace, result)
    class(dummy_alternative_solver_t), intent(inout) :: self
    type(soil_water_solve_request_t), intent(in) :: request
    class(soil_water_solver_workspace_base_t), intent(inout) :: workspace
    type(soil_water_solve_result_t), intent(out) :: result

    result = soil_water_solve_result_t()
    result%status = SW_SOLVE_CONVERGED
    result%candidate_state = request%base_state
    result%top_flux = request%boundary%top_flux
    result%bottom_flux = request%boundary%bottom_flux
    result%unrounded_mass_balance_residual = 0.0d0
    result%diagnostics%route = 'dummy-alternative'
  end subroutine dummy_alternative_solve

end module mod_fsi37_dummy_alternative_solver
