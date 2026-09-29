module mod_ppa_wu05a3_rapid_drain_distribution
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_WU05A3_DISTRIBUTION_OK = 0
  integer, parameter, public :: PPA_WU05A3_DISTRIBUTION_INVALID_INPUT = 1

  public :: ppa_wu05a3_distribute_rapid_drain_flux

contains

  pure subroutine ppa_wu05a3_distribute_rapid_drain_flux(top_compartment, bottom_compartment, &
       component_kd, total_kd, potential_flux, compartment_flux, bounded_flux, status)
    integer, intent(in) :: top_compartment, bottom_compartment
    real(real64), intent(in) :: component_kd(:), total_kd, potential_flux
    real(real64), intent(out) :: compartment_flux(:), bounded_flux
    integer, intent(out) :: status
    integer :: ic, n

    compartment_flux = 0.0_real64
    bounded_flux = 0.0_real64
    status = PPA_WU05A3_DISTRIBUTION_INVALID_INPUT
    n = size(component_kd)
    if (n <= 0 .or. size(compartment_flux) /= n) return
    if (top_compartment < 1 .or. bottom_compartment < top_compartment .or. bottom_compartment > n) return
    if (.not. ieee_is_finite(total_kd) .or. .not. ieee_is_finite(potential_flux)) return
    if (.not. all(ieee_is_finite(component_kd))) return
    if (any(component_kd < 0.0_real64) .or. total_kd < 0.0_real64 .or. potential_flux < 0.0_real64) return

    ! Source: B1.11 SWAP/macrorate.f90 RAPIDDRAIN compartment distribution loop.
    bounded_flux = potential_flux
    do ic = top_compartment, bottom_compartment
      if (total_kd > 1.0e-15_real64) then
        compartment_flux(ic) = potential_flux*component_kd(ic)/total_kd
      else
        compartment_flux(ic) = 0.0_real64
        bounded_flux = 0.0_real64
      end if
    end do
    status = PPA_WU05A3_DISTRIBUTION_OK
  end subroutine ppa_wu05a3_distribute_rapid_drain_flux

end module mod_ppa_wu05a3_rapid_drain_distribution
