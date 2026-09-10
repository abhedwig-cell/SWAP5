module mod_fmr_divdra_serialized_composition
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_fmr_runtime_core, only: fmr_logical_column_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_fmr_divdra_runtime_binding, only: fmr_divdra_binding_diagnostics_t, &
       fmr_bind_single_level_positive_divdra, FMR_DIVDRA_BIND_OK
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
  end type fmr_divdra_serialized_column_request_t

  type, public :: fmr_divdra_serialized_binding_record_t
    integer(int64) :: column_id = 0_int64
    integer :: column_index = 0
    integer(int64) :: forcing_handle = 0_int64
    integer :: composition_status = FMR_DIVDRA_COMPOSE_OK
    type(fmr_divdra_binding_diagnostics_t) :: binding
  end type fmr_divdra_serialized_binding_record_t

  public :: fmr_preflight_serialized_divdra
  public :: fmr_materialize_serialized_divdra_forcing

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
    integer :: i, active_count, slot, forcing_index, parameter_index, view_index

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

      if (requests(i)%distribution_parameter_ref < 1_int64 .or. &
          requests(i)%distribution_parameter_ref > int(size(distribution_parameters), int64)) then
        status = FMR_DIVDRA_COMPOSE_INVALID_PARAMETER_REF
        records(slot)%composition_status = status
        return
      end if
      parameter_index = int(requests(i)%distribution_parameter_ref)

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

      call fmr_bind_single_level_positive_divdra(distribution_parameters(parameter_index), hydraulic_views(view_index), &
           requests(i)%scalar_transfer, probe, bind_diag)
      records(slot)%binding = bind_diag
      if (bind_diag%status /= FMR_DIVDRA_BIND_OK) then
        status = FMR_DIVDRA_COMPOSE_BIND_REJECTED
        records(slot)%composition_status = status
        return
      end if
      records(slot)%composition_status = FMR_DIVDRA_COMPOSE_OK
    end do
  end subroutine fmr_preflight_serialized_divdra

  subroutine fmr_materialize_serialized_divdra_forcing(source_forcing, request, distribution_parameters, hydraulic_views, &
       effective_forcing, diagnostics, status)
    type(fmr_b110_physical_forcing_t), intent(in) :: source_forcing
    type(fmr_divdra_serialized_column_request_t), intent(in) :: request
    type(drainage_distribution_parameters_t), intent(in) :: distribution_parameters(:)
    type(process_hydraulic_view_t), intent(in) :: hydraulic_views(:)
    type(fmr_b110_physical_forcing_t), intent(out) :: effective_forcing
    type(fmr_divdra_binding_diagnostics_t), intent(out) :: diagnostics
    integer, intent(out) :: status

    integer :: parameter_index, view_index

    effective_forcing = source_forcing
    diagnostics = fmr_divdra_binding_diagnostics_t()
    status = FMR_DIVDRA_COMPOSE_OK

    if (.not. request%active) return

    if (request%distribution_parameter_ref < 1_int64 .or. &
        request%distribution_parameter_ref > int(size(distribution_parameters), int64)) then
      status = FMR_DIVDRA_COMPOSE_INVALID_PARAMETER_REF
      return
    end if
    parameter_index = int(request%distribution_parameter_ref)

    if (request%hydraulic_view_ref < 1_int64 .or. &
        request%hydraulic_view_ref > int(size(hydraulic_views), int64)) then
      status = FMR_DIVDRA_COMPOSE_INVALID_HYDRAULIC_VIEW_REF
      return
    end if
    view_index = int(request%hydraulic_view_ref)

    call fmr_bind_single_level_positive_divdra(distribution_parameters(parameter_index), hydraulic_views(view_index), &
         request%scalar_transfer, effective_forcing%drainage_flux_by_level, diagnostics)
    if (diagnostics%status /= FMR_DIVDRA_BIND_OK) status = FMR_DIVDRA_COMPOSE_BIND_REJECTED
  end subroutine fmr_materialize_serialized_divdra_forcing

end module mod_fmr_divdra_serialized_composition
