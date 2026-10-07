module mod_fmr_scheduled_irrigation_application
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_irrigation_process, only: scheduled_irrigation_parameters_t, scheduled_irrigation_request_t, &
       irrigation_state_t, irrigation_flux_result_t, irrigation_diagnostics_t, &
       evaluate_scheduled_irrigation_interval, IRRIGATION_OK, IRRIGATION_APPLICATION_SSDI
  implicit none
  private

  integer, parameter, public :: FMR_SCHEDULED_IRR_OK = 0
  integer, parameter, public :: FMR_SCHEDULED_IRR_UPSTREAM_REJECTED = 1
  integer, parameter, public :: FMR_SCHEDULED_IRR_INACTIVE = 2
  integer, parameter, public :: FMR_SCHEDULED_IRR_UNSUPPORTED_APPLICATION = 3
  integer, parameter, public :: FMR_SCHEDULED_IRR_INVALID_SOURCE = 4

  type, public :: fmr_scheduled_irrigation_application_diagnostics_t
    integer :: status = FMR_SCHEDULED_IRR_OK
    integer :: process_status = IRRIGATION_OK
    logical :: process_called = .false.
    logical :: source_bound = .false.
    logical :: result_produced = .false.
    real(real64) :: external_inflow_amount_cm = 0.0_real64
  end type fmr_scheduled_irrigation_application_diagnostics_t

  public :: fmr_apply_scheduled_tcs7_dcs2_single_node_ssdi

contains

  subroutine fmr_apply_scheduled_tcs7_dcs2_single_node_ssdi(parameters, committed_state, request, hydraulic_view, &
                                                             candidate_state, subsurface_source, diagnostics)
    type(scheduled_irrigation_parameters_t), intent(in) :: parameters
    type(irrigation_state_t), intent(in) :: committed_state
    type(scheduled_irrigation_request_t), intent(in) :: request
    type(process_hydraulic_view_t), intent(in) :: hydraulic_view
    type(irrigation_state_t), intent(out) :: candidate_state
    real(real64), allocatable, intent(out) :: subsurface_source(:)
    type(fmr_scheduled_irrigation_application_diagnostics_t), intent(out) :: diagnostics
    type(irrigation_flux_result_t) :: flux
    type(irrigation_diagnostics_t) :: process_diagnostics

    candidate_state = committed_state
    if (allocated(subsurface_source)) deallocate(subsurface_source)
    diagnostics = fmr_scheduled_irrigation_application_diagnostics_t()

    call evaluate_scheduled_irrigation_interval(parameters, committed_state, request, hydraulic_view, &
                                                candidate_state, flux, process_diagnostics)
    diagnostics%process_called = .true.
    diagnostics%process_status = process_diagnostics%status

    if (process_diagnostics%status /= IRRIGATION_OK) then
      diagnostics%status = FMR_SCHEDULED_IRR_UPSTREAM_REJECTED
      return
    end if
    if (.not. flux%applied) then
      diagnostics%status = FMR_SCHEDULED_IRR_INACTIVE
      return
    end if
    if (flux%application_type /= IRRIGATION_APPLICATION_SSDI) then
      candidate_state = committed_state
      diagnostics%status = FMR_SCHEDULED_IRR_UNSUPPORTED_APPLICATION
      return
    end if
    if (.not. allocated(flux%subsurface_source)) then
      candidate_state = committed_state
      diagnostics%status = FMR_SCHEDULED_IRR_INVALID_SOURCE
      return
    end if
    if (size(flux%subsurface_source) /= parameters%active_nodes) then
      candidate_state = committed_state
      diagnostics%status = FMR_SCHEDULED_IRR_INVALID_SOURCE
      return
    end if

    allocate(subsurface_source(parameters%active_nodes))
    subsurface_source = flux%subsurface_source
    diagnostics%external_inflow_amount_cm = flux%external_inflow_amount
    diagnostics%source_bound = .true.
    diagnostics%result_produced = .true.
  end subroutine fmr_apply_scheduled_tcs7_dcs2_single_node_ssdi

end module mod_fmr_scheduled_irrigation_application
