module mod_top03_microrelief_top_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: dynamic_top_boundary_provider_t, soil_water_boundary_conditions_t, &
       soil_water_top_boundary_result_t, soil_water_parameter_set_t, SW_TOP_BOUNDARY_AVAILABLE, &
       SW_TOP_BOUNDARY_UNAVAILABLE, SW_TOP_BOUNDARY_REGIME_HEAD
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, evaluate_b110_default_mvg_conductivity
  implicit none
  private

  type, extends(dynamic_top_boundary_provider_t), public :: top03_microrelief_provider_t
    type(soil_water_parameter_set_t), pointer :: geometry => null()
    type(b110_default_mvg_parameters_t), pointer :: hydraulics => null()
    real(real64) :: external_stage_cm = 0.0_real64
    real(real64) :: microrelief_amplitude_cm = 0.0_real64
  contains
    procedure :: evaluate => top03_microrelief_evaluate
    procedure :: wet_fraction => top03_wet_fraction
    procedure :: mean_wet_head => top03_mean_wet_head
    procedure :: surface_storage => top03_surface_storage
  end type top03_microrelief_provider_t

  public :: bind_top03_microrelief_provider

contains

  subroutine bind_top03_microrelief_provider(provider, geometry, hydraulics, external_stage_cm, microrelief_amplitude_cm)
    type(top03_microrelief_provider_t), intent(out) :: provider
    type(soil_water_parameter_set_t), target, intent(in) :: geometry
    type(b110_default_mvg_parameters_t), target, intent(in) :: hydraulics
    real(real64), intent(in) :: external_stage_cm, microrelief_amplitude_cm

    provider%geometry => geometry
    provider%hydraulics => hydraulics
    provider%external_stage_cm = external_stage_cm
    provider%microrelief_amplitude_cm = microrelief_amplitude_cm
  end subroutine bind_top03_microrelief_provider

  subroutine top03_microrelief_evaluate(self, pressure_head_top, water_content_top, candidate_ponding_depth, requested, result)
    class(top03_microrelief_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head_top
    real(real64), intent(in) :: water_content_top
    real(real64), intent(in) :: candidate_ponding_depth
    type(soil_water_boundary_conditions_t), intent(in) :: requested
    type(soil_water_top_boundary_result_t), intent(out) :: result

    real(real64) :: k_top, k_sat, k_face, k_contact, top_distance
    real(real64) :: fwet, hwet, storage
    logical :: ok

    result = soil_water_top_boundary_result_t()
    result%status = SW_TOP_BOUNDARY_UNAVAILABLE
    result%route = 'top03-microrelief-invalid'

    if (.not. associated(self%geometry) .or. .not. associated(self%hydraulics)) return
    if (self%geometry%active_nodes <= 0 .or. .not. allocated(self%geometry%node_distance)) return
    if (size(self%geometry%node_distance) < 1) return
    if (.not. ieee_is_finite(self%external_stage_cm) .or. .not. ieee_is_finite(self%microrelief_amplitude_cm)) return
    if (self%external_stage_cm <= 0.0_real64 .or. self%microrelief_amplitude_cm < 0.0_real64) return
    if (.not. ieee_is_finite(pressure_head_top) .or. .not. ieee_is_finite(water_content_top) .or. &
        .not. ieee_is_finite(candidate_ponding_depth)) return

    top_distance = self%geometry%node_distance(1)
    if (.not. ieee_is_finite(top_distance) .or. top_distance <= 0.0_real64) return

    call evaluate_b110_default_mvg_conductivity(self%hydraulics, 1, pressure_head_top, k_top, ok)
    if (.not. ok) return
    call evaluate_b110_default_mvg_conductivity(self%hydraulics, 1, 0.0_real64, k_sat, ok)
    if (.not. ok) return

    ! Exact fixture policy: SWKMEAN=1, arithmetic mean at the surface face.
    k_face = 0.5_real64 * (k_sat + k_top)
    fwet = self%wet_fraction()
    hwet = self%mean_wet_head()
    storage = self%surface_storage()
    k_contact = fwet * k_face

    if (.not. all(ieee_is_finite([k_face,fwet,hwet,storage,k_contact]))) return
    if (fwet <= 0.0_real64 .or. fwet > 1.0_real64 .or. k_contact <= 0.0_real64) return
    if (storage < 0.0_real64 .or. hwet < 0.0_real64) return

    result%status = SW_TOP_BOUNDARY_AVAILABLE
    result%regime = SW_TOP_BOUNDARY_REGIME_HEAD
    result%surface_head = hwet
    result%surface_face_conductivity = k_contact
    result%candidate_ponding_depth = storage
    result%actual_top_flux = -k_contact * ((hwet-pressure_head_top)/top_distance + 1.0_real64)
    result%bare_soil_evaporation = 0.0_real64
    result%ponded_water_evaporation = 0.0_real64
    result%runoff_depth = 0.0_real64
    result%net_potential_surface_flux = 0.0_real64
    result%surface_head_derivative_available = .true.
    result%surface_head_dpressure_head_top = 0.0_real64
    result%external_surface_head_imposed = .true.
    result%carries_surface_mass_terms = .true.
    result%runoff_potential = .false.
    result%runoff_resolved = .true.
    result%route = 'top03-microrelief-contact'

    if (.not. all(ieee_is_finite([result%actual_top_flux,result%surface_head, &
         result%surface_face_conductivity,result%candidate_ponding_depth]))) then
      result = soil_water_top_boundary_result_t()
      result%status = SW_TOP_BOUNDARY_UNAVAILABLE
      result%route = 'top03-microrelief-nonfinite'
    end if

    ! Keep the interface values semantically consumed in this research provider.
    if (requested%top_mode < 0 .and. water_content_top < 0.0_real64 .and. candidate_ponding_depth < 0.0_real64) then
      result%status = SW_TOP_BOUNDARY_UNAVAILABLE
    end if
  end subroutine top03_microrelief_evaluate

  pure real(real64) function top03_wet_fraction(self) result(value)
    class(top03_microrelief_provider_t), intent(in) :: self
    if (self%microrelief_amplitude_cm <= 0.0_real64) then
      value = 1.0_real64
    else
      value = min(1.0_real64, max(0.0_real64, self%external_stage_cm/self%microrelief_amplitude_cm))
    end if
  end function top03_wet_fraction

  pure real(real64) function top03_mean_wet_head(self) result(value)
    class(top03_microrelief_provider_t), intent(in) :: self
    if (self%microrelief_amplitude_cm <= 0.0_real64) then
      value = self%external_stage_cm
    else if (self%external_stage_cm < self%microrelief_amplitude_cm) then
      value = 0.5_real64*self%external_stage_cm
    else
      value = self%external_stage_cm - 0.5_real64*self%microrelief_amplitude_cm
    end if
  end function top03_mean_wet_head

  pure real(real64) function top03_surface_storage(self) result(value)
    class(top03_microrelief_provider_t), intent(in) :: self
    if (self%microrelief_amplitude_cm <= 0.0_real64) then
      value = self%external_stage_cm
    else if (self%external_stage_cm < self%microrelief_amplitude_cm) then
      value = self%external_stage_cm*self%external_stage_cm/(2.0_real64*self%microrelief_amplitude_cm)
    else
      value = self%external_stage_cm - 0.5_real64*self%microrelief_amplitude_cm
    end if
  end function top03_surface_storage

end module mod_top03_microrelief_top_provider
