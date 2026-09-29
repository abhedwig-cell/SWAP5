! PPA-WU05-A3 isolated source oracle for MACROGEOM compartment domain shares.
! Domain-bottom lumping and production state ownership are deliberately absent.
module mod_ppa_wu05a3_macrogeom_partition
  use, intrinsic :: iso_fortran_env, only: real64, int32
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer(int32), parameter, public :: PPA_WU05A3_MACROGEOM_PARTITION_OK = 0_int32
  integer(int32), parameter, public :: PPA_WU05A3_MACROGEOM_PARTITION_INVALID = 1_int32
  public :: ppa_wu05a3_macrogeom_partition

contains

  subroutine ppa_wu05a3_macrogeom_partition(pp_ic_cp, rel_vl_ic, dz, pp_ic_surface, &
      rz_ah, num_subdomains, max_domains, num_domains, num_subdomains_cell, pp_domain, status)
    real(real64), intent(in) :: pp_ic_cp, rel_vl_ic, dz, pp_ic_surface, rz_ah
    integer(int32), intent(in) :: num_subdomains, max_domains
    integer(int32), intent(out) :: num_domains, num_subdomains_cell, status
    real(real64), intent(out) :: pp_domain(:)
    real(real64) :: un_pp_ic, rel_vl_ic_total
    integer(int32) :: id

    status = PPA_WU05A3_MACROGEOM_PARTITION_INVALID
    num_domains = 0_int32
    num_subdomains_cell = 0_int32
    pp_domain = 0.0_real64
    if (.not. all(ieee_is_finite([pp_ic_cp,rel_vl_ic,dz,pp_ic_surface,rz_ah]))) return
    if (pp_ic_cp < 0.0_real64 .or. pp_ic_cp > 1.0_real64 .or. rel_vl_ic < 0.0_real64 .or. &
        dz <= 0.0_real64 .or. pp_ic_surface < 0.0_real64 .or. pp_ic_surface > 1.0_real64 .or. &
        rz_ah < 0.0_real64 .or. rz_ah > 1.0_real64) return
    if (max_domains < 1 .or. size(pp_domain) < max_domains) return

    if (pp_ic_surface > 0.0_real64) then
      if (rz_ah < 0.991_real64) then
        if (num_subdomains < 1) return
        num_domains = num_subdomains + 1_int32
        if (rz_ah > 1.0e-3_real64) num_domains = num_domains + 1_int32
        if (num_domains > max_domains) return
        un_pp_ic = pp_ic_surface*(1.0_real64-rz_ah)/real(num_subdomains,real64)
        if (pp_ic_cp > 1.0e-3_real64) then
          if (un_pp_ic <= 0.0_real64) return
          num_subdomains_cell = int(rel_vl_ic/(un_pp_ic*dz),int32)
          num_subdomains_cell = min(num_subdomains,num_subdomains_cell)
          pp_domain(1) = 1.0_real64-pp_ic_cp
          do id = 2_int32, num_subdomains_cell+1_int32
            pp_domain(id) = pp_ic_cp*un_pp_ic*dz/rel_vl_ic
          end do
          rel_vl_ic_total = real(num_subdomains_cell,real64)*un_pp_ic*dz
          pp_domain(num_subdomains_cell+2) = pp_ic_cp * &
              (1.0_real64-rel_vl_ic_total/rel_vl_ic)
          do id = num_subdomains_cell+3_int32, num_domains
            pp_domain(id) = 0.0_real64
          end do
        else
          pp_domain(1) = 1.0_real64
        end if
      else
        num_domains = 2_int32
        if (num_domains > max_domains) return
        pp_domain(1) = 1.0_real64-pp_ic_cp
        pp_domain(2) = pp_ic_cp
      end if
    else
      num_domains = 1_int32
      pp_domain(1) = 1.0_real64
    end if
    status = PPA_WU05A3_MACROGEOM_PARTITION_OK
  end subroutine ppa_wu05a3_macrogeom_partition

end module mod_ppa_wu05a3_macrogeom_partition
