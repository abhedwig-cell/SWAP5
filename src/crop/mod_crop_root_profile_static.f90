module mod_crop_root_profile_static
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_wofost_rate_table, only: wofost_rate_table_t, WOFOST_RATE_TABLE_OK
  implicit none
  private

  real(real64), parameter :: ROOT_DEPTH_BOUNDARY_TOL_CM = 1.0e-8_real64

  integer, parameter, public :: CROP_ROOT_PROFILE_OK = 0
  integer, parameter, public :: CROP_ROOT_PROFILE_INVALID_TABLE = 1
  integer, parameter, public :: CROP_ROOT_PROFILE_INVALID_GEOMETRY = 2
  integer, parameter, public :: CROP_ROOT_PROFILE_INVALID_DEPTH = 3
  integer, parameter, public :: CROP_ROOT_PROFILE_ZERO_DENSITY = 4

  public :: materialize_static_root_profile

contains

  subroutine materialize_static_root_profile(density_table, zbotcp_cm, maximum_root_depth_cm, root_depth_cm, &
                                               rooted_nodes, cumulative_root_fraction, status)
    type(wofost_rate_table_t), intent(in) :: density_table
    real(real64), intent(in) :: zbotcp_cm(:), maximum_root_depth_cm, root_depth_cm
    integer, intent(out) :: rooted_nodes
    real(real64), allocatable, intent(out) :: cumulative_root_fraction(:)
    integer, intent(out) :: status

    integer :: n, max_root_node, node, i, table_status
    real(real64) :: previous_depth, relative_depth, previous_density, density, total, query, fraction
    real(real64), allocatable :: cumulative_depth(:), cumulative_fraction(:)

    rooted_nodes = 0
    status = CROP_ROOT_PROFILE_INVALID_GEOMETRY
    if (allocated(cumulative_root_fraction)) deallocate(cumulative_root_fraction)

    if (.not. density_table%ready()) then
      status = CROP_ROOT_PROFILE_INVALID_TABLE
      return
    end if

    n = size(zbotcp_cm)
    if (n <= 0 .or. any(.not. ieee_is_finite(zbotcp_cm))) return
    if (zbotcp_cm(1) >= 0.0_real64) return
    do i = 2, n
      if (zbotcp_cm(i) >= zbotcp_cm(i-1)) return
    end do
    if (.not. ieee_is_finite(maximum_root_depth_cm) .or. maximum_root_depth_cm <= 0.0_real64) return
    if (.not. ieee_is_finite(root_depth_cm) .or. root_depth_cm < 0.0_real64 .or. &
        root_depth_cm > maximum_root_depth_cm) then
      status = CROP_ROOT_PROFILE_INVALID_DEPTH
      return
    end if
    if (root_depth_cm <= ROOT_DEPTH_BOUNDARY_TOL_CM) then
      status = CROP_ROOT_PROFILE_OK
      return
    end if

    ! B1.11 initialize_cumdens: use the first compartment bottom deeper than
    ! RDM-1e-8 as the maximum rooted profile support.
    max_root_node = 0
    do i = 1, n
      if (zbotcp_cm(i) < (-maximum_root_depth_cm + ROOT_DEPTH_BOUNDARY_TOL_CM)) then
        max_root_node = i
        exit
      end if
    end do
    if (max_root_node == 0) return

    allocate(cumulative_depth(0:max_root_node), cumulative_fraction(0:max_root_node))
    cumulative_depth = 0.0_real64
    cumulative_fraction = 0.0_real64

    call density_table%evaluate(0.0_real64, previous_density, table_status)
    if (table_status /= WOFOST_RATE_TABLE_OK .or. .not. ieee_is_finite(previous_density) .or. &
        previous_density < 0.0_real64) then
      status = CROP_ROOT_PROFILE_INVALID_TABLE
      return
    end if

    previous_depth = 0.0_real64
    total = 0.0_real64
    do i = 1, max_root_node
      relative_depth = min(1.0_real64, abs(zbotcp_cm(i) / maximum_root_depth_cm))
      call density_table%evaluate(relative_depth, density, table_status)
      if (table_status /= WOFOST_RATE_TABLE_OK .or. .not. ieee_is_finite(density) .or. density < 0.0_real64) then
        status = CROP_ROOT_PROFILE_INVALID_TABLE
        return
      end if
      total = total + 0.5_real64 * (previous_density + density) * (relative_depth - previous_depth)
      cumulative_depth(i) = relative_depth
      cumulative_fraction(i) = total
      previous_depth = relative_depth
      previous_density = density
    end do

    if (.not. ieee_is_finite(total) .or. total <= 0.0_real64) then
      status = CROP_ROOT_PROFILE_ZERO_DENSITY
      return
    end if
    cumulative_fraction = cumulative_fraction / total

    ! B1.11 update_rootextension: exact-boundary roots stay in that node
    ! because the source tests zbotcp(node)+RD < nihil.
    do node = 1, n
      if (zbotcp_cm(node) + root_depth_cm < ROOT_DEPTH_BOUNDARY_TOL_CM) then
        rooted_nodes = node
        exit
      end if
    end do
    if (rooted_nodes == 0) then
      status = CROP_ROOT_PROFILE_INVALID_DEPTH
      return
    end if

    allocate(cumulative_root_fraction(rooted_nodes + 1))
    cumulative_root_fraction(1) = 0.0_real64
    do node = 1, rooted_nodes
      query = abs(zbotcp_cm(node) / zbotcp_cm(rooted_nodes))
      call interpolate_cumulative(cumulative_depth, cumulative_fraction, max_root_node, query, fraction)
      cumulative_root_fraction(node + 1) = fraction
    end do
    cumulative_root_fraction(rooted_nodes + 1) = 1.0_real64
    status = CROP_ROOT_PROFILE_OK
  end subroutine materialize_static_root_profile

  pure subroutine interpolate_cumulative(x, y, n, query, value)
    real(real64), intent(in) :: x(0:), y(0:), query
    integer, intent(in) :: n
    real(real64), intent(out) :: value
    integer :: i

    if (query <= x(0)) then
      value = y(0)
      return
    end if
    if (query >= x(n)) then
      value = y(n)
      return
    end if
    do i = 1, n
      if (query <= x(i)) then
        value = y(i-1) + (query-x(i-1)) * (y(i)-y(i-1)) / (x(i)-x(i-1))
        return
      end if
    end do
    value = y(n)
  end subroutine interpolate_cumulative

end module mod_crop_root_profile_static
