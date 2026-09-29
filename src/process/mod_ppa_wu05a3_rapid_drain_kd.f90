module mod_ppa_wu05a3_rapid_drain_kd
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_WU05A3_KD_OK = 0
  integer, parameter, public :: PPA_WU05A3_KD_INVALID_INPUT = 1

  public :: ppa_wu05a3_rapid_drain_conductivity

contains

  pure subroutine ppa_wu05a3_rapid_drain_conductivity(top_compartment, bottom_compartment, saturation_fraction, &
                                                       exponent, dz, pore_diameter, pore_volume, &
                                                       component_kd, total_kd, status)
    integer, intent(in) :: top_compartment, bottom_compartment
    real(real64), intent(in) :: saturation_fraction, exponent
    real(real64), intent(in) :: dz(:), pore_diameter(:), pore_volume(:)
    real(real64), intent(out) :: component_kd(:), total_kd
    integer, intent(out) :: status
    real(real64) :: water_thickness
    integer :: ic, n

    component_kd = 0.0_real64
    total_kd = 0.0_real64
    status = PPA_WU05A3_KD_INVALID_INPUT
    n = size(dz)
    if (n <= 0 .or. size(pore_diameter) /= n .or. size(pore_volume) /= n .or. size(component_kd) /= n) return
    if (top_compartment < 1 .or. bottom_compartment < top_compartment .or. bottom_compartment > n) return
    if (.not. ieee_is_finite(saturation_fraction) .or. .not. ieee_is_finite(exponent)) return
    if (saturation_fraction < 0.0_real64 .or. saturation_fraction > 1.0_real64 .or. exponent <= 0.0_real64) return
    if (.not. all(ieee_is_finite(dz)) .or. .not. all(ieee_is_finite(pore_diameter)) .or. &
        .not. all(ieee_is_finite(pore_volume))) return
    if (any(dz <= 0.0_real64) .or. any(pore_diameter <= 0.0_real64) .or. any(pore_volume < 0.0_real64)) return
    if (any(pore_volume > dz)) return

    ! Source: B1.11 SWAP/macrorate.f90 RAPIDDRAIN, transmissivity loop lines 1890-1896.
    do ic = top_compartment, bottom_compartment
      water_thickness = pore_diameter(ic) * &
                        (1.0_real64 - sqrt(1.0_real64 - pore_volume(ic)/dz(ic)))
      component_kd(ic) = ((water_thickness**exponent)/pore_diameter(ic))*dz(ic)
      if (ic == top_compartment) component_kd(ic) = saturation_fraction*component_kd(ic)
      total_kd = total_kd + component_kd(ic)
    end do

    if (.not. all(ieee_is_finite(component_kd)) .or. .not. ieee_is_finite(total_kd)) then
      component_kd = 0.0_real64
      total_kd = 0.0_real64
      return
    end if
    status = PPA_WU05A3_KD_OK
  end subroutine ppa_wu05a3_rapid_drain_conductivity

end module mod_ppa_wu05a3_rapid_drain_kd
