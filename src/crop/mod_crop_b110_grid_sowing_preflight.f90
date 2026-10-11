module mod_crop_b110_grid_sowing_preflight
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_crop_b111_sowing_node, only: b111_sowing_temperature_node, CROP_SOW_NODE_OK
  implicit none
  private
  integer, parameter, public :: CROP_GRID_SOW_OK=0, CROP_GRID_SOW_INVALID=1, &
       CROP_GRID_SOW_OUTSIDE=2
  public :: preflight_b110_grid_sowing_node
contains
  ! B110 geometry and historical B1.11 node selection. Read-only.
  ! Parameters passed here are NOT certified against F-KT committed state.
  pure subroutine preflight_b110_grid_sowing_node(ztempsow,z,dz,node,status)
    real(real64), intent(in) :: ztempsow,z(:),dz(:)
    integer, intent(out) :: node,status
    real(real64) :: bottom
    real(real64) :: zbotcp(size(dz))
    integer :: i, node_status
    node=0
    status=CROP_GRID_SOW_INVALID
    if(size(dz)<1.or.size(z)/=size(dz)) return
    if (.not.ieee_is_finite(ztempsow)) return
    if(.not.all(ieee_is_finite(z)).or..not.all(ieee_is_finite(dz))) return
    if(any(dz<=0.0_real64)) return
    bottom=0.0_real64
    do i=1,size(dz)
      if(z(i)/=bottom-0.5_real64*dz(i)) return
      bottom=bottom-dz(i)
      if(.not.ieee_is_finite(bottom)) return
      zbotcp(i)=bottom
    end do
    call b111_sowing_temperature_node(ztempsow,zbotcp,node,node_status)
    if(node_status==CROP_SOW_NODE_OK) then
      status=CROP_GRID_SOW_OK
    else
      status=CROP_GRID_SOW_OUTSIDE
    end if
  end subroutine
end module
