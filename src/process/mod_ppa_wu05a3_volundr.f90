module mod_ppa_wu05a3_volundr
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_WU05A3_OK = 0
  integer, parameter, public :: PPA_WU05A3_INVALID_INPUT = 1

  public :: ppa_wu05a3_volume_under_level

contains

  pure subroutine ppa_wu05a3_volume_under_level(z_top, z_bottom, bottom_compartment, dz, pore_volume, volume, status)
    real(real64), intent(in) :: z_top, z_bottom
    integer, intent(in) :: bottom_compartment
    real(real64), intent(in) :: dz(:), pore_volume(:)
    real(real64), intent(out) :: volume
    integer, intent(out) :: status
    real(real64) :: z_help
    integer :: ic, n

    volume = 0.0_real64
    status = PPA_WU05A3_INVALID_INPUT
    n = size(dz)
    if (n <= 0 .or. size(pore_volume) /= n) return
    if (bottom_compartment < 0 .or. bottom_compartment > n) return
    if (.not. ieee_is_finite(z_top) .or. .not. ieee_is_finite(z_bottom)) return
    if (.not. all(ieee_is_finite(dz)) .or. .not. all(ieee_is_finite(pore_volume))) return
    if (any(dz <= 0.0_real64) .or. any(pore_volume < 0.0_real64)) return

    ! Source: B1.11 SWAP/macrorate.f90 VOLUNDR, lines 1955-1963.
    ic = bottom_compartment + 1
    z_help = z_bottom
    do while (z_help < z_top .and. ic > 1)
      ic = ic - 1
      z_help = z_help + dz(ic)
      volume = volume + pore_volume(ic)
    end do
    if (volume > 0.0_real64) volume = volume - (z_help-z_top)*pore_volume(ic)/dz(ic)

    if (.not. ieee_is_finite(volume)) then
      volume = 0.0_real64
      return
    end if
    status = PPA_WU05A3_OK
  end subroutine ppa_wu05a3_volume_under_level

end module mod_ppa_wu05a3_volundr
