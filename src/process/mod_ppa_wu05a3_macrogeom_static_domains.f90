! PPA-WU05-A3 isolated source oracle for static MACROGEOM domain volumes.
! This helper is not a production state owner or runtime route.
module mod_ppa_wu05a3_macrogeom_static_domains
  use, intrinsic :: iso_fortran_env, only: real64, int32
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer(int32), parameter, public :: PPA_WU05A3_STATIC_DOMAINS_OK = 0_int32
  integer(int32), parameter, public :: PPA_WU05A3_STATIC_DOMAINS_INVALID = 1_int32
  public :: ppa_wu05a3_macrogeom_static_domains

contains

  subroutine ppa_wu05a3_macrogeom_static_domains(num_domains, pp_domain, &
      vl_mp_static_cell, vl_mp_static_mb, vl_mp_static_ic, status)
    integer(int32), intent(in) :: num_domains
    real(real64), intent(in) :: pp_domain(:), vl_mp_static_cell
    real(real64), intent(out) :: vl_mp_static_mb, vl_mp_static_ic
    integer(int32), intent(out) :: status

    status = PPA_WU05A3_STATIC_DOMAINS_INVALID
    vl_mp_static_mb = 0.0_real64
    vl_mp_static_ic = 0.0_real64
    if (num_domains < 1 .or. num_domains > size(pp_domain)) return
    if (.not. ieee_is_finite(vl_mp_static_cell) .or. vl_mp_static_cell < 0.0_real64) return
    if (.not. all(ieee_is_finite(pp_domain(1:num_domains)))) return
    if (any(pp_domain(1:num_domains) < 0.0_real64)) return

    vl_mp_static_mb = pp_domain(1)*vl_mp_static_cell
    if (num_domains > 1) then
      vl_mp_static_ic = sum(pp_domain(2:num_domains))*vl_mp_static_cell
    else
      vl_mp_static_ic = 0.0_real64
    end if
    if (.not. all(ieee_is_finite([vl_mp_static_mb,vl_mp_static_ic]))) then
      vl_mp_static_mb = 0.0_real64
      vl_mp_static_ic = 0.0_real64
      return
    end if
    status = PPA_WU05A3_STATIC_DOMAINS_OK
  end subroutine ppa_wu05a3_macrogeom_static_domains

end module mod_ppa_wu05a3_macrogeom_static_domains
