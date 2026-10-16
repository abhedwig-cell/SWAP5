module mod_crop_b111_sowing_node
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: CROP_SOW_NODE_OK=0, CROP_SOW_NODE_INVALID=1, CROP_SOW_NODE_OUTSIDE=2
  real(real64), parameter :: SOURCE_EPS=1.0e-8_real64
  public :: b111_sowing_temperature_node
contains
  ! Exact B1.11 cropdevelopment criterion: first zbotcp(i) < ztempsow + 1d-8.
  ! This only resolves a supplied grid, never certifies its F-KT ownership.
  pure subroutine b111_sowing_temperature_node(ztempsow,zbotcp,node,status)
    real(real64), intent(in) :: ztempsow,zbotcp(:)
    integer, intent(out) :: node,status
    integer :: i
    node=0
    status=CROP_SOW_NODE_INVALID
    if (.not.ieee_is_finite(ztempsow)) return
    if(size(zbotcp)==0) return
    if(.not.all(ieee_is_finite(zbotcp))) return
    if(ztempsow>0.0_real64) return
    if(any(zbotcp>=0.0_real64)) return
    do i=2,size(zbotcp)
      if(zbotcp(i)>=zbotcp(i-1)) return
    end do
    status=CROP_SOW_NODE_OUTSIDE
    do i=1,size(zbotcp)
      if(zbotcp(i)<ztempsow+SOURCE_EPS) then
        node=i
        status=CROP_SOW_NODE_OK
        return
      end if
    end do
  end subroutine
end module
