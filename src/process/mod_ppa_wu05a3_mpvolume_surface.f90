! PPA-WU05-A3 isolated MPVOLUME task-1 surface-area/capacity equation oracle.
! This helper returns candidates only; it does not publish macropore state.
module mod_ppa_wu05a3_mpvolume_surface
  use, intrinsic :: iso_fortran_env, only: real64, int32
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer(int32), parameter, public :: PPA_WU05A3_MPVOLUME_SURFACE_OK = 0_int32
  integer(int32), parameter, public :: PPA_WU05A3_MPVOLUME_SURFACE_INVALID = 1_int32
  public :: ppa_wu05a3_mpvolume_surface

contains

  subroutine ppa_wu05a3_mpvolume_surface(num_nodes, num_domains, ic_top_mp, crack_node, &
      dz, subsidy, dynamic_volume, static_volume, diameter, pp_domain, area_dynamic, &
      area_static, area_total, area_domains, area_surface, capacity, status)
    integer(int32), intent(in) :: num_nodes, num_domains, ic_top_mp, crack_node
    real(real64), intent(in) :: dz(:), subsidy(:), dynamic_volume(:), static_volume(:), diameter(:)
    real(real64), intent(in) :: pp_domain(:)
    real(real64), intent(out) :: area_dynamic, area_static, area_total
    real(real64), intent(out) :: area_domains(:), area_surface, capacity
    integer(int32), intent(out) :: status
    integer(int32) :: node
    real(real64) :: area_minimum
    real(real64), parameter :: min_crack_width = 1.0e-3_real64

    status = PPA_WU05A3_MPVOLUME_SURFACE_INVALID
    area_dynamic = 0.0_real64
    area_static = 0.0_real64
    area_total = 0.0_real64
    area_domains = 0.0_real64
    area_surface = 0.0_real64
    capacity = 0.0_real64
    if (num_nodes < 1 .or. num_domains < 1 .or. num_domains > size(pp_domain)) return
    if (ic_top_mp < 1 .or. ic_top_mp > num_nodes .or. crack_node < 1 .or. crack_node > num_nodes) return
    if (num_nodes > min(size(dz),size(subsidy),size(dynamic_volume),size(static_volume),size(diameter))) return
    if (.not. all(ieee_is_finite(dz(1:num_nodes))) .or. &
        .not. all(ieee_is_finite(subsidy(1:num_nodes))) .or. &
        .not. all(ieee_is_finite(dynamic_volume(1:num_nodes))) .or. &
        .not. all(ieee_is_finite(static_volume(1:num_nodes))) .or. &
        .not. all(ieee_is_finite(diameter(1:num_nodes))) .or. &
        .not. all(ieee_is_finite(pp_domain(1:num_domains)))) return
    if (any(dz(1:num_nodes) <= 0.0_real64) .or. any(subsidy(1:num_nodes) < 0.0_real64) .or. &
        any(dynamic_volume(1:num_nodes) < 0.0_real64) .or. &
        any(static_volume(1:num_nodes) < 0.0_real64) .or. &
        any(diameter(1:num_nodes) <= 0.0_real64) .or. &
        any(subsidy(1:num_nodes) >= dz(1:num_nodes)) .or. &
        any(pp_domain(1:num_domains) < 0.0_real64)) return

    node = crack_node
    if (ic_top_mp > crack_node) node = ic_top_mp
    area_dynamic = dynamic_volume(node)/(dz(node)-subsidy(node))
    area_static = static_volume(ic_top_mp)/dz(ic_top_mp)
    area_total = min(0.6_real64,area_dynamic+area_static)
    area_minimum = 1.0_real64-(1.0_real64-min_crack_width/diameter(ic_top_mp))**2
    if (area_total < area_minimum) area_total = 0.0_real64
    area_domains(1:num_domains) = pp_domain(1:num_domains)*area_total
    if (ic_top_mp == 1) area_surface = area_total
    capacity = 2.0_real64*7.2e8_real64 * &
        (diameter(ic_top_mp)*(1.0_real64-sqrt(1.0_real64-area_total)))**3 / diameter(ic_top_mp)
    capacity = min(max(capacity,1.0e-14_real64),1.0e3_real64)
    if (.not. all(ieee_is_finite([area_dynamic,area_static,area_total,area_surface,capacity])) .or. &
        .not. all(ieee_is_finite(area_domains(1:num_domains)))) then
      area_dynamic = 0.0_real64
      area_static = 0.0_real64
      area_total = 0.0_real64
      area_domains = 0.0_real64
      area_surface = 0.0_real64
      capacity = 0.0_real64
      return
    end if
    status = PPA_WU05A3_MPVOLUME_SURFACE_OK
  end subroutine ppa_wu05a3_mpvolume_surface

end module mod_ppa_wu05a3_mpvolume_surface
