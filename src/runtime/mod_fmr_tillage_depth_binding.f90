module mod_fmr_tillage_depth_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: TILLAGE_DEPTH_OK = 0
  integer, parameter, public :: TILLAGE_DEPTH_INVALID = 1
  public :: bind_tillage_event_depth
contains
  pure subroutine bind_tillage_event_depth(thickness_cm,layer_bottom_node,event_depth_cm,affected,status)
    real(real64), intent(in) :: thickness_cm(:),event_depth_cm
    integer, intent(in) :: layer_bottom_node(:)
    logical, allocatable, intent(out) :: affected(:)
    integer, intent(out) :: status
    real(real64) :: running_depth
    integer :: i,j,n,match_node,previous_bottom
    status = TILLAGE_DEPTH_INVALID
    n = size(thickness_cm)
    if (n < 1 .or. size(layer_bottom_node) < 1) return
    if (.not. ieee_is_finite(event_depth_cm) .or. &
        any(.not. ieee_is_finite(thickness_cm))) return
    if (event_depth_cm <= 0.0_real64 .or. any(thickness_cm <= 0.0_real64)) return
    previous_bottom = 0
    do j=1,size(layer_bottom_node)
      if (layer_bottom_node(j) <= previous_bottom .or. layer_bottom_node(j) > n) return
      previous_bottom = layer_bottom_node(j)
    end do
    if (previous_bottom /= n) return
    running_depth = 0.0_real64
    match_node = 0
    do i=1,n
      running_depth = running_depth+thickness_cm(i)
      do j=1,size(layer_bottom_node)
        if (i /= layer_bottom_node(j)) cycle
        if (abs(running_depth-event_depth_cm) <= &
            1.e-10_real64*max(1.0_real64,event_depth_cm)) match_node = i
      end do
    end do
    if (match_node < 1) return
    allocate(affected(n))
    affected = .false.
    affected(1:match_node) = .true.
    status = TILLAGE_DEPTH_OK
  end subroutine
end module
