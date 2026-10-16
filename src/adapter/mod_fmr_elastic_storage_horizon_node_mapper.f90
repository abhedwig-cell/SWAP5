module mod_fmr_elastic_storage_horizon_node_mapper
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_elastic_storage_prior_policy, only: &
       FMR_ELAS_REGIME_MINERAL, FMR_ELAS_REGIME_ORGANIC_RICH_NONPEAT, &
       FMR_ELAS_REGIME_PEAT, FMR_ELAS_REGIME_UNKNOWN
  use mod_fmr_elastic_storage_descriptor_assembly, only: fmr_elastic_storage_descriptor_t
  implicit none
  private

  real(real64), parameter, public :: FMR_ELAS_GEOMETRY_TOL_M = 1.0e-10_real64

  integer, parameter, public :: FMR_ELAS_MAP_OK = 0
  integer, parameter, public :: FMR_ELAS_MAP_INVALID_HORIZON = 1
  integer, parameter, public :: FMR_ELAS_MAP_INVALID_NODE = 2
  integer, parameter, public :: FMR_ELAS_MAP_NODE_NOT_COVERED = 3
  integer, parameter, public :: FMR_ELAS_MAP_NODE_STRADDLES = 4

  type, public :: fmr_elastic_storage_horizon_t
    real(real64) :: top_depth_m = 0.0_real64
    real(real64) :: bottom_depth_m = 0.0_real64
    real(real64) :: rho_dry_g_cm3 = 0.0_real64
    real(real64) :: theta_ref_cm3_cm3 = 0.0_real64
    integer :: regime = FMR_ELAS_REGIME_UNKNOWN
  end type fmr_elastic_storage_horizon_t

  type, public :: fmr_elastic_storage_mapping_diagnostics_t
    integer :: status = FMR_ELAS_MAP_INVALID_HORIZON
    integer :: failed_horizon = 0
    integer :: failed_node = 0
    logical :: horizons_valid = .false.
    logical :: nodes_valid = .false.
    logical :: mapping_complete = .false.
  end type fmr_elastic_storage_mapping_diagnostics_t

  public :: fmr_map_elastic_storage_horizons_to_nodes

contains

  subroutine fmr_map_elastic_storage_horizons_to_nodes(horizons, node_depth_m, node_thickness_m, &
                                                        descriptors, source_horizon_index, diagnostics)
    type(fmr_elastic_storage_horizon_t), intent(in) :: horizons(:)
    real(real64), intent(in) :: node_depth_m(:)
    real(real64), intent(in) :: node_thickness_m(:)
    type(fmr_elastic_storage_descriptor_t), allocatable, intent(out) :: descriptors(:)
    integer, allocatable, intent(out) :: source_horizon_index(:)
    type(fmr_elastic_storage_mapping_diagnostics_t), intent(out) :: diagnostics

    integer :: i, j, nnode, owner
    real(real64) :: node_top, node_bottom

    if (allocated(descriptors)) deallocate(descriptors)
    if (allocated(source_horizon_index)) deallocate(source_horizon_index)
    diagnostics = fmr_elastic_storage_mapping_diagnostics_t()

    if (size(horizons) <= 0) return

    do j = 1, size(horizons)
      if (.not. valid_horizon(horizons(j))) then
        diagnostics%failed_horizon = j
        return
      end if
      if (j > 1) then
        if (abs(horizons(j)%top_depth_m - horizons(j-1)%bottom_depth_m) > FMR_ELAS_GEOMETRY_TOL_M) then
          diagnostics%failed_horizon = j
          return
        end if
      end if
    end do
    diagnostics%horizons_valid = .true.

    nnode = size(node_depth_m)
    if (nnode <= 0 .or. size(node_thickness_m) /= nnode) then
      diagnostics%status = FMR_ELAS_MAP_INVALID_NODE
      return
    end if

    do i = 1, nnode
      if (.not. ieee_is_finite(node_depth_m(i)) .or. .not. ieee_is_finite(node_thickness_m(i))) then
        diagnostics%status = FMR_ELAS_MAP_INVALID_NODE
        diagnostics%failed_node = i
        return
      end if
      if (node_depth_m(i) < 0.0_real64 .or. node_thickness_m(i) <= 0.0_real64) then
        diagnostics%status = FMR_ELAS_MAP_INVALID_NODE
        diagnostics%failed_node = i
        return
      end if
      node_top = node_depth_m(i) - 0.5_real64 * node_thickness_m(i)
      if (node_top < -FMR_ELAS_GEOMETRY_TOL_M) then
        diagnostics%status = FMR_ELAS_MAP_INVALID_NODE
        diagnostics%failed_node = i
        return
      end if
    end do
    diagnostics%nodes_valid = .true.

    allocate(descriptors(nnode), source_horizon_index(nnode))
    source_horizon_index = 0

    do i = 1, nnode
      node_top = node_depth_m(i) - 0.5_real64 * node_thickness_m(i)
      node_bottom = node_depth_m(i) + 0.5_real64 * node_thickness_m(i)

      if (node_top < horizons(1)%top_depth_m - FMR_ELAS_GEOMETRY_TOL_M .or. &
          node_bottom > horizons(size(horizons))%bottom_depth_m + FMR_ELAS_GEOMETRY_TOL_M) then
        call fail_mapping(FMR_ELAS_MAP_NODE_NOT_COVERED, i, descriptors, source_horizon_index, diagnostics)
        return
      end if

      owner = 0
      do j = 1, size(horizons)
        if (node_top >= horizons(j)%top_depth_m - FMR_ELAS_GEOMETRY_TOL_M .and. &
            node_bottom <= horizons(j)%bottom_depth_m + FMR_ELAS_GEOMETRY_TOL_M) then
          owner = j
          exit
        end if
      end do

      if (owner == 0) then
        call fail_mapping(FMR_ELAS_MAP_NODE_STRADDLES, i, descriptors, source_horizon_index, diagnostics)
        return
      end if

      descriptors(i)%rho_dry_g_cm3 = horizons(owner)%rho_dry_g_cm3
      descriptors(i)%theta_ref_cm3_cm3 = horizons(owner)%theta_ref_cm3_cm3
      descriptors(i)%regime = horizons(owner)%regime
      source_horizon_index(i) = owner
    end do

    diagnostics%status = FMR_ELAS_MAP_OK
    diagnostics%mapping_complete = .true.
  end subroutine fmr_map_elastic_storage_horizons_to_nodes

  pure logical function valid_horizon(horizon) result(valid)
    type(fmr_elastic_storage_horizon_t), intent(in) :: horizon

    valid = .false.
    if (.not. ieee_is_finite(horizon%top_depth_m) .or. .not. ieee_is_finite(horizon%bottom_depth_m)) return
    if (.not. ieee_is_finite(horizon%rho_dry_g_cm3) .or. .not. ieee_is_finite(horizon%theta_ref_cm3_cm3)) return
    if (horizon%top_depth_m < 0.0_real64) return
    if (horizon%bottom_depth_m <= horizon%top_depth_m) return
    if (horizon%rho_dry_g_cm3 <= 0.0_real64) return
    if (horizon%theta_ref_cm3_cm3 < 0.0_real64 .or. horizon%theta_ref_cm3_cm3 > 1.0_real64) return
    if (.not. valid_regime(horizon%regime)) return
    valid = .true.
  end function valid_horizon

  pure logical function valid_regime(regime) result(valid)
    integer, intent(in) :: regime
    valid = regime == FMR_ELAS_REGIME_MINERAL .or. &
         regime == FMR_ELAS_REGIME_ORGANIC_RICH_NONPEAT .or. &
         regime == FMR_ELAS_REGIME_PEAT .or. regime == FMR_ELAS_REGIME_UNKNOWN
  end function valid_regime

  subroutine fail_mapping(status, node, descriptors, source_horizon_index, diagnostics)
    integer, intent(in) :: status, node
    type(fmr_elastic_storage_descriptor_t), allocatable, intent(inout) :: descriptors(:)
    integer, allocatable, intent(inout) :: source_horizon_index(:)
    type(fmr_elastic_storage_mapping_diagnostics_t), intent(inout) :: diagnostics

    if (allocated(descriptors)) deallocate(descriptors)
    if (allocated(source_horizon_index)) deallocate(source_horizon_index)
    diagnostics%status = status
    diagnostics%failed_node = node
    diagnostics%mapping_complete = .false.
  end subroutine fail_mapping

end module mod_fmr_elastic_storage_horizon_node_mapper
