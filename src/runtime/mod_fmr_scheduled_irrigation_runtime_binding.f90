module mod_fmr_scheduled_irrigation_runtime_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_irrigation_process, only: scheduled_irrigation_parameters_t, scheduled_irrigation_request_t, &
       irrigation_state_t, irrigation_flux_result_t, irrigation_diagnostics_t, &
       evaluate_scheduled_irrigation_interval, IRRIGATION_OK, IRRIGATION_APPLICATION_SSDI
  use mod_fmr_process_hydraulic_view_binding, only: fmr_build_committed_process_hydraulic_view
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t
  implicit none
  private

  integer, parameter, public :: FMR_SCHEDULED_IRRIGATION_BIND_OK = 0
  integer, parameter, public :: FMR_SCHEDULED_IRRIGATION_BIND_HYDRAULIC_VIEW = 1
  integer, parameter, public :: FMR_SCHEDULED_IRRIGATION_BIND_PROCESS_REJECTED = 2
  integer, parameter, public :: FMR_SCHEDULED_IRRIGATION_BIND_UNSUPPORTED_ROUTE = 3
  integer, parameter, public :: FMR_SCHEDULED_IRRIGATION_BIND_SHAPE = 4

  type, public :: fmr_scheduled_irrigation_binding_diagnostics_t
    integer :: status = FMR_SCHEDULED_IRRIGATION_BIND_OK
    logical :: hydraulic_view_built = .false.
    logical :: process_evaluated = .false.
    logical :: source_bound = .false.
    real(real64) :: external_inflow_amount_cm = 0.0_real64
  end type fmr_scheduled_irrigation_binding_diagnostics_t

  public :: fmr_evaluate_and_bind_scheduled_ssdi

contains

  subroutine fmr_evaluate_and_bind_scheduled_ssdi(parameters, irrigation_committed, request, &
                                                   physical_committed, base_forcing, irrigation_candidate, &
                                                   bound_forcing, flux, process_diagnostics, diagnostics)
    type(scheduled_irrigation_parameters_t), intent(in) :: parameters
    type(irrigation_state_t), intent(in) :: irrigation_committed
    type(scheduled_irrigation_request_t), intent(in) :: request
    type(kernel_committed_state_t), intent(in) :: physical_committed
    type(fmr_b110_physical_forcing_t), intent(in) :: base_forcing
    type(irrigation_state_t), intent(out) :: irrigation_candidate
    type(fmr_b110_physical_forcing_t), intent(out) :: bound_forcing
    type(irrigation_flux_result_t), intent(out) :: flux
    type(irrigation_diagnostics_t), intent(out) :: process_diagnostics
    type(fmr_scheduled_irrigation_binding_diagnostics_t), intent(out) :: diagnostics

    type(process_hydraulic_view_t) :: hydraulic_view
    logical :: view_ok

    irrigation_candidate = irrigation_committed
    bound_forcing = base_forcing
    flux = irrigation_flux_result_t()
    process_diagnostics = irrigation_diagnostics_t()
    diagnostics = fmr_scheduled_irrigation_binding_diagnostics_t()

    call fmr_build_committed_process_hydraulic_view(physical_committed, hydraulic_view, view_ok)
    if (.not. view_ok) then
      diagnostics%status = FMR_SCHEDULED_IRRIGATION_BIND_HYDRAULIC_VIEW
      return
    end if
    diagnostics%hydraulic_view_built = .true.

    call evaluate_scheduled_irrigation_interval(parameters, irrigation_committed, request, hydraulic_view, &
                                                irrigation_candidate, flux, process_diagnostics)
    diagnostics%process_evaluated = .true.
    if (process_diagnostics%status /= IRRIGATION_OK) then
      diagnostics%status = FMR_SCHEDULED_IRRIGATION_BIND_PROCESS_REJECTED
      bound_forcing = base_forcing
      irrigation_candidate = irrigation_committed
      return
    end if
    if (.not. flux%applied) return
    if (flux%application_type /= IRRIGATION_APPLICATION_SSDI) then
      diagnostics%status = FMR_SCHEDULED_IRRIGATION_BIND_UNSUPPORTED_ROUTE
      bound_forcing = base_forcing
      irrigation_candidate = irrigation_committed
      return
    end if
    if (.not. allocated(flux%subsurface_source)) then
      diagnostics%status = FMR_SCHEDULED_IRRIGATION_BIND_SHAPE
      bound_forcing = base_forcing
      irrigation_candidate = irrigation_committed
      return
    end if
    if (size(flux%subsurface_source) /= parameters%active_nodes) then
      diagnostics%status = FMR_SCHEDULED_IRRIGATION_BIND_SHAPE
      bound_forcing = base_forcing
      irrigation_candidate = irrigation_committed
      return
    end if

    if (allocated(bound_forcing%subsurface_irrigation_source)) then
      if (size(bound_forcing%subsurface_irrigation_source) /= parameters%active_nodes) then
        diagnostics%status = FMR_SCHEDULED_IRRIGATION_BIND_SHAPE
        bound_forcing = base_forcing
        irrigation_candidate = irrigation_committed
        return
      end if
      bound_forcing%subsurface_irrigation_source = bound_forcing%subsurface_irrigation_source + flux%subsurface_source
    else
      allocate(bound_forcing%subsurface_irrigation_source(parameters%active_nodes))
      bound_forcing%subsurface_irrigation_source = flux%subsurface_source
    end if

    diagnostics%source_bound = .true.
    diagnostics%external_inflow_amount_cm = flux%external_inflow_amount
  end subroutine fmr_evaluate_and_bind_scheduled_ssdi

end module mod_fmr_scheduled_irrigation_runtime_binding
