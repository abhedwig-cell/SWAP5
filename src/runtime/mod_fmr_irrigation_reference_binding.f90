module mod_fmr_irrigation_reference_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_irrigation_process, only: irrigation_state_t, irrigation_flux_result_t, irrigation_diagnostics_t, &
       scheduled_irrigation_parameters_t, scheduled_irrigation_request_t, evaluate_scheduled_irrigation_interval
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_process_hydraulic_view_binding, only: fmr_build_committed_process_hydraulic_view
  use mod_fmr_irrigation_depth_binding, only: bind_irrigation_depth_to_nodes, IRRIGATION_DEPTH_BIND_OK
  use mod_fmr_irrigation_source_binding, only: fmr_bind_irrigation_to_subsurface_source, &
       fmr_irrigation_source_diagnostics_t, FMR_IRR_SOURCE_OK
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t, fmr_b110_physical_parameters_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t
  implicit none
  private
  integer, parameter, public :: FMR_IRR_REFERENCE_OK = 0
  integer, parameter, public :: FMR_IRR_REFERENCE_INVALID = 1
  public :: fmr_bind_ssdi_reference_candidate, fmr_publish_accepted_irrigation_state
  public :: fmr_prepare_scheduled_irrigation_from_accepted
contains
  subroutine fmr_prepare_scheduled_irrigation_from_accepted(parameters, committed_physical, accepted_result, &
       sensor_depth_below_surface_cm, committed_management, request, scheduled_parameters, candidate_management, &
       flux, diagnostics, status)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(kernel_committed_state_t), intent(in) :: committed_physical
    type(fmr_serialized_column_result_t), intent(in) :: accepted_result
    real(real64), intent(in) :: sensor_depth_below_surface_cm
    type(irrigation_state_t), intent(in) :: committed_management
    type(scheduled_irrigation_request_t), intent(in) :: request
    type(scheduled_irrigation_parameters_t), intent(in) :: scheduled_parameters
    type(irrigation_state_t), intent(out) :: candidate_management
    type(irrigation_flux_result_t), intent(out) :: flux
    type(irrigation_diagnostics_t), intent(out) :: diagnostics
    integer, intent(out) :: status
    type(process_hydraulic_view_t) :: hydraulic
    type(scheduled_irrigation_parameters_t) :: bound_parameters
    real(real64) :: committed_time
    integer :: first_node, last_node, bind_status
    logical :: time_available, view_available

    status = FMR_IRR_REFERENCE_INVALID
    candidate_management = committed_management
    flux = irrigation_flux_result_t()
    diagnostics = irrigation_diagnostics_t()
    if (.not. accepted_result%completed .or. .not. accepted_result%committed .or. &
        .not. accepted_result%mass%complete .or. .not. accepted_result%final_committed_time_bound) return
    if (accepted_result%column_id <= 0_int64 .or. .not. committed_physical%ready() .or. &
        .not. committed_physical%time_is_bound()) return
    if (accepted_result%column_id /= committed_physical%current_lineage_id() .or. &
        accepted_result%final_revision /= committed_physical%current_revision()) return
    call committed_physical%current_time(committed_time,time_available)
    if (.not. time_available .or. .not. ieee_is_finite(committed_time) .or. &
        .not. ieee_is_finite(accepted_result%final_committed_time)) return
    if (accepted_result%final_committed_time /= committed_time .or. request%t0 /= committed_time) return
    if (.not. ieee_is_finite(sensor_depth_below_surface_cm) .or. &
        sensor_depth_below_surface_cm <= 0.0_real64) return
    if (parameters%active_nodes <= 0 .or. .not. allocated(parameters%z)) return
    if (size(parameters%z) /= parameters%active_nodes) return
    call bind_irrigation_depth_to_nodes(parameters%z,-sensor_depth_below_surface_cm, &
         -sensor_depth_below_surface_cm,first_node,last_node,bind_status)
    if (bind_status /= IRRIGATION_DEPTH_BIND_OK .or. first_node /= last_node) return
    call fmr_build_committed_process_hydraulic_view(committed_physical,hydraulic,view_available)
    if (.not. view_available .or. hydraulic%active_nodes /= parameters%active_nodes) return

    bound_parameters = scheduled_parameters
    bound_parameters%active_nodes = parameters%active_nodes
    bound_parameters%sensor_node = first_node
    call evaluate_scheduled_irrigation_interval(bound_parameters,committed_management,request,hydraulic, &
         candidate_management,flux,diagnostics)
    status = FMR_IRR_REFERENCE_OK
  end subroutine fmr_prepare_scheduled_irrigation_from_accepted

  subroutine fmr_bind_ssdi_reference_candidate(base, flux, diagnostics, candidate, status)
    type(fmr_b110_physical_forcing_t), intent(in) :: base
    type(irrigation_flux_result_t), intent(in) :: flux
    type(irrigation_diagnostics_t), intent(in) :: diagnostics
    type(fmr_b110_physical_forcing_t), intent(out) :: candidate
    integer, intent(out) :: status
    type(fmr_irrigation_source_diagnostics_t) :: bound
    real(real64), allocatable :: source(:)

    status = FMR_IRR_REFERENCE_INVALID
    if (.not. allocated(base%subsurface_irrigation_source)) return
    if (.not. allocated(flux%subsurface_source)) return
    if (.not. ieee_is_finite(flux%active_duration) .or. &
        .not. ieee_is_finite(flux%external_inflow_amount)) return
    if (flux%active_duration <= 0.0_real64 .or. flux%external_inflow_amount < 0.0_real64) return
    if (size(flux%subsurface_source) /= size(base%subsurface_irrigation_source)) return
    if (abs(sum(flux%subsurface_source)*flux%active_duration-flux%external_inflow_amount) > &
        1.e-12_real64*max(1.0_real64,flux%external_inflow_amount)) return
    call fmr_bind_irrigation_to_subsurface_source(base%subsurface_irrigation_source, &
         flux, diagnostics, source, bound)
    if (bound%status /= FMR_IRR_SOURCE_OK) return
    candidate = base
    candidate%subsurface_irrigation_source = source
    status = FMR_IRR_REFERENCE_OK
  end subroutine

  subroutine fmr_publish_accepted_irrigation_state(committed, proposed, result, &
       expected_column_id, expected_t1, published)
    type(irrigation_state_t), intent(inout) :: committed
    type(irrigation_state_t), intent(in) :: proposed
    type(fmr_serialized_column_result_t), intent(in) :: result
    integer(int64), intent(in) :: expected_column_id
    real(real64), intent(in) :: expected_t1
    logical, intent(out) :: published
    published = .false.
    if (expected_column_id <= 0_int64 .or. .not. ieee_is_finite(expected_t1)) return
    if (result%column_id /= expected_column_id) return
    if (.not. result%completed .or. .not. result%committed .or. &
        .not. result%mass%complete .or. .not. result%final_committed_time_bound) return
    if (.not. ieee_is_finite(result%final_committed_time)) return
    if (result%final_committed_time /= expected_t1) return
    published = .true.
    if (published) committed = proposed
  end subroutine
end module
