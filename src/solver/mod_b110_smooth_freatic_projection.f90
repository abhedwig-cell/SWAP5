module mod_b110_smooth_freatic_projection
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  integer, parameter, public :: B110_GWL_PROJECTION_OK = 0
  integer, parameter, public :: B110_GWL_PROJECTION_INVALID_INPUT = 1
  integer, parameter, public :: B110_GWL_PROJECTION_UNSUPPORTED_BOTTOM_MODE = 2
  integer, parameter, public :: B110_GWL_PROJECTION_UNSUPPORTED_MACROPORE = 3
  integer, parameter, public :: B110_GWL_PROJECTION_NO_INTERIOR_WATER_TABLE = 4
  integer, parameter, public :: B110_GWL_PROJECTION_FULLY_SATURATED = 5
  integer, parameter, public :: B110_GWL_PROJECTION_NONSMOOTH = 6

  type, public :: b110_smooth_freatic_projection_diagnostics_t
    integer :: status = B110_GWL_PROJECTION_INVALID_INPUT
    integer :: crossing_lower_node = 0
    logical :: value_defined = .false.
    logical :: direction_defined = .false.
    logical :: branch_or_nonsmooth_point = .false.
    character(len=64) :: route = 'not-evaluated'
  end type b110_smooth_freatic_projection_diagnostics_t

  public :: evaluate_b110_smooth_freatic_projection

contains

  pure subroutine evaluate_b110_smooth_freatic_projection(bottom_mode, macropore_active, z, node_distance, &
       pressure_head, pressure_head_direction, groundwater_level, groundwater_level_direction, diagnostics)
    integer, intent(in) :: bottom_mode
    logical, intent(in) :: macropore_active
    real(real64), intent(in) :: z(:), node_distance(:), pressure_head(:), pressure_head_direction(:)
    real(real64), intent(out) :: groundwater_level, groundwater_level_direction
    type(b110_smooth_freatic_projection_diagnostics_t), intent(out) :: diagnostics

    integer :: n, node, lower
    real(real64) :: h_lower, h_upper, dh_lower, dh_upper, distance, denominator

    groundwater_level = 0.0_real64
    groundwater_level_direction = 0.0_real64
    diagnostics = b110_smooth_freatic_projection_diagnostics_t()

    n = size(pressure_head)
    if (n < 2 .or. size(z) /= n .or. size(node_distance) /= n .or. size(pressure_head_direction) /= n) then
      diagnostics%route = 'shape-invalid'
      return
    end if
    if (bottom_mode /= 2) then
      diagnostics%status = B110_GWL_PROJECTION_UNSUPPORTED_BOTTOM_MODE
      diagnostics%route = 'prescribed-qbot-only'
      return
    end if
    if (macropore_active) then
      diagnostics%status = B110_GWL_PROJECTION_UNSUPPORTED_MACROPORE
      diagnostics%route = 'macropore-excluded'
      return
    end if
    if (any(.not. ieee_is_finite(z)) .or. any(.not. ieee_is_finite(node_distance)) .or. &
        any(.not. ieee_is_finite(pressure_head)) .or. any(.not. ieee_is_finite(pressure_head_direction))) then
      diagnostics%route = 'nonfinite-input'
      return
    end if
    if (any(node_distance(2:n) <= 0.0_real64)) then
      diagnostics%route = 'node-distance-invalid'
      return
    end if

    if (pressure_head(n) < 0.0_real64) then
      diagnostics%status = B110_GWL_PROJECTION_NO_INTERIOR_WATER_TABLE
      diagnostics%route = 'water-table-below-profile'
      return
    else if (.not. (pressure_head(n) > 0.0_real64)) then
      diagnostics%status = B110_GWL_PROJECTION_NONSMOOTH
      diagnostics%branch_or_nonsmooth_point = .true.
      diagnostics%route = 'bottom-node-zero-pressure'
      return
    end if

    lower = 0
    node = n
    do while (node > 1)
      node = node - 1
      if (pressure_head(node) < 0.0_real64) then
        lower = node
        exit
      else if (.not. (pressure_head(node) > 0.0_real64)) then
        diagnostics%status = B110_GWL_PROJECTION_NONSMOOTH
        diagnostics%branch_or_nonsmooth_point = .true.
        diagnostics%route = 'zero-pressure-node-crossing'
        return
      end if
    end do

    if (lower == 0) then
      diagnostics%status = B110_GWL_PROJECTION_FULLY_SATURATED
      diagnostics%branch_or_nonsmooth_point = .true.
      diagnostics%route = 'fully-saturated-branch-excluded'
      return
    end if

    h_lower = pressure_head(lower)
    h_upper = pressure_head(lower+1)
    dh_lower = pressure_head_direction(lower)
    dh_upper = pressure_head_direction(lower+1)
    distance = node_distance(lower+1)
    denominator = h_upper - h_lower

    if (.not. (h_lower < 0.0_real64) .or. .not. (h_upper > 0.0_real64) .or. &
        .not. ieee_is_finite(denominator) .or. .not. (denominator > 0.0_real64)) then
      diagnostics%status = B110_GWL_PROJECTION_NONSMOOTH
      diagnostics%branch_or_nonsmooth_point = .true.
      diagnostics%route = 'strict-interior-crossing-unavailable'
      return
    end if

    groundwater_level = z(lower+1) + h_upper * distance / denominator
    groundwater_level_direction = distance * (h_upper*dh_lower - h_lower*dh_upper) / (denominator*denominator)

    if (.not. ieee_is_finite(groundwater_level) .or. .not. ieee_is_finite(groundwater_level_direction)) then
      groundwater_level = 0.0_real64
      groundwater_level_direction = 0.0_real64
      diagnostics%route = 'projection-nonfinite'
      return
    end if

    diagnostics%status = B110_GWL_PROJECTION_OK
    diagnostics%crossing_lower_node = lower
    diagnostics%value_defined = .true.
    diagnostics%direction_defined = .true.
    diagnostics%route = 'b110-nonmacropore-smooth-interior-zero-pressure-crossing'
  end subroutine evaluate_b110_smooth_freatic_projection

end module mod_b110_smooth_freatic_projection
