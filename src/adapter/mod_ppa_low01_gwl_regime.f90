module mod_ppa_low01_gwl_regime
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_LOW01_REGIME_INVALID = 0
  integer, parameter, public :: PPA_LOW01_REGIME_FIXED_TOP = 1
  integer, parameter, public :: PPA_LOW01_REGIME_WITHIN_PROFILE = 2
  integer, parameter, public :: PPA_LOW01_REGIME_BELOW_PROFILE = 3
  public :: classify_ppa_low01_gwl_regime

contains

  ! Pure translation of HeadCalc's SWBOTB=1 top/in-profile/below-profile selector.
  ! This reports the legacy regime only; it does not evolve hydraulic state.
  subroutine classify_ppa_low01_gwl_regime(z_nodes, compartment_dz, nihil, gwlinp, &
      regime, nn, snapped_gwlinp, hbot, status)
    real(real64), intent(in) :: z_nodes(:), compartment_dz(:), nihil, gwlinp
    integer, intent(out) :: regime, nn, status
    real(real64), intent(out) :: snapped_gwlinp, hbot
    integer :: numnod

    regime = PPA_LOW01_REGIME_INVALID
    nn = 0
    snapped_gwlinp = gwlinp
    hbot = 0.0_real64
    status = PPA_LOW01_REGIME_INVALID
    if (size(z_nodes) < 2) return
    numnod = size(z_nodes)-1
    if (size(compartment_dz) /= numnod) return
    if (.not. ieee_is_finite(nihil) .or. .not. ieee_is_finite(gwlinp)) return
    if (.not. all(ieee_is_finite(z_nodes)) .or. .not. all(ieee_is_finite(compartment_dz))) return
    if (any(compartment_dz <= 0.0_real64)) return
    if (any(z_nodes(2:) >= z_nodes(:numnod))) return

    if (gwlinp >= z_nodes(1)-1.0e-4_real64) then
      regime = PPA_LOW01_REGIME_FIXED_TOP
      status = regime
      return
    end if

    nn = 0
    do while (z_nodes(nn+1) > gwlinp .and. nn < numnod)
      nn = nn + 1
    end do
    if (z_nodes(nn+1) < gwlinp + nihil) then
      regime = PPA_LOW01_REGIME_WITHIN_PROFILE
      if ((z_nodes(nn)-gwlinp) < 1.0e-4_real64 .and. nn > 0) then
        snapped_gwlinp = z_nodes(nn)
        nn = nn - 1
      end if
    else
      regime = PPA_LOW01_REGIME_BELOW_PROFILE
      hbot = gwlinp - z_nodes(numnod) + 0.5_real64*compartment_dz(numnod)
    end if
    status = regime
  end subroutine classify_ppa_low01_gwl_regime

end module mod_ppa_low01_gwl_regime
