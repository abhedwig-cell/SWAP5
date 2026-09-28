! PPA-WU05-A3 isolated source oracle for MACROINIT crack-area node selection.
! The helper does not own production macropore initialization state.
module mod_ppa_wu05a3_macroinit_crack_node
  use, intrinsic :: iso_fortran_env, only: real64, int32
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer(int32), parameter, public :: PPA_WU05A3_CRACK_NODE_OK = 0_int32
  integer(int32), parameter, public :: PPA_WU05A3_CRACK_NODE_INVALID = 1_int32
  public :: ppa_wu05a3_macroinit_crack_node

contains

  subroutine ppa_wu05a3_macroinit_crack_node(num_nodes, ic_top_mp, z, dz, z_crack_area, &
      crack_area_node, status)
    integer(int32), intent(in) :: num_nodes, ic_top_mp
    real(real64), intent(in) :: z(:), dz(:), z_crack_area
    integer(int32), intent(out) :: crack_area_node, status
    integer(int32) :: ic

    status = PPA_WU05A3_CRACK_NODE_INVALID
    crack_area_node = 0_int32
    if (num_nodes < 1 .or. ic_top_mp < 1 .or. ic_top_mp > num_nodes) return
    if (num_nodes > min(size(z),size(dz))) return
    if (.not. ieee_is_finite(z_crack_area)) return
    if (.not. all(ieee_is_finite(z(1:num_nodes))) .or. &
        .not. all(ieee_is_finite(dz(1:num_nodes)))) return
    if (any(dz(1:num_nodes) <= 0.0_real64)) return

    if (ic_top_mp == 1) then
      do ic = 1_int32, num_nodes
        if ((z(ic)-0.5_real64*dz(ic)+1.0e-2_real64) > z_crack_area) cycle
        crack_area_node = ic
        status = PPA_WU05A3_CRACK_NODE_OK
        return
      end do
      return
    end if
    crack_area_node = ic_top_mp
    status = PPA_WU05A3_CRACK_NODE_OK
  end subroutine ppa_wu05a3_macroinit_crack_node

end module mod_ppa_wu05a3_macroinit_crack_node
