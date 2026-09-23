! PPA-WU05-A3 isolated source oracle for MACROGEOM top-layer suppression.
! It owns no production macropore state and is not a runtime route.
module mod_ppa_wu05a3_macrogeom_top_suppression
  use, intrinsic :: iso_fortran_env, only: real64, int32
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer(int32), parameter, public :: PPA_WU05A3_TOP_SUPPRESSION_OK = 0_int32
  integer(int32), parameter, public :: PPA_WU05A3_TOP_SUPPRESSION_INVALID = 1_int32
  public :: ppa_wu05a3_macrogeom_top_suppression

contains

  subroutine ppa_wu05a3_macrogeom_top_suppression(ic_top_mp, num_nodes, num_domains, &
      pp_ic_cp, vl_mp_static_domain1, vl_mp_static_domain2, vl_mp_static_cp, &
      frac_area_matrix, pp_domain, status)
    integer(int32), intent(in) :: ic_top_mp, num_nodes, num_domains
    real(real64), intent(inout) :: pp_ic_cp(:), vl_mp_static_domain1(:)
    real(real64), intent(inout) :: vl_mp_static_domain2(:), vl_mp_static_cp(:)
    real(real64), intent(inout) :: frac_area_matrix(:), pp_domain(:,:)
    integer(int32), intent(out) :: status

    status = PPA_WU05A3_TOP_SUPPRESSION_INVALID
    if (num_nodes < 1 .or. num_domains < 1 .or. ic_top_mp < 1 .or. ic_top_mp > num_nodes) return
    if (num_nodes > min(size(pp_ic_cp),size(vl_mp_static_domain1), &
        size(vl_mp_static_domain2),size(vl_mp_static_cp),size(frac_area_matrix))) return
    if (num_domains > size(pp_domain,1) .or. num_nodes > size(pp_domain,2)) return
    if (.not. all(ieee_is_finite(pp_ic_cp(1:num_nodes))) .or. &
        .not. all(ieee_is_finite(vl_mp_static_domain1(1:num_nodes))) .or. &
        .not. all(ieee_is_finite(vl_mp_static_domain2(1:num_nodes))) .or. &
        .not. all(ieee_is_finite(vl_mp_static_cp(1:num_nodes))) .or. &
        .not. all(ieee_is_finite(frac_area_matrix(1:num_nodes))) .or. &
        .not. all(ieee_is_finite(pp_domain(1:num_domains,1:num_nodes)))) return

    if (ic_top_mp > 1) then
      pp_ic_cp(1:ic_top_mp-1) = 0.0_real64
      vl_mp_static_domain1(1:ic_top_mp-1) = 0.0_real64
      vl_mp_static_domain2(1:ic_top_mp-1) = 0.0_real64
      vl_mp_static_cp(1:ic_top_mp-1) = 0.0_real64
      pp_domain(1:num_domains,1:ic_top_mp-1) = 0.0_real64
      frac_area_matrix(1:ic_top_mp-1) = 1.0_real64
    end if
    status = PPA_WU05A3_TOP_SUPPRESSION_OK
  end subroutine ppa_wu05a3_macrogeom_top_suppression

end module mod_ppa_wu05a3_macrogeom_top_suppression
