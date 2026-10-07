module mod_fmr_tcs7_ssdi_irrigation_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_irrigation_process, only: scheduled_irrigation_parameters_t, scheduled_irrigation_request_t, &
       irrigation_state_t, irrigation_flux_result_t, irrigation_diagnostics_t, &
       evaluate_scheduled_irrigation_interval, IRRIGATION_OK, IRRIGATION_APPLICATION_SSDI
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t
  use mod_fmr_process_hydraulic_view_binding, only: fmr_build_committed_process_hydraulic_view
  implicit none
  private

  integer, parameter, public :: FMR_TCS7_SSDI_BIND_OK = 0
  integer, parameter, public :: FMR_TCS7_SSDI_BIND_VIEW_REJECTED = 1
  integer, parameter, public :: FMR_TCS7_SSDI_BIND_PROCESS_REJECTED = 2
  integer, parameter, public :: FMR_TCS7_SSDI_BIND_INVALID_SOURCE = 3
  integer, parameter, public :: FMR_TCS7_SSDI_BIND_SOURCE_CONFLICT = 4

  type, public :: fmr_tcs7_ssdi_binding_diagnostics_t
    integer :: status = FMR_TCS7_SSDI_BIND_OK
    logical :: committed_view_built = .false.
    logical :: selection_evaluated = .false.
    logical :: event_applied = .false.
    logical :: source_bound = .false.
  end type fmr_tcs7_ssdi_binding_diagnostics_t

  public :: fmr_prepare_tcs7_dcs2_single_node_ssdi

contains

  subroutine fmr_prepare_tcs7_dcs2_single_node_ssdi(parameters, committed_management, request, &
                                                     committed_physical, base_forcing, candidate_management, &
                                                     bound_forcing, flux, process_diagnostics, diagnostics)
    type(scheduled_irrigation_parameters_t), intent(in) :: parameters
    type(irrigation_state_t), intent(in) :: committed_management
    type(scheduled_irrigation_request_t), intent(in) :: request
    type(kernel_committed_state_t), intent(in) :: committed_physical
    type(fmr_b110_physical_forcing_t), intent(in) :: base_forcing
    type(irrigation_state_t), intent(out) :: candidate_management
    type(fmr_b110_physical_forcing_t), intent(out) :: bound_forcing
    type(irrigation_flux_result_t), intent(out) :: flux
    type(irrigation_diagnostics_t), intent(out) :: process_diagnostics
    type(fmr_tcs7_ssdi_binding_diagnostics_t), intent(out) :: diagnostics
    type(process_hydraulic_view_t) :: hydraulic_view
    logical :: view_ok

    candidate_management = committed_management
    bound_forcing = base_forcing
    flux = irrigation_flux_result_t()
    process_diagnostics = irrigation_diagnostics_t()
    diagnostics = fmr_tcs7_ssdi_binding_diagnostics_t()

    call fmr_build_committed_process_hydraulic_view(committed_physical, hydraulic_view, view_ok)
    if (.not. view_ok) then
      diagnostics%status = FMR_TCS7_SSDI_BIND_VIEW_REJECTED
      return
    end if
    diagnostics%committed_view_built = .true.

    call evaluate_scheduled_irrigation_interval(parameters, committed_management, request, hydraulic_view, &
                                                candidate_management, flux, process_diagnostics)
    diagnostics%selection_evaluated = process_diagnostics%selection_evaluated
    if (process_diagnostics%status /= IRRIGATION_OK) then
      candidate_management = committed_management
      bound_forcing = base_forcing
      diagnostics%status = FMR_TCS7_SSDI_BIND_PROCESS_REJECTED
      return
    end if
    if (.not. flux%applied) return

    diagnostics%event_applied = .true.
    if (flux%application_type /= IRRIGATION_APPLICATION_SSDI .or. .not. allocated(flux%subsurface_source)) then
      candidate_management = committed_management
      bound_forcing = base_forcing
      diagnostics%status = FMR_TCS7_SSDI_BIND_INVALID_SOURCE
      return
    end if
    if (size(flux%subsurface_source) /= parameters%active_nodes .or. &
        any(.not. ieee_is_finite(flux%subsurface_source)) .or. any(flux%subsurface_source < 0.0_real64)) then
      candidate_management = committed_management
      bound_forcing = base_forcing
      diagnostics%status = FMR_TCS7_SSDI_BIND_INVALID_SOURCE
      return
    end if
    if (allocated(base_forcing%subsurface_irrigation_source)) then
      if (size(base_forcing%subsurface_irrigation_source) /= parameters%active_nodes) then
        candidate_management = committed_management
        bound_forcing = base_forcing
        diagnostics%status = FMR_TCS7_SSDI_BIND_INVALID_SOURCE
        return
      end if
      if (any(abs(base_forcing%subsurface_irrigation_source) > epsilon(1.0_real64))) then
        candidate_management = committed_management
        bound_forcing = base_forcing
        diagnostics%status = FMR_TCS7_SSDI_BIND_SOURCE_CONFLICT
        return
      end if
    else
      allocate(bound_forcing%subsurface_irrigation_source(parameters%active_nodes))
    end if

    bound_forcing%subsurface_irrigation_source = flux%subsurface_source
    diagnostics%source_bound = .true.
  end subroutine fmr_prepare_tcs7_dcs2_single_node_ssdi

end module mod_fmr_tcs7_ssdi_irrigation_binding
