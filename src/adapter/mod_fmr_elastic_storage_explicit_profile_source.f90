module mod_fmr_elastic_storage_explicit_profile_source
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_elastic_storage_staringseriesblock_map, only: &
       fmr_map_staringseriesblock_to_catalog, FMR_STARINGSERIESBLOCK_OK
  use mod_fmr_elastic_storage_staringreeks_catalog, only: &
       fmr_lookup_staringreeks_retention, FMR_STARINGREEKS_CATALOG_OK
  use mod_fmr_elastic_storage_horizon_descriptor_builder, only: &
       fmr_elastic_storage_retention_t, fmr_build_elastic_storage_horizon_descriptor, &
       FMR_ELAS_DESCRIPTOR_OK
  use mod_fmr_elastic_storage_horizon_node_mapper, only: &
       fmr_elastic_storage_horizon_t, FMR_ELAS_GEOMETRY_TOL_M
  implicit none
  private

  integer, parameter, public :: FMR_ELAS_PROFILE_SOURCE_OK = 0
  integer, parameter, public :: FMR_ELAS_PROFILE_SOURCE_INVALID_REQUEST = 1
  integer, parameter, public :: FMR_ELAS_PROFILE_SOURCE_NOT_FOUND = 2
  integer, parameter, public :: FMR_ELAS_PROFILE_SOURCE_INVALID_STRUCTURE = 3
  integer, parameter, public :: FMR_ELAS_PROFILE_SOURCE_BLOCK_REJECTED = 4
  integer, parameter, public :: FMR_ELAS_PROFILE_SOURCE_CATALOG_REJECTED = 5
  integer, parameter, public :: FMR_ELAS_PROFILE_SOURCE_DESCRIPTOR_REJECTED = 6

  type, public :: fmr_elastic_storage_bro_horizon_row_t
    integer :: normalsoilprofile_id = 0
    integer :: layer_number = 0
    real(real64) :: top_depth_m = 0.0_real64
    real(real64) :: bottom_depth_m = 0.0_real64
    integer :: staringseriesblock = 0
    real(real64) :: rho_dry_g_cm3 = 0.0_real64
    logical :: organic_matter_available = .false.
    real(real64) :: organic_matter_pct = 0.0_real64
    logical :: peat_type_present = .false.
  end type fmr_elastic_storage_bro_horizon_row_t

  type, public :: fmr_elastic_storage_profile_source_diagnostics_t
    integer :: status = FMR_ELAS_PROFILE_SOURCE_INVALID_REQUEST
    integer :: selected_profile_id = 0
    integer :: selected_rows = 0
    integer :: failed_input_row = 0
    integer :: failed_layer_number = 0
    integer :: nested_status = 0
    logical :: structure_valid = .false.
    logical :: assembly_complete = .false.
  end type fmr_elastic_storage_profile_source_diagnostics_t

  public :: fmr_build_explicit_bro_profile_horizons

contains

  subroutine fmr_build_explicit_bro_profile_horizons(rows, requested_profile_id, horizons, &
                                                       layer_numbers, catalog_indices, diagnostics)
    type(fmr_elastic_storage_bro_horizon_row_t), intent(in) :: rows(:)
    integer, intent(in) :: requested_profile_id
    type(fmr_elastic_storage_horizon_t), allocatable, intent(out) :: horizons(:)
    integer, allocatable, intent(out) :: layer_numbers(:)
    integer, allocatable, intent(out) :: catalog_indices(:)
    type(fmr_elastic_storage_profile_source_diagnostics_t), intent(out) :: diagnostics

    type(fmr_elastic_storage_retention_t) :: retention
    character(len=3) :: code
    integer :: i, k, count_selected, map_status, catalog_status, descriptor_status, catalog_index
    integer :: expected_layer
    real(real64) :: previous_bottom

    if (allocated(horizons)) deallocate(horizons)
    if (allocated(layer_numbers)) deallocate(layer_numbers)
    if (allocated(catalog_indices)) deallocate(catalog_indices)
    diagnostics = fmr_elastic_storage_profile_source_diagnostics_t()
    diagnostics%selected_profile_id = requested_profile_id

    if (requested_profile_id <= 0) return
    if (size(rows) <= 0) then
      diagnostics%status = FMR_ELAS_PROFILE_SOURCE_NOT_FOUND
      return
    end if

    count_selected = count([(rows(i)%normalsoilprofile_id == requested_profile_id, i=1,size(rows))])
    diagnostics%selected_rows = count_selected
    if (count_selected <= 0) then
      diagnostics%status = FMR_ELAS_PROFILE_SOURCE_NOT_FOUND
      return
    end if

    expected_layer = 1
    previous_bottom = 0.0_real64
    k = 0
    do i = 1, size(rows)
      if (rows(i)%normalsoilprofile_id /= requested_profile_id) cycle
      k = k + 1
      if (rows(i)%layer_number /= expected_layer) then
        diagnostics%status = FMR_ELAS_PROFILE_SOURCE_INVALID_STRUCTURE
        diagnostics%failed_input_row = i
        diagnostics%failed_layer_number = rows(i)%layer_number
        return
      end if
      if (expected_layer == 1) then
        if (abs(rows(i)%top_depth_m) > FMR_ELAS_GEOMETRY_TOL_M) then
          diagnostics%status = FMR_ELAS_PROFILE_SOURCE_INVALID_STRUCTURE
          diagnostics%failed_input_row = i
          diagnostics%failed_layer_number = rows(i)%layer_number
          return
        end if
      else
        if (abs(rows(i)%top_depth_m - previous_bottom) > FMR_ELAS_GEOMETRY_TOL_M) then
          diagnostics%status = FMR_ELAS_PROFILE_SOURCE_INVALID_STRUCTURE
          diagnostics%failed_input_row = i
          diagnostics%failed_layer_number = rows(i)%layer_number
          return
        end if
      end if
      previous_bottom = rows(i)%bottom_depth_m
      expected_layer = expected_layer + 1
    end do
    diagnostics%structure_valid = .true.

    allocate(horizons(count_selected), layer_numbers(count_selected), catalog_indices(count_selected))
    k = 0
    do i = 1, size(rows)
      if (rows(i)%normalsoilprofile_id /= requested_profile_id) cycle
      k = k + 1

      call fmr_map_staringseriesblock_to_catalog(rows(i)%staringseriesblock, code, catalog_index, map_status)
      if (map_status /= FMR_STARINGSERIESBLOCK_OK) then
        call fail_atomic(FMR_ELAS_PROFILE_SOURCE_BLOCK_REJECTED, i, rows(i)%layer_number, map_status, &
             horizons, layer_numbers, catalog_indices, diagnostics)
        return
      end if

      call fmr_lookup_staringreeks_retention(code, retention, catalog_indices(k), catalog_status)
      if (catalog_status /= FMR_STARINGREEKS_CATALOG_OK .or. catalog_indices(k) /= catalog_index) then
        call fail_atomic(FMR_ELAS_PROFILE_SOURCE_CATALOG_REJECTED, i, rows(i)%layer_number, catalog_status, &
             horizons, layer_numbers, catalog_indices, diagnostics)
        return
      end if

      call fmr_build_elastic_storage_horizon_descriptor(rows(i)%top_depth_m, rows(i)%bottom_depth_m, &
           rows(i)%rho_dry_g_cm3, rows(i)%organic_matter_available, rows(i)%organic_matter_pct, &
           rows(i)%peat_type_present, retention, horizons(k), descriptor_status)
      if (descriptor_status /= FMR_ELAS_DESCRIPTOR_OK) then
        call fail_atomic(FMR_ELAS_PROFILE_SOURCE_DESCRIPTOR_REJECTED, i, rows(i)%layer_number, descriptor_status, &
             horizons, layer_numbers, catalog_indices, diagnostics)
        return
      end if

      layer_numbers(k) = rows(i)%layer_number
    end do

    diagnostics%status = FMR_ELAS_PROFILE_SOURCE_OK
    diagnostics%assembly_complete = .true.
  end subroutine fmr_build_explicit_bro_profile_horizons

  subroutine fail_atomic(status, input_row, layer_number, nested_status, horizons, layer_numbers, &
                         catalog_indices, diagnostics)
    integer, intent(in) :: status, input_row, layer_number, nested_status
    type(fmr_elastic_storage_horizon_t), allocatable, intent(inout) :: horizons(:)
    integer, allocatable, intent(inout) :: layer_numbers(:), catalog_indices(:)
    type(fmr_elastic_storage_profile_source_diagnostics_t), intent(inout) :: diagnostics

    if (allocated(horizons)) deallocate(horizons)
    if (allocated(layer_numbers)) deallocate(layer_numbers)
    if (allocated(catalog_indices)) deallocate(catalog_indices)
    diagnostics%status = status
    diagnostics%failed_input_row = input_row
    diagnostics%failed_layer_number = layer_number
    diagnostics%nested_status = nested_status
    diagnostics%assembly_complete = .false.
  end subroutine fail_atomic

end module mod_fmr_elastic_storage_explicit_profile_source
