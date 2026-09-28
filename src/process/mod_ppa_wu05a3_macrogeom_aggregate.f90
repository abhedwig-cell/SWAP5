! PPA-WU05-A3 isolated source oracle for MACROGEOM per-cell aggregation.
! No production state ownership or runtime binding is provided here.
module mod_ppa_wu05a3_macrogeom_aggregate
  use, intrinsic :: iso_fortran_env, only: real64, int32
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer(int32), parameter, public :: PPA_WU05A3_MACROGEOM_AGGREGATE_OK = 0_int32
  integer(int32), parameter, public :: PPA_WU05A3_MACROGEOM_AGGREGATE_INVALID = 1_int32
  public :: ppa_wu05a3_macrogeom_aggregate

contains

  subroutine ppa_wu05a3_macrogeom_aggregate(rel_mb, rel_ic, rel_mb_static, &
      rel_ic_static, vl_mp_static_surface, dz, pp_ic_cp, vl_mp_static_cp, &
      frac_area_matrix, status)
    real(real64), intent(in) :: rel_mb, rel_ic, rel_mb_static, rel_ic_static
    real(real64), intent(in) :: vl_mp_static_surface, dz
    real(real64), intent(out) :: pp_ic_cp, vl_mp_static_cp, frac_area_matrix
    integer(int32), intent(out) :: status

    status = PPA_WU05A3_MACROGEOM_AGGREGATE_INVALID
    pp_ic_cp = 0.0_real64
    vl_mp_static_cp = 0.0_real64
    frac_area_matrix = 0.0_real64
    if (.not. all(ieee_is_finite([rel_mb,rel_ic,rel_mb_static,rel_ic_static, &
        vl_mp_static_surface,dz]))) return
    if (rel_mb < 0.0_real64 .or. rel_ic < 0.0_real64 .or. &
        rel_mb_static < 0.0_real64 .or. rel_ic_static < 0.0_real64 .or. &
        vl_mp_static_surface < 0.0_real64 .or. dz <= 0.0_real64) return

    if (rel_ic > 0.0_real64) then
      if (rel_mb+rel_ic <= 0.0_real64) return
      pp_ic_cp = rel_ic/(rel_mb+rel_ic)
    else
      pp_ic_cp = 0.0_real64
    end if
    vl_mp_static_cp = vl_mp_static_surface*(rel_mb_static+rel_ic_static)
    frac_area_matrix = 1.0_real64-vl_mp_static_cp/dz
    if (.not. all(ieee_is_finite([pp_ic_cp,vl_mp_static_cp,frac_area_matrix]))) then
      pp_ic_cp = 0.0_real64
      vl_mp_static_cp = 0.0_real64
      frac_area_matrix = 0.0_real64
      return
    end if
    status = PPA_WU05A3_MACROGEOM_AGGREGATE_OK
  end subroutine ppa_wu05a3_macrogeom_aggregate

end module mod_ppa_wu05a3_macrogeom_aggregate
