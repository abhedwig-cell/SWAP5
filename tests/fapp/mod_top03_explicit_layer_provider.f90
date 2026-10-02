! Research only: preserve physical surface elevation when eliminating a layer.
module mod_top03_explicit_layer_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_top03_microrelief_top_provider, only: top03_microrelief_provider_t
  use mod_soil_water_solver_contract, only: soil_water_boundary_conditions_t, soil_water_top_boundary_result_t, &
       SW_TOP_BOUNDARY_AVAILABLE
  implicit none
  type, extends(top03_microrelief_provider_t) :: top03_layer_contact_provider_t
    real(real64) :: eliminated_layer_thickness_cm = 0.0_real64
  contains
    procedure :: evaluate => evaluate_layer_contact
  end type
contains
  subroutine evaluate_layer_contact(self, pressure_head_top, water_content_top, candidate_ponding_depth, requested, result)
    class(top03_layer_contact_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head_top, water_content_top, candidate_ponding_depth
    type(soil_water_boundary_conditions_t), intent(in) :: requested
    type(soil_water_top_boundary_result_t), intent(out) :: result
    call self%top03_microrelief_provider_t%evaluate(pressure_head_top,water_content_top,candidate_ponding_depth,requested,result)
    if (result%status /= SW_TOP_BOUNDARY_AVAILABLE) return
    result%surface_head=result%surface_head+self%eliminated_layer_thickness_cm
    result%actual_top_flux=-result%surface_face_conductivity * &
         ((result%surface_head-pressure_head_top)/self%geometry%node_distance(1)+1.0_real64)
    ! The physical pond is above the original layer top. Do not add L to pond storage.
    result%route='top03-layer-contact-research'
  end subroutine
end module
