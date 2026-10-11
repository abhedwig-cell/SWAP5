module mod_fmr_pmdirect_dynamic_top_boundary_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_pmdirect_swetr0_process, only: pmdirect_swetr0_interval_result_t, pmdirect_swetr0_diagnostics_t, &
       PMDIRECT_SWETR0_OK
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t
  implicit none
  private

  integer, parameter, public :: FMR_PMDIRECT_TOP_PRECIP_BINDING_OK = 0
  integer, parameter, public :: FMR_PMDIRECT_TOP_PRECIP_UPSTREAM_REJECTED = 1
  integer, parameter, public :: FMR_PMDIRECT_TOP_PRECIP_INVALID_NET_RAIN = 2

  type, public :: fmr_pmdirect_top_precip_binding_diagnostics_t
    integer :: status = FMR_PMDIRECT_TOP_PRECIP_BINDING_OK
    integer :: upstream_status = PMDIRECT_SWETR0_OK
    logical :: upstream_result_accepted = .false.
    logical :: incoming_precipitation_ignored = .false.
    logical :: precipitation_bound = .false.
    logical :: result_produced = .false.
  end type fmr_pmdirect_top_precip_binding_diagnostics_t

  public :: fmr_bind_pmdirect_net_rain_to_dynamic_top_request

contains

  subroutine fmr_bind_pmdirect_net_rain_to_dynamic_top_request(base_request, pmdirect_result, &
                                                               pmdirect_diagnostics, bound_request, diagnostics)
    type(b110_dynamic_top_boundary_request_t), intent(in) :: base_request
    type(pmdirect_swetr0_interval_result_t), intent(in) :: pmdirect_result
    type(pmdirect_swetr0_diagnostics_t), intent(in) :: pmdirect_diagnostics
    type(b110_dynamic_top_boundary_request_t), intent(out) :: bound_request
    type(fmr_pmdirect_top_precip_binding_diagnostics_t), intent(out) :: diagnostics

    real(real64) :: net_rain

    bound_request = b110_dynamic_top_boundary_request_t()
    diagnostics = fmr_pmdirect_top_precip_binding_diagnostics_t()
    diagnostics%upstream_status = pmdirect_diagnostics%status

    if (pmdirect_diagnostics%status /= PMDIRECT_SWETR0_OK .or. &
        .not. pmdirect_diagnostics%interval_result_produced) then
      diagnostics%status = FMR_PMDIRECT_TOP_PRECIP_UPSTREAM_REJECTED
      return
    end if
    diagnostics%upstream_result_accepted = .true.

    net_rain = pmdirect_result%net_rain_cm_per_day
    if (.not. ieee_is_finite(net_rain)) then
      diagnostics%status = FMR_PMDIRECT_TOP_PRECIP_INVALID_NET_RAIN
      return
    end if
    if (net_rain < 0.0_real64) then
      diagnostics%status = FMR_PMDIRECT_TOP_PRECIP_INVALID_NET_RAIN
      return
    end if

    bound_request = base_request
    diagnostics%incoming_precipitation_ignored = .true.
    bound_request%precipitation_rate_cm_per_day = net_rain
    diagnostics%precipitation_bound = .true.
    diagnostics%result_produced = .true.
  end subroutine fmr_bind_pmdirect_net_rain_to_dynamic_top_request

end module mod_fmr_pmdirect_dynamic_top_boundary_binding
