module mod_fmr_divdra_serialized_composition
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_fmr_runtime_core, only: fmr_logical_column_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_fmr_divdra_runtime_binding, only: fmr_divdra_binding_diagnostics_t, &
       fmr_divdra_multilevel_binding_diagnostics_t, fmr_bind_single_level_signed_divdra, &
       fmr_bind_multilevel_signed_divdra, FMR_DIVDRA_BIND_OK
  use mod_drainage_discharge_layer_top, only: drainage_discharge_layer_top_control_t, &
       drainage_discharge_layer_top_diagnostics_t
  use mod_fmr_divdra_discharge_top_binding, only: apply_fmr_divdra_discharge_top_controls, FMR_DIVDRA_TOP_OK
  use mod_fmr_divdra_top_interflow_binding, only: fmr_divdra_top_interflow_binding_diagnostics_t, &
       fmr_bind_highest_interflow_signed_divdra, FMR_DIVDRA_TOPINT_OK
  use mod_fmr_divdra_separate_infiltration_binding, only: fmr_divdra_separate_infiltration_binding_diagnostics_t, &
       fmr_bind_single_level_separate_infiltration, FMR_DIVDRA_INF_SPLIT_OK
  use mod_fmr_divdra_multilevel_separate_infiltration_binding, only: &
       fmr_divdra_multi_inf_binding_diagnostics_t, &
       fmr_bind_multilevel_separate_infiltration, FMR_DIVDRA_MULTI_INF_OK
  implicit none
  private

  integer, parameter, public :: FMR_DIVDRA_COMPOSE_OK = 0
  integer, parameter, public :: FMR_DIVDRA_COMPOSE_INVALID_SHAPE = 1
  integer, parameter, public :: FMR_DIVDRA_COMPOSE_COLUMN_ID_MISMATCH = 2
  integer, parameter, public :: FMR_DIVDRA_COMPOSE_INVALID_FORCING_HANDLE = 3
  integer, parameter, public :: FMR_DIVDRA_COMPOSE_SHARED_FORCING_HANDLE = 4
  integer, parameter, public :: FMR_DIVDRA_COMPOSE_INVALID_PARAMETER_REF = 5
  integer, parameter, public :: FMR_DIVDRA_COMPOSE_INVALID_HYDRAULIC_VIEW_REF = 6
  integer, parameter, public :: FMR_DIVDRA_COMPOSE_BIND_REJECTED = 7

  type, public :: fmr_divdra_serialized_column_request_t
    integer(int64) :: column_id = 0_int64
    logical :: active = .false.
    integer(int64) :: distribution_parameter_ref = 0_int64
    integer(int64) :: hydraulic_view_ref = 0_int64
    real(real64) :: scalar_transfer = 0.0_real64
    integer(int64), allocatable :: distribution_parameter_refs(:)
    real(real64), allocatable :: scalar_transfers(:)
    type(drainage_discharge_layer_top_control_t), allocatable :: top_layer_controls(:)
    logical :: highest_interflow_active = .false.
    real(real64) :: highest_interflow_drain_bottom_cm = 0.0_real64
    logical :: separate_infiltration_active = .false.
    real(real64) :: separate_infiltration_drain_bottom_cm = 0.0_real64
    real(real64) :: separate_infiltration_surface_water_level_cm = 0.0_real64
    real(real64), allocatable :: separate_infiltration_drain_bottom_cm_by_level(:)
    real(real64), allocatable :: separate_infiltration_surface_water_level_cm_by_level(:)
    real(real64) :: separate_infiltration_depth_factor = 0.5_real64
  end type fmr_divdra_serialized_column_request_t

  type, public :: fmr_divdra_serialized_binding_record_t
    integer(int64) :: column_id = 0_int64
    integer :: column_index = 0
    integer(int64) :: forcing_handle = 0_int64
    integer :: composition_status = FMR_DIVDRA_COMPOSE_OK
    type(fmr_divdra_binding_diagnostics_t) :: binding
    logical :: multilevel = .false.
    type(fmr_divdra_multilevel_binding_diagnostics_t) :: multilevel_binding
    type(drainage_discharge_layer_top_diagnostics_t), allocatable :: top_diagnostics(:)
    type(fmr_divdra_top_interflow_binding_diagnostics_t) :: top_interflow_binding
    type(fmr_divdra_separate_infiltration_binding_diagnostics_t) :: separate_infiltration_binding
    type(fmr_divdra_multi_inf_binding_diagnostics_t) :: multilevel_separate_infiltration_binding
  end type fmr_divdra_serialized_binding_record_t

  public :: fmr_preflight_serialized_divdra

contains

  subroutine fmr_preflight_serialized_divdra(columns, forcing_registry, requests, distribution_parameters, &
       hydraulic_views, records, status)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing_registry(:)
    type(fmr_divdra_serialized_column_request_t), intent(in) :: requests(:)
    type(drainage_distribution_parameters_t), intent(in) :: distribution_parameters(:)
    type(process_hydraulic_view_t), intent(in) :: hydraulic_views(:)
    type(fmr_divdra_serialized_binding_record_t), allocatable, intent(out) :: records(:)
    integer, intent(out) :: status

    integer, allocatable :: forcing_use_count(:)
    real(real64), allocatable :: probe(:,:)
    type(fmr_divdra_binding_diagnostics_t) :: bind_diag
    type(fmr_divdra_multilevel_binding_diagnostics_t) :: multi_diag
    type(fmr_divdra_top_interflow_binding_diagnostics_t) :: topint_diag
    type(fmr_divdra_separate_infiltration_binding_diagnostics_t) :: inf_split_diag
    type(fmr_divdra_multi_inf_binding_diagnostics_t) :: multi_inf_diag
    type(drainage_distribution_parameters_t), allocatable :: level_parameters(:)
    type(drainage_distribution_parameters_t) :: single_parameter(1)
    real(real64) :: single_scalar(1)
    integer :: i, j, active_count, slot, forcing_index, parameter_index, view_index, top_status
    logical :: multilevel

    status = FMR_DIVDRA_COMPOSE_OK
    allocate(records(0))

    if (size(requests) /= size(columns)) then
      status = FMR_DIVDRA_COMPOSE_INVALID_SHAPE
      return
    end if

    allocate(forcing_use_count(size(forcing_registry)))
    forcing_use_count = 0
    do i = 1, size(columns)
      if (columns(i)%forcing_handle >= 1_int64 .and. &
          columns(i)%forcing_handle <= int(size(forcing_registry), int64)) then
        forcing_index = int(columns(i)%forcing_handle)
        forcing_use_count(forcing_index) = forcing_use_count(forcing_index) + 1
      end if
    end do

    do i = 1, size(columns)
      if (requests(i)%column_id /= columns(i)%column_id) then
        status = FMR_DIVDRA_COMPOSE_COLUMN_ID_MISMATCH
        return
      end if
    end do

    active_count = count(requests%active)
    deallocate(records)
    allocate(records(active_count))
    slot = 0

    do i = 1, size(columns)
      if (.not. requests(i)%active) cycle
      slot = slot + 1
      records(slot)%column_id = columns(i)%column_id
      records(slot)%column_index = i
      records(slot)%forcing_handle = columns(i)%forcing_handle

      if (columns(i)%forcing_handle < 1_int64 .or. &
          columns(i)%forcing_handle > int(size(forcing_registry), int64)) then
        status = FMR_DIVDRA_COMPOSE_INVALID_FORCING_HANDLE
        records(slot)%composition_status = status
        return
      end if
      forcing_index = int(columns(i)%forcing_handle)
      if (forcing_use_count(forcing_index) /= 1) then
        status = FMR_DIVDRA_COMPOSE_SHARED_FORCING_HANDLE
        records(slot)%composition_status = status
        return
      end if

      multilevel=allocated(requests(i)%distribution_parameter_refs).or.allocated(requests(i)%scalar_transfers)
      if(multilevel)then
        if(.not.allocated(requests(i)%distribution_parameter_refs).or..not.allocated(requests(i)%scalar_transfers))then
          status=FMR_DIVDRA_COMPOSE_INVALID_PARAMETER_REF
          records(slot)%composition_status=status
          return
        end if
        if(size(requests(i)%distribution_parameter_refs)<=1.or. &
             size(requests(i)%distribution_parameter_refs)/=size(requests(i)%scalar_transfers))then
          status=FMR_DIVDRA_COMPOSE_INVALID_PARAMETER_REF
          records(slot)%composition_status=status
          return
        end if
        if(allocated(level_parameters))deallocate(level_parameters)
        allocate(level_parameters(size(requests(i)%distribution_parameter_refs)))
        do j=1,size(level_parameters)
          if(requests(i)%distribution_parameter_refs(j)<1_int64.or. &
               requests(i)%distribution_parameter_refs(j)>int(size(distribution_parameters),int64))then
            status=FMR_DIVDRA_COMPOSE_INVALID_PARAMETER_REF
            records(slot)%composition_status=status
            return
          end if
          level_parameters(j)=distribution_parameters(int(requests(i)%distribution_parameter_refs(j)))
        end do
      else
        if (requests(i)%distribution_parameter_ref < 1_int64 .or. &
            requests(i)%distribution_parameter_ref > int(size(distribution_parameters), int64)) then
          status = FMR_DIVDRA_COMPOSE_INVALID_PARAMETER_REF
          records(slot)%composition_status = status
          return
        end if
        parameter_index = int(requests(i)%distribution_parameter_ref)
      end if

      if (requests(i)%hydraulic_view_ref < 1_int64 .or. &
          requests(i)%hydraulic_view_ref > int(size(hydraulic_views), int64)) then
        status = FMR_DIVDRA_COMPOSE_INVALID_HYDRAULIC_VIEW_REF
        records(slot)%composition_status = status
        return
      end if
      view_index = int(requests(i)%hydraulic_view_ref)

      if (allocated(probe)) deallocate(probe)
      if (allocated(forcing_registry(forcing_index)%drainage_flux_by_level)) then
        allocate(probe(size(forcing_registry(forcing_index)%drainage_flux_by_level, 1), &
                       size(forcing_registry(forcing_index)%drainage_flux_by_level, 2)))
        probe = forcing_registry(forcing_index)%drainage_flux_by_level
      end if

      records(slot)%multilevel=multilevel
      if(requests(i)%highest_interflow_active.and..not.multilevel)then
        status=FMR_DIVDRA_COMPOSE_INVALID_SHAPE
        records(slot)%composition_status=status
        return
      end if
      if(multilevel)then
        if(requests(i)%separate_infiltration_active)then
          if(requests(i)%highest_interflow_active.or.allocated(requests(i)%top_layer_controls))then
            status=FMR_DIVDRA_COMPOSE_INVALID_SHAPE
            records(slot)%composition_status=status
            return
          end if
          if(.not.allocated(requests(i)%separate_infiltration_drain_bottom_cm_by_level).or. &
               .not.allocated(requests(i)%separate_infiltration_surface_water_level_cm_by_level).or. &
               size(requests(i)%separate_infiltration_drain_bottom_cm_by_level)/=size(level_parameters).or. &
               size(requests(i)%separate_infiltration_surface_water_level_cm_by_level)/=size(level_parameters))then
            status=FMR_DIVDRA_COMPOSE_INVALID_SHAPE
            records(slot)%composition_status=status
            return
          end if
          call fmr_bind_multilevel_separate_infiltration(level_parameters,hydraulic_views(view_index), &
               requests(i)%scalar_transfers,requests(i)%separate_infiltration_drain_bottom_cm_by_level, &
               requests(i)%separate_infiltration_surface_water_level_cm_by_level, &
               requests(i)%separate_infiltration_depth_factor,probe,multi_inf_diag)
          records(slot)%multilevel_separate_infiltration_binding=multi_inf_diag
          if(multi_inf_diag%status/=FMR_DIVDRA_MULTI_INF_OK)then
            status=FMR_DIVDRA_COMPOSE_BIND_REJECTED
            records(slot)%composition_status=status
            return
          end if
        else if(requests(i)%highest_interflow_active)then
          call fmr_bind_highest_interflow_signed_divdra(level_parameters,hydraulic_views(view_index), &
               requests(i)%scalar_transfers,requests(i)%highest_interflow_drain_bottom_cm,probe,topint_diag)
          records(slot)%top_interflow_binding=topint_diag
          if(topint_diag%status/=FMR_DIVDRA_TOPINT_OK)then
            status=FMR_DIVDRA_COMPOSE_BIND_REJECTED
            records(slot)%composition_status=status
            return
          end if
        else
          call fmr_bind_multilevel_signed_divdra(level_parameters,hydraulic_views(view_index), &
               requests(i)%scalar_transfers,probe,multi_diag)
          records(slot)%multilevel_binding=multi_diag
          if(multi_diag%status/=FMR_DIVDRA_BIND_OK)then
            status=FMR_DIVDRA_COMPOSE_BIND_REJECTED
            records(slot)%composition_status=status
            return
          end if
        end if
        if(allocated(requests(i)%top_layer_controls).and..not.requests(i)%separate_infiltration_active)then
          if(size(requests(i)%top_layer_controls)/=size(level_parameters))then
            status=FMR_DIVDRA_COMPOSE_INVALID_SHAPE
            records(slot)%composition_status=status
            return
          end if
          call apply_fmr_divdra_discharge_top_controls(level_parameters,hydraulic_views(view_index), &
               requests(i)%scalar_transfers,requests(i)%top_layer_controls,probe,records(slot)%top_diagnostics,top_status)
          if(top_status/=FMR_DIVDRA_TOP_OK)then
            status=FMR_DIVDRA_COMPOSE_BIND_REJECTED
            records(slot)%composition_status=status
            return
          end if
        end if
        deallocate(level_parameters)
      else
        if(requests(i)%separate_infiltration_active)then
          call fmr_bind_single_level_separate_infiltration(distribution_parameters(parameter_index), &
               hydraulic_views(view_index),requests(i)%scalar_transfer,requests(i)%separate_infiltration_drain_bottom_cm, &
               requests(i)%separate_infiltration_surface_water_level_cm,requests(i)%separate_infiltration_depth_factor, &
               probe,inf_split_diag)
          records(slot)%separate_infiltration_binding=inf_split_diag
          if(inf_split_diag%status/=FMR_DIVDRA_INF_SPLIT_OK)then
            status=FMR_DIVDRA_COMPOSE_BIND_REJECTED
            records(slot)%composition_status=status
            return
          end if
        else
          call fmr_bind_single_level_signed_divdra(distribution_parameters(parameter_index), hydraulic_views(view_index), &
               requests(i)%scalar_transfer, probe, bind_diag)
          records(slot)%binding = bind_diag
          if (bind_diag%status /= FMR_DIVDRA_BIND_OK) then
            status = FMR_DIVDRA_COMPOSE_BIND_REJECTED
            records(slot)%composition_status = status
            return
          end if
        end if
        if(allocated(requests(i)%top_layer_controls))then
          if(size(requests(i)%top_layer_controls)/=1)then
            status=FMR_DIVDRA_COMPOSE_INVALID_SHAPE
            records(slot)%composition_status=status
            return
          end if
          single_parameter(1)=distribution_parameters(parameter_index)
          single_scalar(1)=requests(i)%scalar_transfer
          call apply_fmr_divdra_discharge_top_controls(single_parameter,hydraulic_views(view_index),single_scalar, &
               requests(i)%top_layer_controls,probe,records(slot)%top_diagnostics,top_status)
          if(top_status/=FMR_DIVDRA_TOP_OK)then
            status=FMR_DIVDRA_COMPOSE_BIND_REJECTED
            records(slot)%composition_status=status
            return
          end if
        end if
      end if
      records(slot)%composition_status = FMR_DIVDRA_COMPOSE_OK
    end do
  end subroutine fmr_preflight_serialized_divdra

end module mod_fmr_divdra_serialized_composition
