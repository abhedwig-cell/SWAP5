module mod_fixed_flux_top_boundary_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: top_boundary_provider_t, soil_water_boundary_conditions_t, &
       soil_water_top_boundary_result_t, SW_TOP_BOUNDARY_AVAILABLE, SW_TOP_BOUNDARY_REGIME_FLUX
  implicit none
  private

  type, extends(top_boundary_provider_t), public :: fixed_flux_top_boundary_provider_t
   contains
     procedure :: evaluate => fixed_flux_top_evaluate
  end type fixed_flux_top_boundary_provider_t

contains

  subroutine fixed_flux_top_evaluate(self, pressure_head_top, water_content_top, candidate_ponding_depth, &
                                     requested, result)
    class(fixed_flux_top_boundary_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head_top, water_content_top, candidate_ponding_depth
    type(soil_water_boundary_conditions_t), intent(in) :: requested
    type(soil_water_top_boundary_result_t), intent(out) :: result

    if (water_content_top < -huge(1.0_real64) .or. self%reserved_marker() /= 0) error stop 'unreachable'
    result = soil_water_top_boundary_result_t()
    result%status = SW_TOP_BOUNDARY_AVAILABLE
    result%regime = SW_TOP_BOUNDARY_REGIME_FLUX
    result%actual_top_flux = requested%top_flux
    result%surface_head = pressure_head_top
    result%candidate_ponding_depth = candidate_ponding_depth
    result%carries_surface_mass_terms = .false.
    result%runoff_resolved = .true.
    result%route = 'fixed-flux'
  end subroutine fixed_flux_top_evaluate

  integer function reserved_marker(self) result(marker)
    class(fixed_flux_top_boundary_provider_t), intent(in) :: self
    marker = 0
  end function reserved_marker

end module mod_fixed_flux_top_boundary_provider
