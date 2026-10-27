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

  public :: evaluate_b111_profile_groundwater_projection, minimum_pocket_node, evaluate_b111_pocket_contact_limits

contains

  pure subroutine evaluate_b111_profile_groundwater_projection(z, node_distance, pressure_head, ponding_depth, result, positive_pond_surface)
    real(real64), intent(in) :: z(:), node_distance(:), pressure_head(:), ponding_depth
    type(b111_profile_groundwater_projection_t), intent(out) :: result
    logical, intent(in), optional :: positive_pond_surface

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
      ! A positive surface film is a connected free-water boundary regardless
      ! of its thickness. The literal legacy absence threshold remains the
      ! default; the explicit corrected wall route selects this convention.
      if (present(positive_pond_surface)) then
        if (positive_pond_surface .and. ponding_depth > 0.0_real64) then
          result%level_cm = ponding_depth
          return
        end if
      end if
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

  pure integer function minimum_pocket_node(head, first, last) result(node)
    real(real64),intent(in)::head(:)
    integer,intent(in)::first,last
    node=0
    if(first<1.or.last<first.or.last>size(head))return
    if(any(.not.ieee_is_finite(head(first:last))))return
    node=first-1+minloc(head(first:last),dim=1)
  end function minimum_pocket_node

  pure subroutine evaluate_b111_pocket_contact_limits(z,distance,head,pond,first,last,node, &
       deep_level,shallow_level,ok,positive_pond_surface)
    real(real64),intent(in)::z(:),distance(:),head(:),pond
    integer,intent(in)::first,last,node
    real(real64),intent(out)::deep_level,shallow_level
    logical,intent(out)::ok
    logical,intent(in)::positive_pond_surface
    real(real64)::limiting_head(size(head))
    type(b111_profile_groundwater_projection_t)::projection
    ok=.false.;deep_level=0.0_real64;shallow_level=0.0_real64
    if(size(z)/=size(head).or.size(distance)/=size(head))return
    if(minimum_pocket_node(head,first,last)==0)return
    if(node<first.or.node>last)return
    ! The negative one-sided zero approaches the active node's depth. Remove
    ! only this disappearing pocket to obtain the other original CALCGWL limit.
    ! This is a private limit view, never a mutation of physical candidate water.
    limiting_head=head
    limiting_head(first:last)=max(0.0_real64,limiting_head(first:last))
    limiting_head(node)=0.0_real64
    call evaluate_b111_profile_groundwater_projection(z,distance,limiting_head,pond,projection,positive_pond_surface)
    if(.not.projection%valid.or..not.projection%level_present)return
    if(projection%level_cm<=z(node))return
    deep_level=z(node);shallow_level=projection%level_cm
    ok=.true.
  end subroutine evaluate_b111_pocket_contact_limits

end module mod_b111_profile_groundwater_projection
