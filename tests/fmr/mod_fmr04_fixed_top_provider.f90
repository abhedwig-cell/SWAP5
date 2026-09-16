module mod_fmr04_fixed_top_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: top_boundary_provider_t, soil_water_boundary_conditions_t
  implicit none
  private

  type, extends(top_boundary_provider_t), public :: fmr04_fixed_flux_top_provider_t
  contains
    procedure :: evaluate => fmr04_top_evaluate
  end type fmr04_fixed_flux_top_provider_t

contains

  subroutine fmr04_top_evaluate(self, pressure_head_top, water_content_top, requested, &
                                actual_top_flux, surface_head, runoff_flux)
    class(fmr04_fixed_flux_top_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head_top, water_content_top
    type(soil_water_boundary_conditions_t), intent(in) :: requested
    real(real64), intent(out) :: actual_top_flux, surface_head, runoff_flux
    if (.not. same_type_as(self,self) .or. water_content_top < -huge(water_content_top)) &
      error stop 'F-MR04 invalid top provider state'
    actual_top_flux = requested%top_flux
    surface_head = pressure_head_top
    runoff_flux = 0.0_real64
  end subroutine fmr04_top_evaluate

end module mod_fmr04_fixed_top_provider
