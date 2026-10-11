module mod_fmr_elastic_storage_row_application_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t
  use mod_fmr_elastic_storage_row_interchange_file_adapter, only: &
       fmr_elastic_storage_row_file_diagnostics_t, fmr_read_elastic_storage_row_interchange_file, &
       FMR_ELAS_ROWS_FILE_OK
  use mod_fmr_elastic_storage_explicit_profile_source, only: &
       fmr_elastic_storage_bro_horizon_row_t, fmr_elastic_storage_profile_source_diagnostics_t, &
       fmr_build_explicit_bro_profile_horizons, FMR_ELAS_PROFILE_SOURCE_OK
  use mod_fmr_elastic_storage_swap_grid_normalization, only: &
       fmr_elastic_storage_grid_diagnostics_t, fmr_normalize_swap_grid_geometry, &
       FMR_ELAS_GRID_OK, FMR_ELAS_GRID_INVALID_SHAPE
  use mod_fmr_elastic_storage_horizon_node_mapper, only: &
       fmr_elastic_storage_horizon_t, fmr_elastic_storage_mapping_diagnostics_t, &
       fmr_map_elastic_storage_horizons_to_nodes, FMR_ELAS_MAP_OK
  use mod_fmr_elastic_storage_descriptor_assembly, only: &
       fmr_elastic_storage_descriptor_t, fmr_elastic_storage_assembly_diagnostics_t, &
       fmr_assemble_generated_elastic_storage, FMR_ELAS_ASSEMBLY_OK
  implicit none
  private

  integer, parameter, public :: FMR_ELAS_ROW_APP_OK = 0
  integer, parameter, public :: FMR_ELAS_ROW_APP_INACTIVE = 1
  integer, parameter, public :: FMR_ELAS_ROW_APP_ROW_FILE_REJECTED = 2
  integer, parameter, public :: FMR_ELAS_ROW_APP_PROFILE_REJECTED = 3
  integer, parameter, public :: FMR_ELAS_ROW_APP_GRID_REJECTED = 4
  integer, parameter, public :: FMR_ELAS_ROW_APP_MAP_REJECTED = 5
  integer, parameter, public :: FMR_ELAS_ROW_APP_ASSEMBLY_REJECTED = 6

  type, public :: fmr_elastic_storage_row_application_diagnostics_t
    integer :: status = FMR_ELAS_ROW_APP_INACTIVE
    integer :: row_file_status = 0
    integer :: profile_status = 0
    integer :: grid_status = 0
    integer :: map_status = 0
    integer :: assembly_status = 0
    integer :: selected_profile_id = 0
    logical :: request_present = .false.
    logical :: generated_prior_applied = .false.
  end type fmr_elastic_storage_row_application_diagnostics_t

  public :: fmr_bind_elastic_storage_from_row_interchange

contains

  subroutine fmr_bind_elastic_storage_from_row_interchange(path, generated_prior_requested, base_parameters, &
                                                            bound_parameters, diagnostics)
    character(len=*), intent(in) :: path
    logical, intent(in) :: generated_prior_requested
    type(fmr_b110_physical_parameters_t), intent(in) :: base_parameters
    type(fmr_b110_physical_parameters_t), intent(out) :: bound_parameters
    type(fmr_elastic_storage_row_application_diagnostics_t), intent(out) :: diagnostics

    type(fmr_elastic_storage_bro_horizon_row_t), allocatable :: rows(:)
    type(fmr_elastic_storage_horizon_t), allocatable :: horizons(:)
    type(fmr_elastic_storage_descriptor_t), allocatable :: descriptors(:)
    real(real64), allocatable :: node_depth_m(:), node_thickness_m(:)
    integer, allocatable :: layer_numbers(:), catalog_indices(:), source_horizon_index(:)
    type(fmr_elastic_storage_row_file_diagnostics_t) :: file_diag
    type(fmr_elastic_storage_profile_source_diagnostics_t) :: profile_diag
    type(fmr_elastic_storage_grid_diagnostics_t) :: grid_diag
    type(fmr_elastic_storage_mapping_diagnostics_t) :: map_diag
    type(fmr_elastic_storage_assembly_diagnostics_t) :: assembly_diag

    bound_parameters = base_parameters
    diagnostics = fmr_elastic_storage_row_application_diagnostics_t()
    diagnostics%request_present = generated_prior_requested

    if (.not. generated_prior_requested) return

    call fmr_read_elastic_storage_row_interchange_file(path, rows, file_diag)
    diagnostics%row_file_status = file_diag%status
    diagnostics%selected_profile_id = file_diag%profile_id
    if (file_diag%status /= FMR_ELAS_ROWS_FILE_OK) then
      diagnostics%status = FMR_ELAS_ROW_APP_ROW_FILE_REJECTED
      return
    end if

    call fmr_build_explicit_bro_profile_horizons(rows, file_diag%profile_id, horizons, &
         layer_numbers, catalog_indices, profile_diag)
    diagnostics%profile_status = profile_diag%status
    if (profile_diag%status /= FMR_ELAS_PROFILE_SOURCE_OK) then
      diagnostics%status = FMR_ELAS_ROW_APP_PROFILE_REJECTED
      return
    end if

    if (.not. allocated(base_parameters%z) .or. .not. allocated(base_parameters%dz)) then
      diagnostics%grid_status = FMR_ELAS_GRID_INVALID_SHAPE
      diagnostics%status = FMR_ELAS_ROW_APP_GRID_REJECTED
      return
    end if

    call fmr_normalize_swap_grid_geometry(base_parameters%z, base_parameters%dz, &
         node_depth_m, node_thickness_m, grid_diag)
    diagnostics%grid_status = grid_diag%status
    if (grid_diag%status /= FMR_ELAS_GRID_OK) then
      diagnostics%status = FMR_ELAS_ROW_APP_GRID_REJECTED
      return
    end if

    call fmr_map_elastic_storage_horizons_to_nodes(horizons, node_depth_m, node_thickness_m, &
         descriptors, source_horizon_index, map_diag)
    diagnostics%map_status = map_diag%status
    if (map_diag%status /= FMR_ELAS_MAP_OK) then
      diagnostics%status = FMR_ELAS_ROW_APP_MAP_REJECTED
      return
    end if

    call fmr_assemble_generated_elastic_storage(base_parameters, .true., descriptors, &
         bound_parameters, assembly_diag)
    diagnostics%assembly_status = assembly_diag%status
    diagnostics%generated_prior_applied = assembly_diag%generated_prior_applied
    if (assembly_diag%status /= FMR_ELAS_ASSEMBLY_OK) then
      bound_parameters = base_parameters
      diagnostics%status = FMR_ELAS_ROW_APP_ASSEMBLY_REJECTED
      return
    end if

    diagnostics%status = FMR_ELAS_ROW_APP_OK
  end subroutine fmr_bind_elastic_storage_from_row_interchange

end module mod_fmr_elastic_storage_row_application_binding
