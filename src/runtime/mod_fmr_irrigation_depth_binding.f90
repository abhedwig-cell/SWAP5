module mod_fmr_irrigation_depth_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: IRRIGATION_DEPTH_BIND_OK = 0
  integer, parameter, public :: IRRIGATION_DEPTH_BIND_INVALID = 1
  real(real64), parameter :: SOURCE_NODE_TOLERANCE_CM = 1.0e-5_real64
  public :: bind_irrigation_depth_to_nodes
contains
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
