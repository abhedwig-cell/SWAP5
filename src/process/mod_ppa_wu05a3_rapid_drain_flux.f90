module mod_ppa_wu05a3_rapid_drain_flux
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_WU05A3_FLUX_OK = 0
  integer, parameter, public :: PPA_WU05A3_FLUX_INVALID_INPUT = 1

  public :: ppa_wu05a3_rapid_drain_flux

contains

  pure subroutine ppa_wu05a3_rapid_drain_flux(z_water_level, drain_base, macropore_bottom, ponding, &
                                               transmissivity, reference_transmissivity, reference_resistance, &
                                               flow_reduction, time_step, drainable_storage, resistance, &
                                               potential_flux, status)
    real(real64), intent(in) :: z_water_level, drain_base, macropore_bottom, ponding
    real(real64), intent(in) :: transmissivity, reference_transmissivity, reference_resistance
    real(real64), intent(in) :: flow_reduction, time_step, drainable_storage
    real(real64), intent(out) :: resistance, potential_flux
    integer, intent(out) :: status
    real(real64) :: head_difference, resistance_factor

    resistance = 0.0_real64
    potential_flux = 0.0_real64
    status = PPA_WU05A3_FLUX_INVALID_INPUT
    if (.not. ieee_is_finite(z_water_level) .or. .not. ieee_is_finite(drain_base) .or. &
        .not. ieee_is_finite(macropore_bottom) .or. .not. ieee_is_finite(ponding) .or. &
        .not. ieee_is_finite(transmissivity) .or. .not. ieee_is_finite(reference_transmissivity) .or. &
        .not. ieee_is_finite(reference_resistance) .or. .not. ieee_is_finite(flow_reduction) .or. &
        .not. ieee_is_finite(time_step) .or. .not. ieee_is_finite(drainable_storage)) return
    if (ponding < 0.0_real64 .or. transmissivity < 0.0_real64 .or. reference_transmissivity < 0.0_real64 .or. &
        reference_resistance <= 0.0_real64 .or. flow_reduction < 0.0_real64 .or. flow_reduction > 1.0_real64 .or. &
        time_step < 0.0_real64 .or. drainable_storage < 0.0_real64) return

    ! Source: B1.11 SWAP/macrorate.f90 RAPIDDRAIN, lines 1914-1928.
    head_difference = z_water_level - max(drain_base, macropore_bottom)
    if (z_water_level > -1.0e-7_real64) head_difference = head_difference + ponding
    head_difference = max(head_difference, 0.0_real64)
    if (transmissivity > 1.0e-10_real64) then
      resistance_factor = min(reference_transmissivity/transmissivity, 1.1_real64)
      resistance = reference_resistance*resistance_factor
      potential_flux = flow_reduction*(head_difference/resistance)*time_step
    end if
    potential_flux = min(potential_flux, drainable_storage)

    if (.not. ieee_is_finite(resistance) .or. .not. ieee_is_finite(potential_flux)) then
      resistance = 0.0_real64
      potential_flux = 0.0_real64
      return
    end if
    status = PPA_WU05A3_FLUX_OK
  end subroutine ppa_wu05a3_rapid_drain_flux

end module mod_ppa_wu05a3_rapid_drain_flux
