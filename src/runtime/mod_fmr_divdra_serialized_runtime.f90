module mod_fmr_divdra_serialized_runtime
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_soil_water_solver_contract, only: top_boundary_provider_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_fmr_divdra_runtime_binding, only: fmr_divdra_binding_diagnostics_t, &
       fmr_divdra_multilevel_binding_diagnostics_t, fmr_bind_single_level_signed_divdra, &
       fmr_bind_multilevel_signed_divdra, FMR_DIVDRA_BIND_OK
  use mod_fmr_divdra_discharge_top_binding, only: apply_fmr_divdra_discharge_top_controls, FMR_DIVDRA_TOP_OK
  use mod_fmr_divdra_top_interflow_binding, only: fmr_divdra_top_interflow_binding_diagnostics_t, &
       fmr_bind_highest_interflow_signed_divdra, FMR_DIVDRA_TOPINT_OK
  use mod_fmr_divdra_separate_infiltration_binding, only: fmr_divdra_separate_infiltration_binding_diagnostics_t, &
       fmr_bind_single_level_separate_infiltration, FMR_DIVDRA_INF_SPLIT_OK
  use mod_fmr_divdra_multilevel_separate_infiltration_binding, only: &
       fmr_divdra_multi_inf_binding_diagnostics_t, &
       fmr_bind_multilevel_separate_infiltration, FMR_DIVDRA_MULTI_INF_OK
  use mod_fmr_divdra_serialized_composition, only: fmr_divdra_serialized_column_request_t, &
       fmr_divdra_serialized_binding_record_t, fmr_preflight_serialized_divdra, &
       FMR_DIVDRA_COMPOSE_OK, FMR_DIVDRA_COMPOSE_BIND_REJECTED
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_commit_receipt_record_t, fmr_serialized_batch_diagnostics_t, &
       fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_INVALID_REQUEST
  implicit none
  private

  public :: fmr_divdra_serialized_column_request_t
  public :: fmr_divdra_serialized_binding_record_t
  public :: fmr_run_serialized_physical_multiswap_with_divdra

contains

  subroutine fmr_run_serialized_physical_multiswap_with_divdra(columns, templates, parameter_registry, forcing_registry, &
       state_registry, numerical_config, top_boundary, t0, t1, batch_size, divdra_requests, &
       distribution_parameter_registry, hydraulic_view_registry, results, diagnostics, aggregate, dispatch_status, &
       composition_status, divdra_records, runtime_diagnostics, receipt_column_ids, commit_receipts)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_template_t), intent(in) :: templates(:)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameter_registry(:)
    type(fmr_b110_physical_forcing_t), intent(inout) :: forcing_registry(:)
    type(kernel_committed_state_t), intent(inout) :: state_registry(:)
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    class(top_boundary_provider_t), target, intent(in) :: top_boundary
    real(real64), intent(in) :: t0, t1
    integer, intent(in) :: batch_size
    type(fmr_divdra_serialized_column_request_t), intent(in) :: divdra_requests(:)
    type(drainage_distribution_parameters_t), intent(in) :: distribution_parameter_registry(:)
    type(process_hydraulic_view_t), intent(in) :: hydraulic_view_registry(:)
    type(fmr_serialized_column_result_t), allocatable, intent(out) :: results(:)
    type(fmr_column_diagnostics_t), allocatable, intent(out) :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t), intent(out) :: aggregate
    integer, intent(out) :: dispatch_status
    integer, intent(out) :: composition_status
    type(fmr_divdra_serialized_binding_record_t), allocatable, intent(out) :: divdra_records(:)
    type(fmr_serialized_batch_diagnostics_t), intent(out), optional :: runtime_diagnostics
    integer(int64), intent(in), optional :: receipt_column_ids(:)
    type(fmr_serialized_commit_receipt_record_t), allocatable, intent(out), optional :: commit_receipts(:)

    type(fmr_divdra_binding_diagnostics_t) :: bind_diag
    type(fmr_divdra_multilevel_binding_diagnostics_t) :: multi_diag
    type(fmr_divdra_top_interflow_binding_diagnostics_t) :: topint_diag
    type(fmr_divdra_separate_infiltration_binding_diagnostics_t) :: inf_split_diag
    type(fmr_divdra_multi_inf_binding_diagnostics_t) :: multi_inf_diag
    type(drainage_distribution_parameters_t), allocatable :: level_parameters(:)
    type(drainage_distribution_parameters_t) :: single_parameter(1)
    real(real64) :: single_scalar(1)
    integer :: i, j, forcing_index, parameter_index, view_index, slot, top_status

    allocate(results(0), diagnostics(0))
    aggregate = fmr_aggregate_diagnostics_t()
    dispatch_status = FMR_SERIAL_DISPATCH_INVALID_REQUEST
    composition_status = FMR_DIVDRA_COMPOSE_OK
    if (present(runtime_diagnostics)) runtime_diagnostics = fmr_serialized_batch_diagnostics_t()
    if (present(commit_receipts)) allocate(commit_receipts(0))

    ! Complete preflight happens before the generic runtime initializes its
    ! backend or captures any committed-state checkpoint. This guarantees that
    ! expected DIVDRA composition errors are batch-transactional precommit.
    call fmr_preflight_serialized_divdra(columns, forcing_registry, divdra_requests, &
         distribution_parameter_registry, hydraulic_view_registry, divdra_records, composition_status)
    if (composition_status /= FMR_DIVDRA_COMPOSE_OK) return

    ! Materialize only feature-active rows. The canonical forcing registry is
    ! used as transient runtime-owned composition scratch and restored before
    ! every normal return from this routine. No full registry deep copy occurs.
    slot = 0
    do i = 1, size(columns)
      if (.not. divdra_requests(i)%active) cycle
      slot = slot + 1
      forcing_index = int(columns(i)%forcing_handle)
      view_index = int(divdra_requests(i)%hydraulic_view_ref)
      if(divdra_records(slot)%multilevel)then
        allocate(level_parameters(size(divdra_requests(i)%distribution_parameter_refs)))
        do j=1,size(level_parameters)
          level_parameters(j)=distribution_parameter_registry(int(divdra_requests(i)%distribution_parameter_refs(j)))
        end do
        if(divdra_requests(i)%separate_infiltration_active)then
          call fmr_bind_multilevel_separate_infiltration(level_parameters,hydraulic_view_registry(view_index), &
               divdra_requests(i)%scalar_transfers,divdra_requests(i)%separate_infiltration_drain_bottom_cm_by_level, &
               divdra_requests(i)%separate_infiltration_surface_water_level_cm_by_level, &
               divdra_requests(i)%separate_infiltration_depth_factor, &
               forcing_registry(forcing_index)%drainage_flux_by_level,multi_inf_diag)
          divdra_records(slot)%multilevel_separate_infiltration_binding=multi_inf_diag
          if(multi_inf_diag%status/=FMR_DIVDRA_MULTI_INF_OK)then
            composition_status=FMR_DIVDRA_COMPOSE_BIND_REJECTED
            divdra_records(slot)%composition_status=composition_status
            deallocate(level_parameters)
            call cleanup_materialized_divdra(columns,divdra_requests,forcing_registry)
            return
          end if
        else if(divdra_requests(i)%highest_interflow_active)then
          call fmr_bind_highest_interflow_signed_divdra(level_parameters,hydraulic_view_registry(view_index), &
               divdra_requests(i)%scalar_transfers,divdra_requests(i)%highest_interflow_drain_bottom_cm, &
               forcing_registry(forcing_index)%drainage_flux_by_level,topint_diag)
          divdra_records(slot)%top_interflow_binding=topint_diag
          if(topint_diag%status/=FMR_DIVDRA_TOPINT_OK)then
            composition_status=FMR_DIVDRA_COMPOSE_BIND_REJECTED
            divdra_records(slot)%composition_status=composition_status
            call cleanup_materialized_divdra(columns,divdra_requests,forcing_registry)
            return
          end if
        else
          call fmr_bind_multilevel_signed_divdra(level_parameters,hydraulic_view_registry(view_index), &
               divdra_requests(i)%scalar_transfers,forcing_registry(forcing_index)%drainage_flux_by_level,multi_diag)
          divdra_records(slot)%multilevel_binding=multi_diag
          if(multi_diag%status/=FMR_DIVDRA_BIND_OK)then
            composition_status=FMR_DIVDRA_COMPOSE_BIND_REJECTED
            divdra_records(slot)%composition_status=composition_status
            call cleanup_materialized_divdra(columns,divdra_requests,forcing_registry)
            return
          end if
        end if
        if(allocated(divdra_requests(i)%top_layer_controls).and..not.divdra_requests(i)%separate_infiltration_active)then
          call apply_fmr_divdra_discharge_top_controls(level_parameters,hydraulic_view_registry(view_index), &
               divdra_requests(i)%scalar_transfers,divdra_requests(i)%top_layer_controls, &
               forcing_registry(forcing_index)%drainage_flux_by_level,divdra_records(slot)%top_diagnostics,top_status)
          if(top_status/=FMR_DIVDRA_TOP_OK)then
            composition_status=FMR_DIVDRA_COMPOSE_BIND_REJECTED
            divdra_records(slot)%composition_status=composition_status
            deallocate(level_parameters)
            call cleanup_materialized_divdra(columns,divdra_requests,forcing_registry)
            return
          end if
        end if
        deallocate(level_parameters)
      else
        parameter_index = int(divdra_requests(i)%distribution_parameter_ref)
        if(divdra_requests(i)%separate_infiltration_active)then
          call fmr_bind_single_level_separate_infiltration(distribution_parameter_registry(parameter_index), &
               hydraulic_view_registry(view_index),divdra_requests(i)%scalar_transfer, &
               divdra_requests(i)%separate_infiltration_drain_bottom_cm, &
               divdra_requests(i)%separate_infiltration_surface_water_level_cm, &
               divdra_requests(i)%separate_infiltration_depth_factor, &
               forcing_registry(forcing_index)%drainage_flux_by_level,inf_split_diag)
          divdra_records(slot)%separate_infiltration_binding=inf_split_diag
          if(inf_split_diag%status/=FMR_DIVDRA_INF_SPLIT_OK)then
            composition_status=FMR_DIVDRA_COMPOSE_BIND_REJECTED
            divdra_records(slot)%composition_status=composition_status
            call cleanup_materialized_divdra(columns,divdra_requests,forcing_registry)
            return
          end if
        else
          call fmr_bind_single_level_signed_divdra(distribution_parameter_registry(parameter_index), &
               hydraulic_view_registry(view_index), divdra_requests(i)%scalar_transfer, &
               forcing_registry(forcing_index)%drainage_flux_by_level, bind_diag)
          divdra_records(slot)%binding = bind_diag
          if (bind_diag%status /= FMR_DIVDRA_BIND_OK) then
            composition_status = FMR_DIVDRA_COMPOSE_BIND_REJECTED
            divdra_records(slot)%composition_status = composition_status
            call cleanup_materialized_divdra(columns, divdra_requests, forcing_registry)
            return
          end if
        end if
        if(allocated(divdra_requests(i)%top_layer_controls))then
          single_parameter(1)=distribution_parameter_registry(parameter_index)
          single_scalar(1)=divdra_requests(i)%scalar_transfer
          call apply_fmr_divdra_discharge_top_controls(single_parameter,hydraulic_view_registry(view_index),single_scalar, &
               divdra_requests(i)%top_layer_controls,forcing_registry(forcing_index)%drainage_flux_by_level, &
               divdra_records(slot)%top_diagnostics,top_status)
          if(top_status/=FMR_DIVDRA_TOP_OK)then
            composition_status=FMR_DIVDRA_COMPOSE_BIND_REJECTED
            divdra_records(slot)%composition_status=composition_status
            call cleanup_materialized_divdra(columns,divdra_requests,forcing_registry)
            return
          end if
        end if
      end if
    end do

    call fmr_run_serialized_physical_multiswap(columns, templates, parameter_registry, forcing_registry, &
         state_registry, numerical_config, top_boundary, t0, t1, batch_size, results, diagnostics, aggregate, &
         dispatch_status, runtime_diagnostics, receipt_column_ids, commit_receipts)

    call cleanup_materialized_divdra(columns, divdra_requests, forcing_registry)
    composition_status = FMR_DIVDRA_COMPOSE_OK
  end subroutine fmr_run_serialized_physical_multiswap_with_divdra

  subroutine cleanup_materialized_divdra(columns, requests, forcing_registry)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_divdra_serialized_column_request_t), intent(in) :: requests(:)
    type(fmr_b110_physical_forcing_t), intent(inout) :: forcing_registry(:)
    integer :: i, forcing_index

    do i = 1, min(size(columns), size(requests))
      if (.not. requests(i)%active) cycle
      if (columns(i)%forcing_handle < 1_int64 .or. &
          columns(i)%forcing_handle > int(size(forcing_registry), int64)) cycle
      forcing_index = int(columns(i)%forcing_handle)
      if (allocated(forcing_registry(forcing_index)%drainage_flux_by_level)) &
           deallocate(forcing_registry(forcing_index)%drainage_flux_by_level)
    end do
  end subroutine cleanup_materialized_divdra

end module mod_fmr_divdra_serialized_runtime
