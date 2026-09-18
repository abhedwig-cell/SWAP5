module mod_fmr_pmdirect_swinter0_dynamic_top_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_pmdirect_swetr0_process, only: pmdirect_swetr0_interval_result_t, pmdirect_swetr0_diagnostics_t, &
       PMDIRECT_SWETR0_OK
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t
  implicit none
  private

  integer, parameter, public :: FMR_PMDIRECT_SWINTER0_TOP_OK = 0
  integer, parameter, public :: FMR_PMDIRECT_SWINTER0_TOP_UPSTREAM_REJECTED = 1
  integer, parameter, public :: FMR_PMDIRECT_SWINTER0_TOP_INVALID_NET_RAIN = 2
  integer, parameter, public :: FMR_PMDIRECT_SWINTER0_TOP_INVALID_NET_IRRIGATION = 3

  type, public :: fmr_pmdirect_swinter0_top_diagnostics_t
    integer :: status = FMR_PMDIRECT_SWINTER0_TOP_OK
    integer :: upstream_status = PMDIRECT_SWETR0_OK
    logical :: upstream_result_accepted = .false.
    logical :: incoming_precipitation_ignored = .false.
    logical :: incoming_irrigation_ignored = .false.
    logical :: result_produced = .false.
  end type

  public :: fmr_bind_pmdirect_swinter0_surface_fluxes

contains

  subroutine fmr_bind_pmdirect_swinter0_surface_fluxes(base_request, pmdirect_result, &
      net_surface_irrigation_cm_per_day, pmdirect_diagnostics, bound_request, diagnostics)
    type(b110_dynamic_top_boundary_request_t), intent(in) :: base_request
    type(pmdirect_swetr0_interval_result_t), intent(in) :: pmdirect_result
    real(real64), intent(in) :: net_surface_irrigation_cm_per_day
    type(pmdirect_swetr0_diagnostics_t), intent(in) :: pmdirect_diagnostics
    type(b110_dynamic_top_boundary_request_t), intent(out) :: bound_request
    type(fmr_pmdirect_swinter0_top_diagnostics_t), intent(out) :: diagnostics
    real(real64) :: net_rain

    bound_request = b110_dynamic_top_boundary_request_t()
    diagnostics = fmr_pmdirect_swinter0_top_diagnostics_t()
    diagnostics%upstream_status = pmdirect_diagnostics%status

    if (pmdirect_diagnostics%status /= PMDIRECT_SWETR0_OK .or. &
        .not. pmdirect_diagnostics%interval_result_produced) then
      diagnostics%status = FMR_PMDIRECT_SWINTER0_TOP_UPSTREAM_REJECTED
      return
    end if
    diagnostics%upstream_result_accepted = .true.

    net_rain = pmdirect_result%net_rain_cm_per_day
    if (.not. ieee_is_finite(net_rain) .or. net_rain < 0.0_real64) then
      diagnostics%status = FMR_PMDIRECT_SWINTER0_TOP_INVALID_NET_RAIN
      return
    end if
    if (.not. ieee_is_finite(net_surface_irrigation_cm_per_day) .or. &
        net_surface_irrigation_cm_per_day < 0.0_real64) then
      diagnostics%status = FMR_PMDIRECT_SWINTER0_TOP_INVALID_NET_IRRIGATION
      return
    end if

    bound_request = base_request
    diagnostics%incoming_precipitation_ignored = .true.
    diagnostics%incoming_irrigation_ignored = .true.
    bound_request%precipitation_rate_cm_per_day = net_rain
    bound_request%irrigation_rate_cm_per_day = net_surface_irrigation_cm_per_day
    diagnostics%result_produced = .true.
  end subroutine fmr_bind_pmdirect_swinter0_surface_fluxes
end module mod_fmr_pmdirect_swinter0_dynamic_top_binding
