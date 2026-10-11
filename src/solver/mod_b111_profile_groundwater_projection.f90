module mod_b111_profile_groundwater_projection
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  integer, parameter, public :: B111_PROFILE_GWL_INVALID = 0
  integer, parameter, public :: B111_PROFILE_GWL_INTERIOR = 1
  integer, parameter, public :: B111_PROFILE_GWL_FULLY_SATURATED = 2
  integer, parameter, public :: B111_PROFILE_GWL_BELOW_PROFILE = 3

  type, public :: b111_profile_groundwater_projection_t
    integer :: status = B111_PROFILE_GWL_INVALID
    integer :: crossing_lower_node = 0
    logical :: valid = .false.
    logical :: level_present = .false.
    real(real64) :: level_cm = 0.0_real64
  end type b111_profile_groundwater_projection_t

  public :: evaluate_b111_profile_groundwater_projection

contains

  pure subroutine evaluate_b111_profile_groundwater_projection(z, node_distance, pressure_head, ponding_depth, result)
    real(real64), intent(in) :: z(:), node_distance(:), pressure_head(:), ponding_depth
    type(b111_profile_groundwater_projection_t), intent(out) :: result

    integer :: n, node, lower
    real(real64) :: denominator

    result = b111_profile_groundwater_projection_t()
    n = size(pressure_head)
    if (n < 2 .or. size(z) /= n .or. size(node_distance) /= n) return
    if (any(.not. ieee_is_finite(z)) .or. any(.not. ieee_is_finite(node_distance)) .or. &
        any(.not. ieee_is_finite(pressure_head)) .or. .not. ieee_is_finite(ponding_depth)) return
    if (any(node_distance(2:n) <= 0.0_real64) .or. ponding_depth < 0.0_real64) return

    ! Literal active CALCGWL option-1 value semantics. Keep the historical
    ! below-profile sentinel out of the typed result: absence is explicit.
    if (pressure_head(n) < 0.0_real64) then
      result%status = B111_PROFILE_GWL_BELOW_PROFILE
      result%valid = .true.
      return
    end if

    lower = 0
    do node = n - 1, 1, -1
      if (pressure_head(node) < 0.0_real64) then
        lower = node
        exit
      end if
    end do

    if (lower == 0) then
      result%status = B111_PROFILE_GWL_FULLY_SATURATED
      result%valid = .true.
      result%level_present = .true.
      if (pressure_head(1) > 0.0_real64) then
        if (ponding_depth < 1.0e-8_real64) then
          result%level_cm = min(z(1) + pressure_head(1), ponding_depth)
        else
          result%level_cm = ponding_depth
        end if
      else
        result%level_cm = 0.0_real64
      end if
      return
    end if

    denominator = pressure_head(lower+1) - pressure_head(lower)
    if (.not. ieee_is_finite(denominator) .or. denominator <= 0.0_real64) return
    result%level_cm = z(lower+1) + pressure_head(lower+1) * node_distance(lower+1) / denominator
    if (.not. ieee_is_finite(result%level_cm)) return
    result%status = B111_PROFILE_GWL_INTERIOR
    result%crossing_lower_node = lower
    result%valid = .true.
    result%level_present = .true.
  end subroutine evaluate_b111_profile_groundwater_projection

end module mod_b111_profile_groundwater_projection
