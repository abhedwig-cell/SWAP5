module mod_b110_dynamic_top_boundary_solver_adapter
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: top_boundary_provider_t, soil_water_boundary_conditions_t, &
       soil_water_top_boundary_result_t, soil_water_parameter_set_t, &
       SW_TOP_BOUNDARY_AVAILABLE, SW_TOP_BOUNDARY_UNAVAILABLE, &
       SW_TOP_BOUNDARY_REGIME_FLUX, SW_TOP_BOUNDARY_REGIME_HEAD
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t, &
       b110_dynamic_top_boundary_result_t, evaluate_b110_dynamic_top_boundary, &
       B110_DYN_TOP_AVAILABLE, B110_DYN_TOP_REGIME_FLUX, B110_DYN_TOP_REGIME_HEAD
  implicit none
  private

  type, extends(top_boundary_provider_t), public :: b110_dynamic_top_boundary_solver_provider_t
     type(soil_water_parameter_set_t), pointer :: geometry => null()
     type(b110_default_mvg_parameters_t), pointer :: hydraulics => null()
     integer :: conductivity_mean_method = 0
     real(real64) :: previous_ponding_depth = 0.0_real64
     real(real64) :: step_duration = 0.0_real64
     real(real64) :: precipitation_rate = 0.0_real64
     real(real64) :: irrigation_rate = 0.0_real64
     real(real64) :: snowmelt_rate = 0.0_real64
     real(real64) :: runon_rate = 0.0_real64
     real(real64) :: potential_bare_soil_evaporation = 0.0_real64
     real(real64) :: potential_pond_evaporation = 0.0_real64
     real(real64) :: ponding_max = 0.0_real64
     real(real64) :: runoff_resistance = 0.0_real64
     real(real64) :: runoff_exponent = 1.0_real64
   contains
     procedure :: evaluate => b110_dynamic_solver_top_evaluate
  end type b110_dynamic_top_boundary_solver_provider_t

  public :: bind_b110_dynamic_top_boundary_solver_provider

contains

  subroutine bind_b110_dynamic_top_boundary_solver_provider(provider, geometry, hydraulics, &
       conductivity_mean_method, previous_ponding_depth, step_duration, &
       precipitation_rate, irrigation_rate, snowmelt_rate, runon_rate, &
       potential_bare_soil_evaporation, potential_pond_evaporation, &
       ponding_max, runoff_resistance, runoff_exponent)
    type(b110_dynamic_top_boundary_solver_provider_t), intent(out) :: provider
    type(soil_water_parameter_set_t), target, intent(in) :: geometry
    type(b110_default_mvg_parameters_t), target, intent(in) :: hydraulics
    integer, intent(in) :: conductivity_mean_method
    real(real64), intent(in) :: previous_ponding_depth, step_duration
    real(real64), intent(in) :: precipitation_rate, irrigation_rate, snowmelt_rate, runon_rate
    real(real64), intent(in) :: potential_bare_soil_evaporation, potential_pond_evaporation
    real(real64), intent(in) :: ponding_max, runoff_resistance, runoff_exponent

    provider%geometry => geometry
    provider%hydraulics => hydraulics
    provider%conductivity_mean_method = conductivity_mean_method
    provider%previous_ponding_depth = previous_ponding_depth
    provider%step_duration = step_duration
    provider%precipitation_rate = precipitation_rate
    provider%irrigation_rate = irrigation_rate
    provider%snowmelt_rate = snowmelt_rate
    provider%runon_rate = runon_rate
    provider%potential_bare_soil_evaporation = potential_bare_soil_evaporation
    provider%potential_pond_evaporation = potential_pond_evaporation
    provider%ponding_max = ponding_max
    provider%runoff_resistance = runoff_resistance
    provider%runoff_exponent = runoff_exponent
  end subroutine bind_b110_dynamic_top_boundary_solver_provider

  subroutine b110_dynamic_solver_top_evaluate(self, pressure_head_top, water_content_top, &
       candidate_ponding_depth, requested, result)
    class(b110_dynamic_top_boundary_solver_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head_top, water_content_top, candidate_ponding_depth
    type(soil_water_boundary_conditions_t), intent(in) :: requested
    type(soil_water_top_boundary_result_t), intent(out) :: result
    type(b110_dynamic_top_boundary_request_t) :: b110_request
    type(b110_dynamic_top_boundary_result_t) :: b110_result

    result = soil_water_top_boundary_result_t()
    if (.not. associated(self%geometry) .or. .not. associated(self%hydraulics)) then
       result%status = SW_TOP_BOUNDARY_UNAVAILABLE
       result%route = 'b110-dynamic-unbound'
       return
    end if

    b110_request%conductivity_mean_method = self%conductivity_mean_method
    b110_request%pressure_head_top_cm = pressure_head_top
    b110_request%water_content_top = water_content_top
    b110_request%candidate_ponding_depth_cm = candidate_ponding_depth
    b110_request%previous_ponding_depth_cm = self%previous_ponding_depth
    b110_request%step_duration_day = self%step_duration
    b110_request%precipitation_rate_cm_per_day = self%precipitation_rate
    b110_request%irrigation_rate_cm_per_day = self%irrigation_rate
    b110_request%snowmelt_rate_cm_per_day = self%snowmelt_rate
    b110_request%runon_rate_cm_per_day = self%runon_rate
    b110_request%potential_bare_soil_evaporation_cm_per_day = self%potential_bare_soil_evaporation
    b110_request%potential_pond_evaporation_cm_per_day = self%potential_pond_evaporation
    b110_request%ponding_max_cm = self%ponding_max
    b110_request%runoff_resistance_day = self%runoff_resistance
    b110_request%runoff_exponent = self%runoff_exponent

    call evaluate_b110_dynamic_top_boundary(self%geometry, self%hydraulics, b110_request, b110_result)
    if (b110_result%status /= B110_DYN_TOP_AVAILABLE) then
       result%status = SW_TOP_BOUNDARY_UNAVAILABLE
       result%route = b110_result%route
       return
    end if

    result%status = SW_TOP_BOUNDARY_AVAILABLE
    select case (b110_result%regime)
    case (B110_DYN_TOP_REGIME_FLUX)
       result%regime = SW_TOP_BOUNDARY_REGIME_FLUX
    case (B110_DYN_TOP_REGIME_HEAD)
       result%regime = SW_TOP_BOUNDARY_REGIME_HEAD
    case default
       result%status = SW_TOP_BOUNDARY_UNAVAILABLE
       result%route = 'b110-dynamic-regime-invalid'
       return
    end select
    result%actual_top_flux = b110_result%actual_top_flux_cm_per_day
    result%surface_head = b110_result%surface_head_cm
    result%surface_face_conductivity = b110_result%surface_face_conductivity_cm_per_day
    result%candidate_ponding_depth = b110_result%candidate_ponding_depth_cm
    result%bare_soil_evaporation = b110_result%bare_soil_evaporation_cm_per_day
    result%ponded_water_evaporation = b110_result%ponded_water_evaporation_cm_per_day
    result%runoff_depth = b110_result%runoff_depth_cm
    result%net_potential_surface_flux = b110_result%net_potential_surface_flux_cm_per_day
    result%carries_surface_mass_terms = .true.
    result%runoff_resolved = .true.
    result%route = b110_result%route

    ! requested remains part of the generic provider ABI.  The qualified F-SI29
    ! profile obtains its forcing from this request-local adapter context instead
    ! of treating requested%top_flux as an immutable replacement for BoundTop.
    if (requested%top_mode == huge(requested%top_mode)) result%status = SW_TOP_BOUNDARY_UNAVAILABLE
  end subroutine b110_dynamic_solver_top_evaluate

end module mod_b110_dynamic_top_boundary_solver_adapter
