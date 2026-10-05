module mod_fmr_irrigation_depth_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: IRRIGATION_DEPTH_BIND_OK = 0
  integer, parameter, public :: IRRIGATION_DEPTH_BIND_INVALID = 1
  real(real64), parameter :: SOURCE_NODE_TOLERANCE_CM = 1.0e-5_real64
  public :: bind_irrigation_depth_to_nodes
  public :: bind_fixed_irrigation_rate
contains
  pure subroutine bind_fixed_irrigation_rate(depth_mm,rate_supplied,rate_mm_per_hour, &
       depth_cm,rate_cm_per_day,status)
    real(real64), intent(in) :: depth_mm,rate_mm_per_hour
    logical, intent(in) :: rate_supplied
    real(real64), intent(out) :: depth_cm,rate_cm_per_day
    integer, intent(out) :: status
    depth_cm = 0.0_real64
    rate_cm_per_day = 0.0_real64
    status = IRRIGATION_DEPTH_BIND_INVALID
    if (.not. ieee_is_finite(depth_mm)) return
    if (depth_mm <= 0.0_real64) return
    if (rate_supplied) then
      if (.not. ieee_is_finite(rate_mm_per_hour) .or. rate_mm_per_hour <= 0.0_real64) return
      rate_cm_per_day = 2.4_real64*rate_mm_per_hour
    else
      ! B1.11's missing IRRATE fallback is depth/24 mm/h: exactly one day.
      rate_cm_per_day = 0.1_real64*depth_mm
    end if
    depth_cm = 0.1_real64*depth_mm
    if (.not. all(ieee_is_finite([depth_cm,rate_cm_per_day]))) then
      depth_cm = 0.0_real64
      rate_cm_per_day = 0.0_real64
      return
    end if
    status = IRRIGATION_DEPTH_BIND_OK
  end subroutine

  pure subroutine bind_irrigation_depth_to_nodes(compartment_bottom_cm, first_depth_cm, &
       last_depth_cm, first_node, last_node, status)
    real(real64), intent(in) :: compartment_bottom_cm(:), first_depth_cm,last_depth_cm
    integer, intent(out) :: first_node,last_node,status
    integer :: i,n
    first_node = 0
    last_node = 0
    status = IRRIGATION_DEPTH_BIND_INVALID
    n = size(compartment_bottom_cm)
    if (n < 1) return
    if (any(.not. ieee_is_finite(compartment_bottom_cm)) .or. &
        .not. ieee_is_finite(first_depth_cm) .or. .not. ieee_is_finite(last_depth_cm)) return
    if (any(compartment_bottom_cm >= 0.0_real64)) return
    do i=2,n
      if (compartment_bottom_cm(i) >= compartment_bottom_cm(i-1)) return
    end do
    if (first_depth_cm > 0.0_real64 .or. last_depth_cm > first_depth_cm .or. &
        last_depth_cm < compartment_bottom_cm(n)-SOURCE_NODE_TOLERANCE_CM) return
    do i=1,n
      if (first_node == 0 .and. compartment_bottom_cm(i) <= first_depth_cm+SOURCE_NODE_TOLERANCE_CM) first_node = i
      if (last_node == 0 .and. compartment_bottom_cm(i) <= last_depth_cm+SOURCE_NODE_TOLERANCE_CM) last_node = i
    end do
    if (first_node < 1 .or. last_node < first_node) then
      first_node = 0
      last_node = 0
      return
    end if
    status = IRRIGATION_DEPTH_BIND_OK
  end subroutine
end module
