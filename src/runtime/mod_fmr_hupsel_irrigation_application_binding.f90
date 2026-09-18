module mod_fmr_hupsel_irrigation_application_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_irrigation_process, only: irrigation_flux_result_t, irrigation_diagnostics_t, IRRIGATION_OK, &
       IRRIGATION_APPLICATION_SPRINKLER, IRRIGATION_APPLICATION_SURFACE
  use mod_tcs1_dcs2_sprinkling_irrigation_process, only: tcs1_dcs2_sprinkling_result_t, &
       tcs1_dcs2_sprinkling_diagnostics_t, TCS1_DCS2_OK
  use mod_rutter_interception_process, only: rutter_interval_input_t, rutter_interval_result_t, &
       rutter_diagnostics_t, RUTTER_OK
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t
  implicit none
  private

  integer, parameter, public :: FMR_HUPSEL_IRR_BIND_OK = 0
  integer, parameter, public :: FMR_HUPSEL_IRR_BIND_UPSTREAM_REJECTED = 1
  integer, parameter, public :: FMR_HUPSEL_IRR_BIND_INACTIVE = 2
  integer, parameter, public :: FMR_HUPSEL_IRR_BIND_UNSUPPORTED_APPLICATION = 3
  integer, parameter, public :: FMR_HUPSEL_IRR_BIND_INVALID_RATE = 4

  type, public :: fmr_hupsel_irrigation_binding_diagnostics_t
    integer :: status = FMR_HUPSEL_IRR_BIND_OK
    logical :: upstream_accepted = .false.
    logical :: gross_irrigation_bound = .false.
    logical :: rutter_interception_enabled = .false.
    logical :: net_irrigation_bound = .false.
    logical :: result_produced = .false.
  end type fmr_hupsel_irrigation_binding_diagnostics_t

  public :: fmr_bind_fixed_surface_irrigation_identity_to_dynamic_top
  public :: fmr_bind_tcs1_sprinkling_to_rutter
  public :: fmr_bind_rutter_net_irrigation_to_dynamic_top

contains

  subroutine fmr_bind_fixed_surface_irrigation_identity_to_dynamic_top(base_request, flux, upstream, &
                                                                        bound_request, diagnostics)
    type(b110_dynamic_top_boundary_request_t), intent(in) :: base_request
    type(irrigation_flux_result_t), intent(in) :: flux
    type(irrigation_diagnostics_t), intent(in) :: upstream
    type(b110_dynamic_top_boundary_request_t), intent(out) :: bound_request
    type(fmr_hupsel_irrigation_binding_diagnostics_t), intent(out) :: diagnostics

    bound_request = b110_dynamic_top_boundary_request_t()
    diagnostics = fmr_hupsel_irrigation_binding_diagnostics_t()

    if (upstream%status /= IRRIGATION_OK) then
      diagnostics%status = FMR_HUPSEL_IRR_BIND_UPSTREAM_REJECTED
      return
    end if
    diagnostics%upstream_accepted = .true.
    if (.not. flux%applied) then
      diagnostics%status = FMR_HUPSEL_IRR_BIND_INACTIVE
      return
    end if
    if (flux%application_type /= IRRIGATION_APPLICATION_SPRINKLER .and. &
        flux%application_type /= IRRIGATION_APPLICATION_SURFACE) then
      diagnostics%status = FMR_HUPSEL_IRR_BIND_UNSUPPORTED_APPLICATION
      return
    end if
    if (.not. valid_nonnegative_rate(flux%surface_gross_rate)) then
      diagnostics%status = FMR_HUPSEL_IRR_BIND_INVALID_RATE
      return
    end if

    bound_request = base_request
    bound_request%irrigation_rate_cm_per_day = flux%surface_gross_rate
    diagnostics%gross_irrigation_bound = .true.
    diagnostics%net_irrigation_bound = .true.
    diagnostics%result_produced = .true.
  end subroutine fmr_bind_fixed_surface_irrigation_identity_to_dynamic_top

  subroutine fmr_bind_tcs1_sprinkling_to_rutter(base_input, scheduled, upstream, bound_input, diagnostics)
    type(rutter_interval_input_t), intent(in) :: base_input
    type(tcs1_dcs2_sprinkling_result_t), intent(in) :: scheduled
    type(tcs1_dcs2_sprinkling_diagnostics_t), intent(in) :: upstream
    type(rutter_interval_input_t), intent(out) :: bound_input
    type(fmr_hupsel_irrigation_binding_diagnostics_t), intent(out) :: diagnostics

    bound_input = rutter_interval_input_t()
    diagnostics = fmr_hupsel_irrigation_binding_diagnostics_t()

    if (upstream%status /= TCS1_DCS2_OK) then
      diagnostics%status = FMR_HUPSEL_IRR_BIND_UPSTREAM_REJECTED
      return
    end if
    diagnostics%upstream_accepted = .true.
    if (.not. scheduled%applied) then
      diagnostics%status = FMR_HUPSEL_IRR_BIND_INACTIVE
      return
    end if
    if (.not. valid_nonnegative_rate(scheduled%gross_surface_rate_cm_per_day)) then
      diagnostics%status = FMR_HUPSEL_IRR_BIND_INVALID_RATE
      return
    end if

    bound_input = base_input
    bound_input%surface_irrigation_cm_per_day = scheduled%gross_surface_rate_cm_per_day
    bound_input%surface_irrigation_is_intercepted = .true.
    diagnostics%gross_irrigation_bound = .true.
    diagnostics%rutter_interception_enabled = .true.
    diagnostics%result_produced = .true.
  end subroutine fmr_bind_tcs1_sprinkling_to_rutter

  subroutine fmr_bind_rutter_net_irrigation_to_dynamic_top(base_request, rutter, upstream, &
                                                            bound_request, diagnostics)
    type(b110_dynamic_top_boundary_request_t), intent(in) :: base_request
    type(rutter_interval_result_t), intent(in) :: rutter
    type(rutter_diagnostics_t), intent(in) :: upstream
    type(b110_dynamic_top_boundary_request_t), intent(out) :: bound_request
    type(fmr_hupsel_irrigation_binding_diagnostics_t), intent(out) :: diagnostics

    bound_request = b110_dynamic_top_boundary_request_t()
    diagnostics = fmr_hupsel_irrigation_binding_diagnostics_t()

    if (upstream%status /= RUTTER_OK .or. .not. upstream%result_produced) then
      diagnostics%status = FMR_HUPSEL_IRR_BIND_UPSTREAM_REJECTED
      return
    end if
    diagnostics%upstream_accepted = .true.
    if (.not. valid_nonnegative_rate(rutter%net_surface_irrigation_cm_per_day)) then
      diagnostics%status = FMR_HUPSEL_IRR_BIND_INVALID_RATE
      return
    end if

    bound_request = base_request
    bound_request%irrigation_rate_cm_per_day = rutter%net_surface_irrigation_cm_per_day
    diagnostics%net_irrigation_bound = .true.
    diagnostics%result_produced = .true.
  end subroutine fmr_bind_rutter_net_irrigation_to_dynamic_top

  pure logical function valid_nonnegative_rate(value)
    real(real64), intent(in) :: value
    valid_nonnegative_rate = ieee_is_finite(value) .and. value >= 0.0_real64
  end function valid_nonnegative_rate

end module mod_fmr_hupsel_irrigation_application_binding
