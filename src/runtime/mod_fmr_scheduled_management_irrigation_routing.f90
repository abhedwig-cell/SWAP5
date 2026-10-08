module mod_fmr_scheduled_management_irrigation_routing
  use mod_irrigation_process, only: irrigation_flux_result_t, irrigation_diagnostics_t, &
       IRRIGATION_OK, IRRIGATION_INVALID_PARAMETERS, IRRIGATION_APPLICATION_SURFACE
  use mod_fmr_scheduled_management_irrigation_application, only: &
       fmr_irrigation_management_diagnostics_t, FMR_IRR_MGMT_APP_OK
  use mod_fmr_hupsel_irrigation_application_binding, only: &
       fmr_hupsel_irrigation_binding_diagnostics_t, &
       fmr_bind_fixed_surface_irrigation_identity_to_dynamic_top, &
       fmr_bind_fixed_sprinkler_to_rutter, FMR_HUPSEL_IRR_BIND_UNSUPPORTED_APPLICATION
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t
  use mod_rutter_interception_process, only: rutter_interval_input_t
  implicit none
  private

  public :: fmr_bind_management_surface_to_dynamic_top
  public :: fmr_bind_management_sprinkler_to_rutter

contains

  subroutine fmr_bind_management_surface_to_dynamic_top(base_request, flux, management, bound_request, diagnostics)
    type(b110_dynamic_top_boundary_request_t), intent(in) :: base_request
    type(irrigation_flux_result_t), intent(in) :: flux
    type(fmr_irrigation_management_diagnostics_t), intent(in) :: management
    type(b110_dynamic_top_boundary_request_t), intent(out) :: bound_request
    type(fmr_hupsel_irrigation_binding_diagnostics_t), intent(out) :: diagnostics
    type(irrigation_diagnostics_t) :: upstream

    call management_as_irrigation_diagnostics(management, upstream)
    ! Fail closed on a rejected management candidate before inspecting the
    ! default application type of its deliberately empty flux result.
    if (upstream%status /= IRRIGATION_OK) then
      call fmr_bind_fixed_surface_irrigation_identity_to_dynamic_top(base_request, flux, upstream, &
                                                                      bound_request, diagnostics)
      return
    end if
    if (flux%application_type /= IRRIGATION_APPLICATION_SURFACE) then
      bound_request = b110_dynamic_top_boundary_request_t()
      diagnostics = fmr_hupsel_irrigation_binding_diagnostics_t()
      diagnostics%status = FMR_HUPSEL_IRR_BIND_UNSUPPORTED_APPLICATION
      return
    end if
    call fmr_bind_fixed_surface_irrigation_identity_to_dynamic_top(base_request, flux, upstream, &
                                                                    bound_request, diagnostics)
  end subroutine fmr_bind_management_surface_to_dynamic_top

  subroutine fmr_bind_management_sprinkler_to_rutter(base_input, flux, management, bound_input, diagnostics)
    type(rutter_interval_input_t), intent(in) :: base_input
    type(irrigation_flux_result_t), intent(in) :: flux
    type(fmr_irrigation_management_diagnostics_t), intent(in) :: management
    type(rutter_interval_input_t), intent(out) :: bound_input
    type(fmr_hupsel_irrigation_binding_diagnostics_t), intent(out) :: diagnostics
    type(irrigation_diagnostics_t) :: upstream

    call management_as_irrigation_diagnostics(management, upstream)
    call fmr_bind_fixed_sprinkler_to_rutter(base_input, flux, upstream, bound_input, diagnostics)
  end subroutine fmr_bind_management_sprinkler_to_rutter

  pure subroutine management_as_irrigation_diagnostics(management, upstream)
    type(fmr_irrigation_management_diagnostics_t), intent(in) :: management
    type(irrigation_diagnostics_t), intent(out) :: upstream
    upstream = irrigation_diagnostics_t()
    if (management%status /= FMR_IRR_MGMT_APP_OK) upstream%status = IRRIGATION_INVALID_PARAMETERS
  end subroutine management_as_irrigation_diagnostics

end module mod_fmr_scheduled_management_irrigation_routing
