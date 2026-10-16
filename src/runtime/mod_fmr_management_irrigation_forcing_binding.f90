module mod_fmr_management_irrigation_forcing_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_irrigation_process, only: irrigation_flux_result_t, IRRIGATION_APPLICATION_SSDI
  use mod_scheduled_irrigation_management_policy, only: irrigation_management_policy_result_t
  use mod_irrigation_root_zone_summary, only: irrigation_root_zone_summary_t
  use mod_fmr_process_hydraulic_view_binding, only: fmr_build_committed_process_hydraulic_view
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t
  use mod_fmr_scheduled_management_irrigation_application, only: fmr_irrigation_management_parameters_t, &
       fmr_irrigation_management_request_t, fmr_irrigation_management_state_t, &
       fmr_irrigation_management_diagnostics_t, fmr_evaluate_scheduled_management_irrigation, FMR_IRR_MGMT_APP_OK
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_soil_water_solver_contract, only: top_boundary_provider_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, &
       fmr_column_diagnostics_t, fmr_aggregate_diagnostics_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK
  implicit none
  private

  integer, parameter, public :: FMR_MGMT_FORCING_BIND_OK = 0
  integer, parameter, public :: FMR_MGMT_FORCING_BIND_VIEW_REJECTED = 1
  integer, parameter, public :: FMR_MGMT_FORCING_BIND_APPLICATION_REJECTED = 2
  integer, parameter, public :: FMR_MGMT_FORCING_BIND_SOURCE_CONFLICT = 3
  integer, parameter, public :: FMR_MGMT_FORCING_BIND_INVALID_SOURCE = 4

  type, public :: fmr_management_forcing_binding_diagnostics_t
    integer :: status = FMR_MGMT_FORCING_BIND_OK
    integer :: application_status = FMR_IRR_MGMT_APP_OK
    logical :: split_required = .false.
    real(real64) :: split_time = 0.0_real64
    logical :: committed_view_built = .false.
    logical :: application_evaluated = .false.
    logical :: source_bound = .false.
    real(real64) :: external_inflow_amount_cm = 0.0_real64
  end type fmr_management_forcing_binding_diagnostics_t

  public :: fmr_prepare_management_ssdi_forcing
  public :: fmr_run_management_ssdi_interval

contains

  ! Execute on a detached F-KT clone. Publish physical and management state
  ! together only after the whole requested interval passes existing gates.
  ! Partial successful substeps in a failed interval never consume an event.
  subroutine fmr_run_management_ssdi_interval(column, template, physical_parameters, base_forcing, &
       physical_state, management_parameters, management_state, request, numerical_config, top_boundary, &
       result, runtime, binding, accepted)
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: template
    type(fmr_b110_physical_parameters_t), intent(in) :: physical_parameters
    type(fmr_b110_physical_forcing_t), intent(in) :: base_forcing
    type(kernel_committed_state_t), intent(inout) :: physical_state
    type(fmr_irrigation_management_parameters_t), intent(in) :: management_parameters
    type(fmr_irrigation_management_state_t), intent(inout) :: management_state
    type(fmr_irrigation_management_request_t), intent(in) :: request
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    class(top_boundary_provider_t), target, intent(in) :: top_boundary
    type(fmr_serialized_column_result_t), intent(out) :: result
    type(fmr_serialized_batch_diagnostics_t), intent(out) :: runtime
    type(fmr_management_forcing_binding_diagnostics_t), intent(out) :: binding
    logical, intent(out) :: accepted
    type(kernel_committed_state_t) :: trial_states(1)
    type(fmr_b110_physical_forcing_t) :: forcing(1)
    type(fmr_irrigation_management_state_t) :: candidate_management
    type(fmr_serialized_column_result_t), allocatable :: results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    integer :: dispatch

    accepted = .false.
    result = fmr_serialized_column_result_t()
    runtime = fmr_serialized_batch_diagnostics_t()
    call fmr_prepare_management_ssdi_forcing(management_parameters, management_state, request, &
         physical_state, base_forcing, candidate_management, forcing(1), binding)
    if (binding%status /= FMR_MGMT_FORCING_BIND_OK) return
    trial_states(1) = physical_state
    call fmr_run_serialized_physical_multiswap([column], [template], [physical_parameters], forcing, &
         trial_states, numerical_config, top_boundary, request%t0, request%t1, 1, results, diagnostics, &
         aggregate, dispatch, runtime)
    if (dispatch /= FMR_SERIAL_DISPATCH_OK) return
    if (.not. allocated(results)) return
    if (size(results) /= 1) return
    result = results(1)
    if (.not. result%completed .or. .not. result%committed) return
    if (.not. result%mass%complete) return
    physical_state = trial_states(1)
    management_state = candidate_management
    accepted = .true.
  end subroutine fmr_run_management_ssdi_interval

  subroutine fmr_prepare_management_ssdi_forcing(parameters, committed_management, request, &
                                                               committed_physical, base_forcing, candidate_management, &
                                                               bound_forcing, diagnostics)
    type(fmr_irrigation_management_parameters_t), intent(in) :: parameters
    type(fmr_irrigation_management_state_t), intent(in) :: committed_management
    type(fmr_irrigation_management_request_t), intent(in) :: request
    type(kernel_committed_state_t), intent(in) :: committed_physical
    type(fmr_b110_physical_forcing_t), intent(in) :: base_forcing
    type(fmr_irrigation_management_state_t), intent(out) :: candidate_management
    type(fmr_b110_physical_forcing_t), intent(out) :: bound_forcing
    type(fmr_management_forcing_binding_diagnostics_t), intent(out) :: diagnostics

    type(process_hydraulic_view_t) :: hydraulic_view
    type(fmr_irrigation_management_diagnostics_t) :: application_diagnostics
    type(irrigation_flux_result_t) :: flux
    type(irrigation_management_policy_result_t) :: policy
    type(irrigation_root_zone_summary_t) :: summary
    logical :: view_ok

    candidate_management = committed_management
    bound_forcing = base_forcing
    diagnostics = fmr_management_forcing_binding_diagnostics_t()

    call fmr_build_committed_process_hydraulic_view(committed_physical, hydraulic_view, view_ok)
    if (.not. view_ok) then
      diagnostics%status = FMR_MGMT_FORCING_BIND_VIEW_REJECTED
      return
    end if
    diagnostics%committed_view_built = .true.

    call fmr_evaluate_scheduled_management_irrigation(parameters, committed_management, request, hydraulic_view, &
         candidate_management, flux, policy, summary, application_diagnostics)
    diagnostics%application_evaluated = .true.
    diagnostics%application_status = application_diagnostics%status
    diagnostics%split_required = application_diagnostics%split_required
    diagnostics%split_time = application_diagnostics%split_time
    if (application_diagnostics%status /= FMR_IRR_MGMT_APP_OK) then
      candidate_management = committed_management
      bound_forcing = base_forcing
      diagnostics%status = FMR_MGMT_FORCING_BIND_APPLICATION_REJECTED
      return
    end if

    if (.not. flux%applied) return
    if (flux%application_type /= IRRIGATION_APPLICATION_SSDI) then
      candidate_management = committed_management
      diagnostics%status = FMR_MGMT_FORCING_BIND_APPLICATION_REJECTED
      return
    end if
    if (.not. allocated(flux%subsurface_source)) then
      candidate_management = committed_management
      diagnostics%status = FMR_MGMT_FORCING_BIND_INVALID_SOURCE
      return
    end if
    if (size(flux%subsurface_source) /= parameters%active_nodes) then
      candidate_management = committed_management
      diagnostics%status = FMR_MGMT_FORCING_BIND_INVALID_SOURCE
      return
    end if
    if (any(.not. ieee_is_finite(flux%subsurface_source))) then
      candidate_management = committed_management
      diagnostics%status = FMR_MGMT_FORCING_BIND_INVALID_SOURCE
      return
    end if
    if (any(flux%subsurface_source < 0.0_real64)) then
      candidate_management = committed_management
      bound_forcing = base_forcing
      diagnostics%status = FMR_MGMT_FORCING_BIND_INVALID_SOURCE
      return
    end if
    if (allocated(base_forcing%subsurface_irrigation_source)) then
      if (size(base_forcing%subsurface_irrigation_source) /= parameters%active_nodes) then
        candidate_management = committed_management
        bound_forcing = base_forcing
        diagnostics%status = FMR_MGMT_FORCING_BIND_INVALID_SOURCE
        return
      end if
      if (any(.not. ieee_is_finite(base_forcing%subsurface_irrigation_source))) then
        candidate_management = committed_management
        diagnostics%status = FMR_MGMT_FORCING_BIND_INVALID_SOURCE
        return
      end if
      if (any(base_forcing%subsurface_irrigation_source /= 0.0_real64)) then
        candidate_management = committed_management
        bound_forcing = base_forcing
        diagnostics%status = FMR_MGMT_FORCING_BIND_SOURCE_CONFLICT
        return
      end if
    else
      allocate(bound_forcing%subsurface_irrigation_source(parameters%active_nodes))
    end if

    bound_forcing%subsurface_irrigation_source = flux%subsurface_source
    diagnostics%source_bound = .true.
    diagnostics%external_inflow_amount_cm = flux%external_inflow_amount
  end subroutine fmr_prepare_management_ssdi_forcing

end module mod_fmr_management_irrigation_forcing_binding
