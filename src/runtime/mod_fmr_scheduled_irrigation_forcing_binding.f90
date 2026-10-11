module mod_fmr_scheduled_irrigation_forcing_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_irrigation_process, only: scheduled_irrigation_parameters_t, scheduled_irrigation_request_t, &
       irrigation_state_t
  use mod_fmr_process_hydraulic_view_binding, only: fmr_build_committed_process_hydraulic_view
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t
  use mod_fmr_scheduled_irrigation_application, only: fmr_scheduled_irrigation_application_diagnostics_t, &
       fmr_apply_scheduled_sensor_dcs2_single_node_ssdi, FMR_SCHEDULED_IRR_OK, FMR_SCHEDULED_IRR_INACTIVE
  implicit none
  private

  integer, parameter, public :: FMR_IRR_FORCING_BIND_OK = 0
  integer, parameter, public :: FMR_IRR_FORCING_BIND_VIEW_REJECTED = 1
  integer, parameter, public :: FMR_IRR_FORCING_BIND_APPLICATION_REJECTED = 2
  integer, parameter, public :: FMR_IRR_FORCING_BIND_SOURCE_CONFLICT = 3
  integer, parameter, public :: FMR_IRR_FORCING_BIND_INVALID_SOURCE = 4

  type, public :: fmr_irrigation_forcing_binding_diagnostics_t
    integer :: status = FMR_IRR_FORCING_BIND_OK
    integer :: application_status = FMR_SCHEDULED_IRR_OK
    logical :: committed_view_built = .false.
    logical :: application_evaluated = .false.
    logical :: source_bound = .false.
    real(real64) :: external_inflow_amount_cm = 0.0_real64
  end type fmr_irrigation_forcing_binding_diagnostics_t

  public :: fmr_prepare_sensor_dcs2_single_node_ssdi_forcing

contains

  subroutine fmr_prepare_sensor_dcs2_single_node_ssdi_forcing(parameters, committed_management, request, &
                                                               committed_physical, base_forcing, candidate_management, &
                                                               bound_forcing, diagnostics)
    type(scheduled_irrigation_parameters_t), intent(in) :: parameters
    type(irrigation_state_t), intent(in) :: committed_management
    type(scheduled_irrigation_request_t), intent(in) :: request
    type(kernel_committed_state_t), intent(in) :: committed_physical
    type(fmr_b110_physical_forcing_t), intent(in) :: base_forcing
    type(irrigation_state_t), intent(out) :: candidate_management
    type(fmr_b110_physical_forcing_t), intent(out) :: bound_forcing
    type(fmr_irrigation_forcing_binding_diagnostics_t), intent(out) :: diagnostics

    type(process_hydraulic_view_t) :: hydraulic_view
    type(fmr_scheduled_irrigation_application_diagnostics_t) :: application_diagnostics
    real(real64), allocatable :: scheduled_source(:)
    logical :: view_ok

    candidate_management = committed_management
    bound_forcing = base_forcing
    diagnostics = fmr_irrigation_forcing_binding_diagnostics_t()

    call fmr_build_committed_process_hydraulic_view(committed_physical, hydraulic_view, view_ok)
    if (.not. view_ok) then
      diagnostics%status = FMR_IRR_FORCING_BIND_VIEW_REJECTED
      return
    end if
    diagnostics%committed_view_built = .true.

    call fmr_apply_scheduled_sensor_dcs2_single_node_ssdi(parameters, committed_management, request, hydraulic_view, &
                                                           candidate_management, scheduled_source, application_diagnostics)
    diagnostics%application_evaluated = .true.
    diagnostics%application_status = application_diagnostics%status
    if (application_diagnostics%status == FMR_SCHEDULED_IRR_INACTIVE) return
    if (application_diagnostics%status /= FMR_SCHEDULED_IRR_OK .or. .not. application_diagnostics%result_produced) then
      candidate_management = committed_management
      bound_forcing = base_forcing
      diagnostics%status = FMR_IRR_FORCING_BIND_APPLICATION_REJECTED
      return
    end if

    if (.not. allocated(scheduled_source) .or. size(scheduled_source) /= parameters%active_nodes .or. &
        any(.not. ieee_is_finite(scheduled_source)) .or. any(scheduled_source < 0.0_real64)) then
      candidate_management = committed_management
      bound_forcing = base_forcing
      diagnostics%status = FMR_IRR_FORCING_BIND_INVALID_SOURCE
      return
    end if
    if (allocated(base_forcing%subsurface_irrigation_source)) then
      if (size(base_forcing%subsurface_irrigation_source) /= parameters%active_nodes) then
        candidate_management = committed_management
        bound_forcing = base_forcing
        diagnostics%status = FMR_IRR_FORCING_BIND_INVALID_SOURCE
        return
      end if
      if (any(abs(base_forcing%subsurface_irrigation_source) > epsilon(1.0_real64))) then
        candidate_management = committed_management
        bound_forcing = base_forcing
        diagnostics%status = FMR_IRR_FORCING_BIND_SOURCE_CONFLICT
        return
      end if
    else
      allocate(bound_forcing%subsurface_irrigation_source(parameters%active_nodes))
    end if

    bound_forcing%subsurface_irrigation_source = scheduled_source
    diagnostics%source_bound = .true.
    diagnostics%external_inflow_amount_cm = application_diagnostics%external_inflow_amount_cm
  end subroutine fmr_prepare_sensor_dcs2_single_node_ssdi_forcing

end module mod_fmr_scheduled_irrigation_forcing_binding
