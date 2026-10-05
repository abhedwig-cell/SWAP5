module mod_fmr_irrigation_forcing_composition
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_irrigation_process, only: irrigation_flux_result_t, irrigation_diagnostics_t, &
       IRRIGATION_OK, IRRIGATION_APPLICATION_SPRINKLER, IRRIGATION_APPLICATION_SURFACE, IRRIGATION_APPLICATION_SSDI
  use mod_rutter_interception_process, only: rutter_interval_input_t
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t
  use mod_fmr_hupsel_irrigation_application_binding, only: fmr_bind_fixed_surface_irrigation_identity_to_dynamic_top, &
       fmr_bind_sprinkling_flux_to_rutter, fmr_hupsel_irrigation_binding_diagnostics_t, FMR_HUPSEL_IRR_BIND_OK
  use mod_fmr_irrigation_source_binding, only: fmr_bind_irrigation_to_subsurface_source, &
       fmr_irrigation_source_diagnostics_t, FMR_IRR_SOURCE_OK
  implicit none
  private
  integer, parameter, public :: FMR_IRR_COMPOSE_OK = 0
  integer, parameter, public :: FMR_IRR_COMPOSE_INVALID = 1
  integer, parameter, public :: FMR_IRR_COMPOSE_NONE = 0
  integer, parameter, public :: FMR_IRR_COMPOSE_RUTTER = 1
  integer, parameter, public :: FMR_IRR_COMPOSE_TOP = 2
  integer, parameter, public :: FMR_IRR_COMPOSE_SUBSURFACE = 3
  public :: fmr_compose_irrigation_forcing
contains
  subroutine fmr_compose_irrigation_forcing(base_top,base_rutter,base_source,flux,upstream, &
       top_candidate,rutter_candidate,source_candidate,route,status)
    type(b110_dynamic_top_boundary_request_t), intent(in) :: base_top
    type(rutter_interval_input_t), intent(in) :: base_rutter
    real(real64), intent(in) :: base_source(:)
    type(irrigation_flux_result_t), intent(in) :: flux
    type(irrigation_diagnostics_t), intent(in) :: upstream
    type(b110_dynamic_top_boundary_request_t), intent(out) :: top_candidate
    type(rutter_interval_input_t), intent(out) :: rutter_candidate
    real(real64), allocatable, intent(out) :: source_candidate(:)
    integer, intent(out) :: route,status
    type(fmr_hupsel_irrigation_binding_diagnostics_t) :: top_diagnostics
    type(fmr_irrigation_source_diagnostics_t) :: source_diagnostics
    real(real64) :: rate_sum

    top_candidate = b110_dynamic_top_boundary_request_t()
    rutter_candidate = rutter_interval_input_t()
    route = FMR_IRR_COMPOSE_NONE
    status = FMR_IRR_COMPOSE_INVALID
    if (upstream%status /= IRRIGATION_OK) return
    if (any(.not. ieee_is_finite(base_source))) return
    if (.not. ieee_is_finite(base_top%irrigation_rate_cm_per_day) .or. &
        .not. ieee_is_finite(base_rutter%surface_irrigation_cm_per_day)) return
    if (base_top%irrigation_rate_cm_per_day < 0.0_real64 .or. &
        base_rutter%surface_irrigation_cm_per_day < 0.0_real64) return
    if (.not. flux%applied) then
      top_candidate = base_top
      rutter_candidate = base_rutter
      source_candidate = base_source
      status = FMR_IRR_COMPOSE_OK
      return
    end if
    if (.not. ieee_is_finite(flux%active_duration) .or. &
        .not. ieee_is_finite(flux%external_inflow_amount)) return
    if (flux%active_duration <= 0.0_real64 .or. flux%external_inflow_amount < 0.0_real64) return
    if (base_top%irrigation_rate_cm_per_day > 0.0_real64 .or. &
        base_rutter%surface_irrigation_cm_per_day > 0.0_real64) return
    select case(flux%application_type)
    case(IRRIGATION_APPLICATION_SPRINKLER,IRRIGATION_APPLICATION_SURFACE)
      if (.not. ieee_is_finite(flux%surface_gross_rate)) return
      rate_sum = flux%surface_gross_rate
    case(IRRIGATION_APPLICATION_SSDI)
      if (.not. allocated(flux%subsurface_source)) return
      if (any(.not. ieee_is_finite(flux%subsurface_source))) return
      rate_sum = sum(flux%subsurface_source)
    case default
      return
    end select
    if (abs(flux%external_inflow_amount-rate_sum*flux%active_duration) > &
        1.e-12_real64*max(1.0_real64,flux%external_inflow_amount)) return

    select case(flux%application_type)
    case(IRRIGATION_APPLICATION_SPRINKLER)
      call fmr_bind_sprinkling_flux_to_rutter(base_rutter,flux,upstream,rutter_candidate,top_diagnostics)
      if (top_diagnostics%status /= FMR_HUPSEL_IRR_BIND_OK) return
      top_candidate = base_top
      source_candidate = base_source
      route = FMR_IRR_COMPOSE_RUTTER
    case(IRRIGATION_APPLICATION_SURFACE)
      call fmr_bind_fixed_surface_irrigation_identity_to_dynamic_top(base_top,flux,upstream, &
           top_candidate,top_diagnostics)
      if (top_diagnostics%status /= FMR_HUPSEL_IRR_BIND_OK) return
      rutter_candidate = base_rutter
      source_candidate = base_source
      route = FMR_IRR_COMPOSE_TOP
    case(IRRIGATION_APPLICATION_SSDI)
      call fmr_bind_irrigation_to_subsurface_source(base_source,flux,upstream,source_candidate,source_diagnostics)
      if (source_diagnostics%status /= FMR_IRR_SOURCE_OK) return
      top_candidate = base_top
      rutter_candidate = base_rutter
      route = FMR_IRR_COMPOSE_SUBSURFACE
    end select
    status = FMR_IRR_COMPOSE_OK
  end subroutine
end module
