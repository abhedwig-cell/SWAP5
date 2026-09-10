module mod_drainage_spatial_distribution
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  implicit none
  private

  integer, parameter, public :: DRAIN_DIST_OK = 0
  integer, parameter, public :: DRAIN_DIST_INVALID_PARAMETERS = 1
  integer, parameter, public :: DRAIN_DIST_INVALID_HYDRAULIC_VIEW = 2
  integer, parameter, public :: DRAIN_DIST_INVALID_TRANSFER = 3
  integer, parameter, public :: DRAIN_DIST_TRANSFER_BELOW_ADMITTED_MAGNITUDE = 4

  real(real64), parameter :: LEGACY_ACTIVE_MAGNITUDE = 1.0e-10_real64
  real(real64), parameter :: LEGACY_LEVEL_TO_COMPARTMENT_OFFSET = 1.0e-10_real64

  type, public :: drainage_distribution_parameters_t
    integer :: active_nodes = 0
    real(real64), allocatable :: dz(:)
    real(real64), allocatable :: zbotcp(:)
    real(real64), allocatable :: saturated_conductivity(:)
    real(real64), allocatable :: horizontal_anisotropy_factor(:)
    real(real64) :: drain_spacing = 0.0_real64
  end type drainage_distribution_parameters_t

  type, public :: drainage_node_transfer_t
    real(real64), allocatable :: soil_to_drain_rate(:)
  end type drainage_node_transfer_t

  type, public :: drainage_distribution_diagnostics_t
    integer :: status = DRAIN_DIST_OK
    logical :: evaluated = .false.
    logical :: zero_transfer = .false.
    integer :: water_table_node = 0
    integer :: discharge_bottom_node = 0
    real(real64) :: groundwater_depth = 0.0_real64
    real(real64) :: saturated_top_thickness = 0.0_real64
    real(real64) :: discharge_bottom_thickness = 0.0_real64
    real(real64) :: profile_anisotropy_factor = 0.0_real64
    real(real64) :: discharge_layer_bottom_depth = 0.0_real64
    real(real64) :: discharge_transmissivity = 0.0_real64
    real(real64) :: raw_partition_sum = 0.0_real64
    real(real64) :: closure_correction = 0.0_real64
    logical :: scalar_transfer_is_authoritative = .true.
    logical :: worker_scratch_only = .true.
  end type drainage_distribution_diagnostics_t

  public :: distribute_single_level_positive_divdra

contains

  subroutine distribute_single_level_positive_divdra(parameters, hydraulic_view, scalar_transfer, node_transfer, diagnostics)
    type(drainage_distribution_parameters_t), intent(in) :: parameters
    type(process_hydraulic_view_t), intent(in) :: hydraulic_view
    real(real64), intent(in) :: scalar_transfer
    type(drainage_node_transfer_t), intent(out) :: node_transfer
    type(drainage_distribution_diagnostics_t), intent(out) :: diagnostics

    real(real64), allocatable :: khor(:), kver(:)
    real(real64) :: wlev, dz_top_sat, kd_hor, kd_ver, saturated_depth
    real(real64) :: khor_avg, kver_avg, fac_aniso, dmax, discharge_bottom
    real(real64) :: kd_drain, depth_accum, discharge_thickness, raw_bottom
    real(real64) :: sum_previous
    integer :: n, i, wt_node, bottom_node

    diagnostics = drainage_distribution_diagnostics_t()
    n = parameters%active_nodes

    if (.not. valid_parameters(parameters)) then
      diagnostics%status = DRAIN_DIST_INVALID_PARAMETERS
      return
    end if

    allocate(node_transfer%soil_to_drain_rate(n))
    node_transfer%soil_to_drain_rate = 0.0_real64

    if (.not. ieee_is_finite(scalar_transfer) .or. scalar_transfer < 0.0_real64) then
      diagnostics%status = DRAIN_DIST_INVALID_TRANSFER
      return
    end if

    if (scalar_transfer <= 0.0_real64) then
      diagnostics%evaluated = .true.
      diagnostics%zero_transfer = .true.
      return
    end if

    if (scalar_transfer <= LEGACY_ACTIVE_MAGNITUDE) then
      diagnostics%status = DRAIN_DIST_TRANSFER_BELOW_ADMITTED_MAGNITUDE
      return
    end if

    if (.not. ieee_is_finite(hydraulic_view%groundwater_level)) then
      diagnostics%status = DRAIN_DIST_INVALID_HYDRAULIC_VIEW
      return
    end if

    wlev = -min(hydraulic_view%groundwater_level, 0.0_real64)
    if (wlev >= -parameters%zbotcp(n)) then
      diagnostics%status = DRAIN_DIST_INVALID_HYDRAULIC_VIEW
      return
    end if

    allocate(khor(n), kver(n))
    khor = parameters%saturated_conductivity * parameters%horizontal_anisotropy_factor
    kver = parameters%saturated_conductivity

    ! Frozen SWAP 4.3.1 Lev2Comp semantics deliberately retain the shallower
    ! compartment until the level is more than 1e-10 cm below its bottom.
    ! This is an explicit reference seam, not a configurable solver tolerance.
    wt_node = 1
    do while (wlev > -parameters%zbotcp(wt_node) + LEGACY_LEVEL_TO_COMPARTMENT_OFFSET)
      wt_node = wt_node + 1
      if (wt_node > n) then
        diagnostics%status = DRAIN_DIST_INVALID_HYDRAULIC_VIEW
        return
      end if
    end do

    dz_top_sat = -parameters%zbotcp(wt_node) - wlev
    if (wt_node == n .and. dz_top_sat <= 0.0_real64) then
      diagnostics%status = DRAIN_DIST_INVALID_HYDRAULIC_VIEW
      return
    end if

    kd_hor = dz_top_sat * khor(wt_node)
    kd_ver = dz_top_sat / kver(wt_node)
    saturated_depth = dz_top_sat
    do i = wt_node + 1, n
      kd_hor = kd_hor + parameters%dz(i) * khor(i)
      kd_ver = kd_ver + parameters%dz(i) / kver(i)
      saturated_depth = saturated_depth + parameters%dz(i)
    end do

    if (kd_hor <= 0.0_real64 .or. kd_ver <= 0.0_real64 .or. saturated_depth <= 0.0_real64) then
      diagnostics%status = DRAIN_DIST_INVALID_PARAMETERS
      return
    end if

    khor_avg = kd_hor / saturated_depth
    kver_avg = saturated_depth / kd_ver
    fac_aniso = sqrt(kver_avg / khor_avg)

    dmax = 0.25_real64 * parameters%drain_spacing * fac_aniso + wlev
    dmax = min(dmax, saturated_depth + wlev)

    discharge_bottom = -parameters%zbotcp(n)
    bottom_node = n
    discharge_thickness = parameters%dz(n)
    kd_drain = kd_hor

    if (discharge_bottom > dmax) then
      discharge_bottom = dmax
      bottom_node = wt_node
      depth_accum = dz_top_sat
      kd_drain = dz_top_sat * khor(wt_node)
      do while (discharge_bottom - wlev > depth_accum)
        bottom_node = bottom_node + 1
        if (bottom_node > n) then
          diagnostics%status = DRAIN_DIST_INVALID_PARAMETERS
          return
        end if
        depth_accum = depth_accum + parameters%dz(bottom_node)
        kd_drain = kd_drain + parameters%dz(bottom_node) * khor(bottom_node)
      end do
      kd_drain = kd_drain - (depth_accum - (discharge_bottom - wlev)) * khor(bottom_node)
      discharge_thickness = parameters%dz(bottom_node) - (depth_accum - (discharge_bottom - wlev))
    end if

    if (kd_drain <= 0.0_real64 .or. discharge_thickness <= 0.0_real64) then
      diagnostics%status = DRAIN_DIST_INVALID_PARAMETERS
      return
    end if

    if (wt_node == bottom_node) then
      node_transfer%soil_to_drain_rate(wt_node) = scalar_transfer
      diagnostics%raw_partition_sum = scalar_transfer
    else
      node_transfer%soil_to_drain_rate(wt_node) = scalar_transfer * dz_top_sat * khor(wt_node) / kd_drain
      do i = wt_node + 1, bottom_node - 1
        node_transfer%soil_to_drain_rate(i) = scalar_transfer * parameters%dz(i) * khor(i) / kd_drain
      end do
      raw_bottom = scalar_transfer * discharge_thickness * khor(bottom_node) / kd_drain
      diagnostics%raw_partition_sum = sum(node_transfer%soil_to_drain_rate(1:bottom_node-1)) + raw_bottom

      sum_previous = sum(node_transfer%soil_to_drain_rate(1:bottom_node-1))
      node_transfer%soil_to_drain_rate(bottom_node) = scalar_transfer - sum_previous
      diagnostics%closure_correction = node_transfer%soil_to_drain_rate(bottom_node) - raw_bottom
    end if

    diagnostics%evaluated = .true.
    diagnostics%water_table_node = wt_node
    diagnostics%discharge_bottom_node = bottom_node
    diagnostics%groundwater_depth = wlev
    diagnostics%saturated_top_thickness = dz_top_sat
    diagnostics%discharge_bottom_thickness = discharge_thickness
    diagnostics%profile_anisotropy_factor = fac_aniso
    diagnostics%discharge_layer_bottom_depth = discharge_bottom
    diagnostics%discharge_transmissivity = kd_drain
  end subroutine distribute_single_level_positive_divdra

  logical function valid_parameters(parameters) result(valid)
    type(drainage_distribution_parameters_t), intent(in) :: parameters
    integer :: i, n
    real(real64) :: cumulative_depth, tolerance

    valid = .false.
    n = parameters%active_nodes
    if (n <= 0) return
    if (.not. allocated(parameters%dz) .or. .not. allocated(parameters%zbotcp)) return
    if (.not. allocated(parameters%saturated_conductivity)) return
    if (.not. allocated(parameters%horizontal_anisotropy_factor)) return
    if (size(parameters%dz) /= n .or. size(parameters%zbotcp) /= n) return
    if (size(parameters%saturated_conductivity) /= n) return
    if (size(parameters%horizontal_anisotropy_factor) /= n) return
    if (any(.not. ieee_is_finite(parameters%dz)) .or. any(parameters%dz <= 0.0_real64)) return
    if (any(.not. ieee_is_finite(parameters%zbotcp)) .or. any(parameters%zbotcp >= 0.0_real64)) return
    if (any(.not. ieee_is_finite(parameters%saturated_conductivity)) .or. &
        any(parameters%saturated_conductivity <= 0.0_real64)) return
    if (any(.not. ieee_is_finite(parameters%horizontal_anisotropy_factor)) .or. &
        any(parameters%horizontal_anisotropy_factor <= 0.0_real64)) return
    if (.not. ieee_is_finite(parameters%drain_spacing) .or. parameters%drain_spacing <= 0.0_real64) return

    cumulative_depth = 0.0_real64
    do i = 1, n
      cumulative_depth = cumulative_depth + parameters%dz(i)
      tolerance = 4096.0_real64 * epsilon(1.0_real64) * max(1.0_real64, cumulative_depth)
      if (abs((-parameters%zbotcp(i)) - cumulative_depth) > tolerance) return
    end do
    valid = .true.
  end function valid_parameters

end module mod_drainage_spatial_distribution
