module mod_ppa_wu05a3_rapid_drain
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_ppa_wu05a3_rapid_drain_kd, only: ppa_wu05a3_rapid_drain_conductivity, PPA_WU05A3_KD_OK
  use mod_ppa_wu05a3_drainable_storage, only: ppa_wu05a3_drainable_storage, PPA_WU05A3_STORAGE_OK
  use mod_ppa_wu05a3_rapid_drain_flux, only: ppa_wu05a3_rapid_drain_flux, PPA_WU05A3_FLUX_OK
  use mod_ppa_wu05a3_rapid_drain_distribution, only: ppa_wu05a3_distribute_rapid_drain_flux, &
                                                      PPA_WU05A3_DISTRIBUTION_OK
  implicit none
  private

  integer, parameter, public :: PPA_WU05A3_RAPID_DRAIN_OK = 0
  integer, parameter, public :: PPA_WU05A3_RAPID_DRAIN_INVALID_INPUT = 1
  integer, parameter, public :: PPA_WU05A3_RAPID_DRAIN_INACTIVE = 2
  integer, parameter, public :: PPA_WU05A3_RAPID_DRAIN_COMPONENT_FAILURE = 3

  public :: ppa_wu05a3_rapid_drain

contains

  pure subroutine ppa_wu05a3_rapid_drain(domain_id, top_compartment, bottom_compartment, rapid_drain_enabled, &
       drain_base, drain_type, open_drain_type, saturation_fraction, exponent, dz, pore_diameter, pore_volume, &
       domain_storage, macropore_bottom, z_water_level, ponding, reference_transmissivity, reference_resistance, &
       flow_reduction, time_step, component_flux, total_flux, resistance, total_kd, status)
    integer, intent(in) :: domain_id, top_compartment, bottom_compartment, drain_type, open_drain_type
    logical, intent(in) :: rapid_drain_enabled
    real(real64), intent(in) :: drain_base, saturation_fraction, exponent, domain_storage, macropore_bottom
    real(real64), intent(in) :: z_water_level, ponding, reference_transmissivity, reference_resistance
    real(real64), intent(in) :: flow_reduction, time_step, dz(:), pore_diameter(:), pore_volume(:)
    real(real64), intent(out) :: component_flux(:), total_flux, resistance, total_kd
    integer, intent(out) :: status
    real(real64) :: component_kd(size(dz)), drainable, bounded_total_flux
    integer :: component_status

    component_flux = 0.0_real64
    total_flux = 0.0_real64
    resistance = 0.0_real64
    total_kd = 0.0_real64
    status = PPA_WU05A3_RAPID_DRAIN_INVALID_INPUT
    if (size(dz) <= 0 .or. size(component_flux) /= size(dz)) return
    if (domain_id < 1 .or. top_compartment < 1 .or. bottom_compartment < top_compartment .or. &
        bottom_compartment > size(dz)) return
    if (.not. ieee_is_finite(drain_base) .or. .not. ieee_is_finite(domain_storage) .or. &
        .not. ieee_is_finite(macropore_bottom) .or. .not. ieee_is_finite(z_water_level) .or. &
        .not. ieee_is_finite(ponding)) return

    ! Source: B1.11 SWAP/macrorate.f90 RAPIDDRAIN, domain/switch/drain-type guards.
    if (domain_id /= 1) then
      status = PPA_WU05A3_RAPID_DRAIN_INACTIVE
      return
    end if
    if (.not. rapid_drain_enabled) then
      status = PPA_WU05A3_RAPID_DRAIN_INACTIVE
      return
    end if
    if (.not. (macropore_bottom < drain_base .or. drain_type /= open_drain_type)) then
      status = PPA_WU05A3_RAPID_DRAIN_INACTIVE
      return
    end if

    call ppa_wu05a3_rapid_drain_conductivity(top_compartment, bottom_compartment, saturation_fraction, exponent, &
         dz, pore_diameter, pore_volume, component_kd, total_kd, component_status)
    if (component_status /= PPA_WU05A3_KD_OK) then
      status = PPA_WU05A3_RAPID_DRAIN_COMPONENT_FAILURE
      return
    end if
    call ppa_wu05a3_drainable_storage(drain_base, macropore_bottom, bottom_compartment, dz, pore_volume, &
                                     domain_storage, drainable, component_status)
    if (component_status /= PPA_WU05A3_STORAGE_OK) then
      status = PPA_WU05A3_RAPID_DRAIN_COMPONENT_FAILURE
      return
    end if
    call ppa_wu05a3_rapid_drain_flux(z_water_level, drain_base, macropore_bottom, ponding, total_kd, &
         reference_transmissivity, reference_resistance, flow_reduction, time_step, drainable, resistance, &
         total_flux, component_status)
    if (component_status /= PPA_WU05A3_FLUX_OK) then
      status = PPA_WU05A3_RAPID_DRAIN_COMPONENT_FAILURE
      return
    end if
    call ppa_wu05a3_distribute_rapid_drain_flux(top_compartment, bottom_compartment, component_kd, total_kd, &
         total_flux, component_flux, bounded_total_flux, component_status)
    if (component_status /= PPA_WU05A3_DISTRIBUTION_OK) then
      status = PPA_WU05A3_RAPID_DRAIN_COMPONENT_FAILURE
      return
    end if
    total_flux = bounded_total_flux
    status = PPA_WU05A3_RAPID_DRAIN_OK
  end subroutine ppa_wu05a3_rapid_drain

end module mod_ppa_wu05a3_rapid_drain
