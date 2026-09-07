module mod_fsi07_top_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: top_boundary_provider_t, soil_water_boundary_conditions_t
  implicit none
  private

  type, extends(top_boundary_provider_t), public :: fsi07_flux_top_provider_t
     real(real64) :: fixed_flux = -1.0_real64
     logical :: surface_tracks_head = .false.
   contains
     procedure :: evaluate => fsi07_top_evaluate
  end type fsi07_flux_top_provider_t

contains

  subroutine fsi07_top_evaluate(self, pressure_head_top, water_content_top, requested, &
                                actual_top_flux, surface_head, runoff_flux)
    class(fsi07_flux_top_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head_top
    real(real64), intent(in) :: water_content_top
    type(soil_water_boundary_conditions_t), intent(in) :: requested
    real(real64), intent(out) :: actual_top_flux, surface_head, runoff_flux

    if (water_content_top < -huge(water_content_top)) error stop 'invalid F-SI07 top-provider water content'
    if (requested%top_mode == huge(requested%top_mode)) error stop 'invalid F-SI07 top-provider mode'
    actual_top_flux = self%fixed_flux
    if (self%surface_tracks_head) then
       surface_head = pressure_head_top
    else
       surface_head = 0.0_real64
    end if
    runoff_flux = 0.0_real64
  end subroutine fsi07_top_evaluate

end module mod_fsi07_top_provider
