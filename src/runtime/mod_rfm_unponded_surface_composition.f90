module mod_rfm_unponded_surface_composition
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_top_boundary_result_t, &
       SW_TOP_BOUNDARY_AVAILABLE, SW_TOP_BOUNDARY_REGIME_FLUX
  use mod_rfm_unponded_activation, only: rfm_unponded_activation_result_t, &
       RFM_ACTIVATION_AVAILABLE
  implicit none
  private

  integer, parameter, public :: RFM_SURFACE_COMPOSITION_NOT_RUN = 0
  integer, parameter, public :: RFM_SURFACE_COMPOSITION_AVAILABLE = 1
  integer, parameter, public :: RFM_SURFACE_COMPOSITION_REFERENCE_REQUIRED = 2
  integer, parameter, public :: RFM_SURFACE_COMPOSITION_INVALID = 3

  type, public :: rfm_unponded_surface_composition_result_t
    integer :: status = RFM_SURFACE_COMPOSITION_NOT_RUN
    real(real64) :: effective_supply_cm_per_day = 0.0_real64
    real(real64) :: matrix_supply_cm_per_day = 0.0_real64
    real(real64) :: preferential_supply_cm_per_day = 0.0_real64
    real(real64) :: partition_residual_cm_per_day = 0.0_real64
  end type rfm_unponded_surface_composition_result_t

  public :: compose_rfm_unponded_surface_receipt

contains

  pure subroutine compose_rfm_unponded_surface_receipt(preflight,activation,tolerance,result)
    type(soil_water_top_boundary_result_t), intent(in) :: preflight
    type(rfm_unponded_activation_result_t), intent(in) :: activation
    real(real64), intent(in) :: tolerance
    type(rfm_unponded_surface_composition_result_t), intent(out) :: result
    real(real64) :: supply, matrix_rate, preferential_rate, residual

    result = rfm_unponded_surface_composition_result_t()

    if (.not.ieee_is_finite(tolerance) .or. tolerance < 0.0_real64) then
      result%status = RFM_SURFACE_COMPOSITION_INVALID
      return
    end if

    if (preflight%status /= SW_TOP_BOUNDARY_AVAILABLE) then
      result%status = RFM_SURFACE_COMPOSITION_INVALID
      return
    end if
    if (.not.preflight%carries_surface_mass_terms .or. .not.preflight%runoff_resolved) then
      result%status = RFM_SURFACE_COMPOSITION_INVALID
      return
    end if

    if (preflight%regime /= SW_TOP_BOUNDARY_REGIME_FLUX) then
      result%status = RFM_SURFACE_COMPOSITION_REFERENCE_REQUIRED
      return
    end if
    if (.not.ieee_is_finite(preflight%candidate_ponding_depth) .or. &
        .not.ieee_is_finite(preflight%runoff_depth) .or. &
        .not.ieee_is_finite(preflight%net_potential_surface_flux)) then
      result%status = RFM_SURFACE_COMPOSITION_INVALID
      return
    end if
    if (preflight%candidate_ponding_depth > tolerance .or. preflight%runoff_depth > tolerance) then
      result%status = RFM_SURFACE_COMPOSITION_REFERENCE_REQUIRED
      return
    end if

    supply = preflight%net_potential_surface_flux
    if (supply <= 0.0_real64) then
      result%status = RFM_SURFACE_COMPOSITION_REFERENCE_REQUIRED
      return
    end if

    if (activation%status /= RFM_ACTIVATION_AVAILABLE) then
      result%status = RFM_SURFACE_COMPOSITION_INVALID
      return
    end if
    matrix_rate = activation%matrix_rate_cm_per_day
    preferential_rate = activation%preferential_rate_cm_per_day
    if (.not.ieee_is_finite(matrix_rate) .or. .not.ieee_is_finite(preferential_rate)) then
      result%status = RFM_SURFACE_COMPOSITION_INVALID
      return
    end if
    if (matrix_rate < 0.0_real64 .or. preferential_rate < 0.0_real64) then
      result%status = RFM_SURFACE_COMPOSITION_INVALID
      return
    end if

    residual = supply - matrix_rate - preferential_rate
    if (abs(residual) > tolerance) then
      result%status = RFM_SURFACE_COMPOSITION_INVALID
      return
    end if

    result%effective_supply_cm_per_day = supply
    result%matrix_supply_cm_per_day = matrix_rate
    result%preferential_supply_cm_per_day = preferential_rate
    result%partition_residual_cm_per_day = residual
    result%status = RFM_SURFACE_COMPOSITION_AVAILABLE
  end subroutine compose_rfm_unponded_surface_receipt

end module mod_rfm_unponded_surface_composition
