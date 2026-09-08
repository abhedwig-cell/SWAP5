module mod_nonadaptive_crop_root_view_producer
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_crop_root_uptake_input_assembly, only: crop_root_state_view_t, validate_crop_root_state_view, &
       CROP_ROOT_ASSEMBLY_OK
  implicit none
  private

  integer, parameter, public :: NONADAPT_ROOT_VIEW_OK = 0
  integer, parameter, public :: NONADAPT_ROOT_VIEW_INVALID_ACTIVE_NODES = 1
  integer, parameter, public :: NONADAPT_ROOT_VIEW_INVALID_GRID = 2
  integer, parameter, public :: NONADAPT_ROOT_VIEW_INVALID_MAX_ROOT_DEPTH = 3
  integer, parameter, public :: NONADAPT_ROOT_VIEW_INVALID_ROOT_DEPTH = 4
  integer, parameter, public :: NONADAPT_ROOT_VIEW_INVALID_DENSITY_TABLE = 5
  integer, parameter, public :: NONADAPT_ROOT_VIEW_ZERO_DENSITY_INTEGRAL = 6
  integer, parameter, public :: NONADAPT_ROOT_VIEW_AMBIGUOUS_NODE_BOUNDARY = 7
  integer, parameter, public :: NONADAPT_ROOT_VIEW_OUTPUT_REJECTED = 8

  real(real64), parameter :: LEGACY_INITIAL_NODE_TOL_CM = 1.0e-8_real64
  real(real64), parameter :: ZERO_ROOT_DEPTH_CM = 1.0e-14_real64
  real(real64), parameter :: TABLE_ENDPOINT_TOL = 256.0_real64 * epsilon(1.0_real64)

  type, public :: nonadaptive_root_profile_parameters_t
    integer :: active_nodes = 0
    real(real64) :: maximum_root_depth = 0.0_real64
    real(real64), allocatable :: node_bottom_depth(:)
    real(real64), allocatable :: relative_root_depth(:)
    real(real64), allocatable :: relative_root_density(:)
  end type nonadaptive_root_profile_parameters_t

  type, public :: crop_root_geometry_snapshot_t
    logical :: crop_emerged = .false.
    real(real64) :: current_root_depth = 0.0_real64
  end type crop_root_geometry_snapshot_t

  type, public :: nonadaptive_root_view_diagnostics_t
    integer :: status = NONADAPT_ROOT_VIEW_OK
    integer :: rooted_nodes = 0
    integer :: maximum_rooted_nodes = 0
    logical :: grid_consumed = .false.
    logical :: density_table_consumed = .false.
    logical :: boundary_ambiguity_checked = .false.
    logical :: output_validated = .false.
    logical :: built = .false.
  end type nonadaptive_root_view_diagnostics_t

  public :: build_nonadaptive_crop_root_state_view

contains

  subroutine build_nonadaptive_crop_root_state_view(parameters, snapshot, view, diagnostics)
    type(nonadaptive_root_profile_parameters_t), intent(in) :: parameters
    type(crop_root_geometry_snapshot_t), intent(in) :: snapshot
    type(crop_root_state_view_t), intent(out) :: view
    type(nonadaptive_root_view_diagnostics_t), intent(out) :: diagnostics

    integer :: i, max_nodes, rooted_nodes, assembly_status
    real(real64) :: total, dx, root_zone_bottom, relative_depth
    real(real64), allocatable :: cumulative_x(:), cumulative_y(:), density(:)

    view = crop_root_state_view_t()
    diagnostics = nonadaptive_root_view_diagnostics_t()

    if (parameters%active_nodes <= 0) then
      diagnostics%status = NONADAPT_ROOT_VIEW_INVALID_ACTIVE_NODES
      return
    end if

    ! Preserve the qualified inactive-crop dependency-free route. Legacy crop
    ! fields may contain stale geometry outside the emerged-crop route.
    if (.not. snapshot%crop_emerged) then
      diagnostics%built = .true.
      return
    end if

    view%crop_emerged = .true.

    if (.not. ieee_is_finite(snapshot%current_root_depth) .or. snapshot%current_root_depth < 0.0_real64) then
      diagnostics%status = NONADAPT_ROOT_VIEW_INVALID_ROOT_DEPTH
      view = crop_root_state_view_t()
      return
    end if

    ! RootExtraction has a no-root route below 1e-14 cm. No grid or density
    ! profile is required on that route.
    if (snapshot%current_root_depth < ZERO_ROOT_DEPTH_CM) then
      diagnostics%built = .true.
      call validate_crop_root_state_view(view, parameters%active_nodes, assembly_status)
      if (assembly_status /= CROP_ROOT_ASSEMBLY_OK) then
        diagnostics%status = NONADAPT_ROOT_VIEW_OUTPUT_REJECTED
        diagnostics%built = .false.
        view = crop_root_state_view_t()
      else
        diagnostics%output_validated = .true.
      end if
      return
    end if

    call validate_grid_and_depth(parameters, snapshot%current_root_depth, diagnostics%status)
    if (diagnostics%status /= NONADAPT_ROOT_VIEW_OK) then
      view = crop_root_state_view_t()
      return
    end if
    diagnostics%grid_consumed = .true.

    diagnostics%boundary_ambiguity_checked = .true.
    do i = 1, parameters%active_nodes
      if (abs(parameters%node_bottom_depth(i) - snapshot%current_root_depth) <= LEGACY_INITIAL_NODE_TOL_CM) then
        diagnostics%status = NONADAPT_ROOT_VIEW_AMBIGUOUS_NODE_BOUNDARY
        view = crop_root_state_view_t()
        return
      end if
    end do

    call validate_density_table(parameters, diagnostics%status)
    if (diagnostics%status /= NONADAPT_ROOT_VIEW_OK) then
      view = crop_root_state_view_t()
      return
    end if
    diagnostics%density_table_consumed = .true.

    max_nodes = first_bottom_beyond(parameters%node_bottom_depth, parameters%active_nodes, &
                                    parameters%maximum_root_depth, LEGACY_INITIAL_NODE_TOL_CM)
    if (max_nodes <= 0) then
      diagnostics%status = NONADAPT_ROOT_VIEW_INVALID_MAX_ROOT_DEPTH
      view = crop_root_state_view_t()
      return
    end if
    diagnostics%maximum_rooted_nodes = max_nodes

    rooted_nodes = first_bottom_beyond(parameters%node_bottom_depth, parameters%active_nodes, &
                                       snapshot%current_root_depth, LEGACY_INITIAL_NODE_TOL_CM)
    if (rooted_nodes <= 0) then
      diagnostics%status = NONADAPT_ROOT_VIEW_INVALID_ROOT_DEPTH
      view = crop_root_state_view_t()
      return
    end if
    diagnostics%rooted_nodes = rooted_nodes

    allocate(cumulative_x(max_nodes + 1), cumulative_y(max_nodes + 1), density(max_nodes + 1))
    cumulative_x = 0.0_real64
    cumulative_y = 0.0_real64
    density = 0.0_real64

    cumulative_x(1) = 0.0_real64
    density(1) = linear_table_value(parameters%relative_root_depth, parameters%relative_root_density, 0.0_real64)
    do i = 1, max_nodes
      cumulative_x(i + 1) = min(1.0_real64, parameters%node_bottom_depth(i) / parameters%maximum_root_depth)
      density(i + 1) = linear_table_value(parameters%relative_root_depth, parameters%relative_root_density, &
                                          cumulative_x(i + 1))
    end do

    total = 0.0_real64
    do i = 1, max_nodes
      dx = cumulative_x(i + 1) - cumulative_x(i)
      total = total + 0.5_real64 * (density(i) + density(i + 1)) * dx
      cumulative_y(i + 1) = total
    end do
    if (.not. ieee_is_finite(total) .or. total <= 0.0_real64) then
      diagnostics%status = NONADAPT_ROOT_VIEW_ZERO_DENSITY_INTEGRAL
      view = crop_root_state_view_t()
      return
    end if
    cumulative_y = cumulative_y / total
    cumulative_y(1) = 0.0_real64
    cumulative_y(max_nodes + 1) = 1.0_real64

    view%rooted_nodes = rooted_nodes
    allocate(view%cumulative_root_fraction(rooted_nodes + 1))
    view%cumulative_root_fraction = 0.0_real64
    root_zone_bottom = parameters%node_bottom_depth(rooted_nodes)
    do i = 1, rooted_nodes
      relative_depth = parameters%node_bottom_depth(i) / root_zone_bottom
      view%cumulative_root_fraction(i + 1) = linear_table_value(cumulative_x, cumulative_y, relative_depth)
    end do
    view%cumulative_root_fraction(1) = 0.0_real64
    view%cumulative_root_fraction(rooted_nodes + 1) = 1.0_real64

    call validate_crop_root_state_view(view, parameters%active_nodes, assembly_status)
    if (assembly_status /= CROP_ROOT_ASSEMBLY_OK) then
      diagnostics%status = NONADAPT_ROOT_VIEW_OUTPUT_REJECTED
      view = crop_root_state_view_t()
      return
    end if

    diagnostics%output_validated = .true.
    diagnostics%built = .true.
  end subroutine build_nonadaptive_crop_root_state_view

  subroutine validate_grid_and_depth(parameters, root_depth, status)
    type(nonadaptive_root_profile_parameters_t), intent(in) :: parameters
    real(real64), intent(in) :: root_depth
    integer, intent(out) :: status
    integer :: i

    status = NONADAPT_ROOT_VIEW_OK
    if (.not. allocated(parameters%node_bottom_depth)) then
      status = NONADAPT_ROOT_VIEW_INVALID_GRID
      return
    end if
    if (size(parameters%node_bottom_depth) /= parameters%active_nodes) then
      status = NONADAPT_ROOT_VIEW_INVALID_GRID
      return
    end if
    if (.not. all(ieee_is_finite(parameters%node_bottom_depth))) then
      status = NONADAPT_ROOT_VIEW_INVALID_GRID
      return
    end if
    if (any(parameters%node_bottom_depth <= 0.0_real64)) then
      status = NONADAPT_ROOT_VIEW_INVALID_GRID
      return
    end if
    do i = 2, parameters%active_nodes
      if (parameters%node_bottom_depth(i) <= parameters%node_bottom_depth(i - 1)) then
        status = NONADAPT_ROOT_VIEW_INVALID_GRID
        return
      end if
    end do

    if (.not. ieee_is_finite(parameters%maximum_root_depth) .or. parameters%maximum_root_depth <= 0.0_real64) then
      status = NONADAPT_ROOT_VIEW_INVALID_MAX_ROOT_DEPTH
      return
    end if
    if (parameters%node_bottom_depth(parameters%active_nodes) <= &
        parameters%maximum_root_depth - LEGACY_INITIAL_NODE_TOL_CM) then
      status = NONADAPT_ROOT_VIEW_INVALID_MAX_ROOT_DEPTH
      return
    end if
    if (root_depth > parameters%maximum_root_depth) then
      status = NONADAPT_ROOT_VIEW_INVALID_ROOT_DEPTH
      return
    end if
  end subroutine validate_grid_and_depth

  subroutine validate_density_table(parameters, status)
    type(nonadaptive_root_profile_parameters_t), intent(in) :: parameters
    integer, intent(out) :: status
    integer :: i, n

    status = NONADAPT_ROOT_VIEW_OK
    if (.not. allocated(parameters%relative_root_depth) .or. &
        .not. allocated(parameters%relative_root_density)) then
      status = NONADAPT_ROOT_VIEW_INVALID_DENSITY_TABLE
      return
    end if
    n = size(parameters%relative_root_depth)
    if (n < 2 .or. size(parameters%relative_root_density) /= n) then
      status = NONADAPT_ROOT_VIEW_INVALID_DENSITY_TABLE
      return
    end if
    if (.not. all(ieee_is_finite(parameters%relative_root_depth)) .or. &
        .not. all(ieee_is_finite(parameters%relative_root_density))) then
      status = NONADAPT_ROOT_VIEW_INVALID_DENSITY_TABLE
      return
    end if
    if (abs(parameters%relative_root_depth(1)) > TABLE_ENDPOINT_TOL .or. &
        abs(parameters%relative_root_depth(n) - 1.0_real64) > TABLE_ENDPOINT_TOL) then
      status = NONADAPT_ROOT_VIEW_INVALID_DENSITY_TABLE
      return
    end if
    if (any(parameters%relative_root_density < 0.0_real64)) then
      status = NONADAPT_ROOT_VIEW_INVALID_DENSITY_TABLE
      return
    end if
    do i = 2, n
      if (parameters%relative_root_depth(i) <= parameters%relative_root_depth(i - 1)) then
        status = NONADAPT_ROOT_VIEW_INVALID_DENSITY_TABLE
        return
      end if
    end do
  end subroutine validate_density_table

  integer function first_bottom_beyond(bottom_depth, active_nodes, root_depth, tolerance) result(node)
    real(real64), intent(in) :: bottom_depth(:)
    integer, intent(in) :: active_nodes
    real(real64), intent(in) :: root_depth, tolerance
    integer :: i

    node = 0
    do i = 1, active_nodes
      if (bottom_depth(i) > root_depth - tolerance) then
        node = i
        return
      end if
    end do
  end function first_bottom_beyond

  real(real64) function linear_table_value(x, y, query) result(value)
    real(real64), intent(in) :: x(:), y(:), query
    integer :: i, n
    real(real64) :: slope

    n = size(x)
    if (query <= x(1)) then
      value = y(1)
      return
    end if
    do i = 2, n
      if (query <= x(i)) then
        slope = (y(i) - y(i - 1)) / (x(i) - x(i - 1))
        value = y(i - 1) + (query - x(i - 1)) * slope
        return
      end if
    end do
    value = y(n)
  end function linear_table_value

end module mod_nonadaptive_crop_root_view_producer
