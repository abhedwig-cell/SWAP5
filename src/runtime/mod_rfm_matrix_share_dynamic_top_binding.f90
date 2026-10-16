module mod_rfm_matrix_share_dynamic_top_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t, &
       b110_dynamic_top_boundary_result_t, B110_DYN_TOP_AVAILABLE, B110_DYN_TOP_REGIME_FLUX
  use mod_rfm_unponded_surface_composition, only: rfm_unponded_surface_composition_result_t, &
       RFM_SURFACE_COMPOSITION_AVAILABLE
  implicit none
  private

  integer, parameter, public :: RFM_MATRIX_REBIND_NOT_RUN = 0
  integer, parameter, public :: RFM_MATRIX_REBIND_AVAILABLE = 1
  integer, parameter, public :: RFM_MATRIX_REBIND_REFERENCE_REQUIRED = 2
  integer, parameter, public :: RFM_MATRIX_REBIND_INVALID = 3

  type, public :: rfm_matrix_rebind_diagnostics_t
    integer :: status = RFM_MATRIX_REBIND_NOT_RUN
    logical :: request_produced = .false.
    logical :: rebound_verified = .false.
  end type rfm_matrix_rebind_diagnostics_t

  public :: build_rfm_matrix_share_dynamic_top_request
  public :: verify_rfm_matrix_share_dynamic_top_result

contains

  pure subroutine build_rfm_matrix_share_dynamic_top_request(base_request,receipt,tolerance, &
       rebound_request,diagnostics)
    type(b110_dynamic_top_boundary_request_t), intent(in) :: base_request
    type(rfm_unponded_surface_composition_result_t), intent(in) :: receipt
    real(real64), intent(in) :: tolerance
    type(b110_dynamic_top_boundary_request_t), intent(out) :: rebound_request
    type(rfm_matrix_rebind_diagnostics_t), intent(out) :: diagnostics

    rebound_request = b110_dynamic_top_boundary_request_t()
    diagnostics = rfm_matrix_rebind_diagnostics_t()

    if (.not.ieee_is_finite(tolerance) .or. tolerance < 0.0_real64) then
      diagnostics%status = RFM_MATRIX_REBIND_INVALID
      return
    end if
    if (receipt%status /= RFM_SURFACE_COMPOSITION_AVAILABLE) then
      diagnostics%status = RFM_MATRIX_REBIND_INVALID
      return
    end if
    if (.not.ieee_is_finite(receipt%matrix_supply_cm_per_day) .or. &
        receipt%matrix_supply_cm_per_day < 0.0_real64) then
      diagnostics%status = RFM_MATRIX_REBIND_INVALID
      return
    end if
    if (.not.ieee_is_finite(base_request%previous_ponding_depth_cm) .or. &
        .not.ieee_is_finite(base_request%candidate_ponding_depth_cm)) then
      diagnostics%status = RFM_MATRIX_REBIND_INVALID
      return
    end if
    if (base_request%previous_ponding_depth_cm > tolerance .or. &
        base_request%candidate_ponding_depth_cm > tolerance) then
      diagnostics%status = RFM_MATRIX_REBIND_REFERENCE_REQUIRED
      return
    end if

    rebound_request = base_request
    rebound_request%previous_ponding_depth_cm = 0.0_real64
    rebound_request%candidate_ponding_depth_cm = 0.0_real64

    rebound_request%precipitation_rate_cm_per_day = receipt%matrix_supply_cm_per_day
    rebound_request%irrigation_rate_cm_per_day = 0.0_real64
    rebound_request%snowmelt_rate_cm_per_day = 0.0_real64
    rebound_request%runon_rate_cm_per_day = 0.0_real64

    rebound_request%potential_bare_soil_evaporation_cm_per_day = 0.0_real64
    rebound_request%potential_pond_evaporation_cm_per_day = 0.0_real64

    diagnostics%request_produced = .true.
    diagnostics%status = RFM_MATRIX_REBIND_AVAILABLE
  end subroutine build_rfm_matrix_share_dynamic_top_request

  pure subroutine verify_rfm_matrix_share_dynamic_top_result(receipt,rebound_result,tolerance,diagnostics)
    type(rfm_unponded_surface_composition_result_t), intent(in) :: receipt
    type(b110_dynamic_top_boundary_result_t), intent(in) :: rebound_result
    real(real64), intent(in) :: tolerance
    type(rfm_matrix_rebind_diagnostics_t), intent(out) :: diagnostics

    diagnostics = rfm_matrix_rebind_diagnostics_t()

    if (.not.ieee_is_finite(tolerance) .or. tolerance < 0.0_real64) then
      diagnostics%status = RFM_MATRIX_REBIND_INVALID
      return
    end if
    if (receipt%status /= RFM_SURFACE_COMPOSITION_AVAILABLE) then
      diagnostics%status = RFM_MATRIX_REBIND_INVALID
      return
    end if
    if (rebound_result%status /= B110_DYN_TOP_AVAILABLE) then
      diagnostics%status = RFM_MATRIX_REBIND_REFERENCE_REQUIRED
      return
    end if
    if (rebound_result%regime /= B110_DYN_TOP_REGIME_FLUX) then
      diagnostics%status = RFM_MATRIX_REBIND_REFERENCE_REQUIRED
      return
    end if
    if (.not.ieee_is_finite(rebound_result%candidate_ponding_depth_cm) .or. &
        .not.ieee_is_finite(rebound_result%runoff_depth_cm) .or. &
        .not.ieee_is_finite(rebound_result%net_potential_surface_flux_cm_per_day)) then
      diagnostics%status = RFM_MATRIX_REBIND_INVALID
      return
    end if
    if (rebound_result%candidate_ponding_depth_cm > tolerance .or. &
        rebound_result%runoff_depth_cm > tolerance) then
      diagnostics%status = RFM_MATRIX_REBIND_REFERENCE_REQUIRED
      return
    end if
    if (abs(rebound_result%net_potential_surface_flux_cm_per_day- &
        receipt%matrix_supply_cm_per_day) > tolerance) then
      diagnostics%status = RFM_MATRIX_REBIND_INVALID
      return
    end if

    diagnostics%rebound_verified = .true.
    diagnostics%status = RFM_MATRIX_REBIND_AVAILABLE
  end subroutine verify_rfm_matrix_share_dynamic_top_result

end module mod_rfm_matrix_share_dynamic_top_binding
