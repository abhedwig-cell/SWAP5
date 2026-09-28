module mod_ppa_wu04c_dynamic_top_forcing_adapter
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_result_t, &
       B110_DYN_TOP_AVAILABLE, B110_DYN_TOP_REGIME_FLUX
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t
  implicit none
  private

  integer, parameter, public :: PPA_WU04C_TOP_FORCING_OK = 0
  integer, parameter, public :: PPA_WU04C_TOP_FORCING_REJECTED = 1
  public :: bind_ppa_wu04c_dynamic_top_to_effective_forcing

contains

  subroutine bind_ppa_wu04c_dynamic_top_to_effective_forcing(base_forcing, top_result, forcing, status)
    type(fmr_b110_physical_forcing_t), intent(in) :: base_forcing
    type(b110_dynamic_top_boundary_result_t), intent(in) :: top_result
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    integer, intent(out) :: status

    forcing = fmr_b110_physical_forcing_t()
    status = PPA_WU04C_TOP_FORCING_REJECTED
    if (top_result%status /= B110_DYN_TOP_AVAILABLE) return
    if (top_result%regime /= B110_DYN_TOP_REGIME_FLUX) return
    if (.not. ieee_is_finite(top_result%actual_top_flux_cm_per_day)) return
    if (.not. ieee_is_finite(top_result%candidate_ponding_depth_cm)) return
    if (.not. ieee_is_finite(top_result%runoff_depth_cm)) return
    if (top_result%runoff_potential) return
    if (top_result%candidate_ponding_depth_cm /= 0.0_real64) return
    if (top_result%runoff_depth_cm /= 0.0_real64) return
    forcing = base_forcing
    forcing%top_flux = top_result%actual_top_flux_cm_per_day
    status = PPA_WU04C_TOP_FORCING_OK
  end subroutine bind_ppa_wu04c_dynamic_top_to_effective_forcing

end module mod_ppa_wu04c_dynamic_top_forcing_adapter
