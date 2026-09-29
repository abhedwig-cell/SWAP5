! PPA-WU05-A3 isolated source oracle for MACROGEOM domain-bottom lumping.
! No production domain/state owner is implemented in this module.
module mod_ppa_wu05a3_macrogeom_lumping
  use, intrinsic :: iso_fortran_env, only: real64, int32
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer(int32), parameter, public :: PPA_WU05A3_MACROGEOM_LUMPING_OK = 0_int32
  integer(int32), parameter, public :: PPA_WU05A3_MACROGEOM_LUMPING_INVALID = 1_int32
  public :: ppa_wu05a3_macrogeom_lumping

contains

  subroutine ppa_wu05a3_macrogeom_lumping(num_nodes, num_subdomains, rz_ah, &
      num_domains, pp_domain, domain_bottom, status)
    integer(int32), intent(in) :: num_nodes, num_subdomains
    real(real64), intent(in) :: rz_ah
    integer(int32), intent(inout) :: num_domains
    real(real64), intent(inout) :: pp_domain(:,:)
    integer(int32), intent(out) :: domain_bottom(:)
    integer(int32), intent(out) :: status
    integer(int32) :: id, ic, jd, num_hlp, last_node

    status = PPA_WU05A3_MACROGEOM_LUMPING_INVALID
    domain_bottom = 0_int32
    if (num_nodes < 1 .or. num_subdomains < 0 .or. num_domains < 1) return
    if (.not. ieee_is_finite(rz_ah) .or. rz_ah < 0.0_real64 .or. rz_ah > 1.0_real64) return
    if (num_domains > size(pp_domain,1) .or. num_domains+1 > size(pp_domain,1)) return
    if (num_nodes > size(pp_domain,2) .or. num_subdomains+1 > size(domain_bottom)) return
    if (.not. all(ieee_is_finite(pp_domain))) return
    if (any(pp_domain < 0.0_real64)) return

    domain_bottom(1) = num_nodes
    do id = 2_int32, num_domains
      ic = 1_int32
      do while (ic <= num_nodes)
        if (pp_domain(id,ic) <= 0.0_real64) exit
        ic = ic + 1_int32
      end do
      domain_bottom(id) = ic - 1_int32
    end do

    num_hlp = num_domains
    if (rz_ah > 1.0e-3_real64) num_hlp = num_hlp - 1_int32
    do id = num_hlp, 3_int32, -1_int32
      if (domain_bottom(id) == domain_bottom(id-1)) then
        last_node = min(num_nodes,domain_bottom(id))
        do ic = 1_int32, last_node
          pp_domain(id-1,ic) = pp_domain(id-1,ic) + pp_domain(id,ic)
        end do
        do jd = id, num_domains-1_int32
          last_node = min(num_nodes,domain_bottom(jd))
          do ic = 1_int32, last_node
            pp_domain(jd,ic) = pp_domain(jd+1,ic)
            pp_domain(jd+1,ic) = 0.0_real64
          end do
          domain_bottom(jd) = domain_bottom(jd+1)
        end do
        num_domains = num_domains - 1_int32
      end if
    end do

    if (num_domains > 1 .and. rz_ah > 1.0e-3_real64 .and. &
        pp_domain(num_domains,1) > 2.0_real64*pp_domain(num_domains-1,1)) then
      if (domain_bottom(num_domains) == domain_bottom(num_domains-1)) then
        last_node = min(num_nodes,domain_bottom(num_domains))
        do ic = 1_int32, last_node
          pp_domain(num_domains-1,ic) = pp_domain(num_domains-1,ic) + &
              pp_domain(num_domains,ic)
          pp_domain(num_domains,ic) = 0.0_real64
        end do
        num_domains = num_domains - 1_int32
      end if
    end if
    do id = num_domains+1_int32, num_subdomains+1_int32
      domain_bottom(id) = 0_int32
    end do
    status = PPA_WU05A3_MACROGEOM_LUMPING_OK
  end subroutine ppa_wu05a3_macrogeom_lumping

end module mod_ppa_wu05a3_macrogeom_lumping
