module mod_ppa_wu05a3_satflow_exchange
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_WU05A3_SATFLOW_OK = 0
  integer, parameter, public :: PPA_WU05A3_SATFLOW_INVALID_INPUT = 1

  public :: ppa_wu05a3_satflow_exchange

contains

  pure subroutine ppa_wu05a3_satflow_exchange(matrix_head, reference_level, node_elevation, compartment_thickness, &
       matrix_saturated_level, matrix_saturated_compartment, saturated_zone_top_compartment, compartment, &
       saturation_fraction, darcy_reciprocal_resistance, seepage_switch, ksat_horizontal, pore_diameter, &
       domain_volume_fraction, shape_factor, pi, flow_reduction, time_step, &
       head_difference, signed_potential_flux, status)
    real(real64), intent(in) :: matrix_head, reference_level, node_elevation, compartment_thickness
    real(real64), intent(in) :: matrix_saturated_level, saturation_fraction, darcy_reciprocal_resistance, ksat_horizontal
    real(real64), intent(in) :: pore_diameter, domain_volume_fraction, shape_factor, pi, flow_reduction, time_step
    integer, intent(in) :: matrix_saturated_compartment, saturated_zone_top_compartment, compartment, seepage_switch
    real(real64), intent(out) :: head_difference, signed_potential_flux
    integer, intent(out) :: status
    real(real64) :: macropore_head, reciprocal_resistance, res_horizontal, res_vertical, res_radial

    head_difference = 0.0_real64
    signed_potential_flux = 0.0_real64
    status = PPA_WU05A3_SATFLOW_INVALID_INPUT
    if (.not. ieee_is_finite(matrix_head) .or. .not. ieee_is_finite(reference_level) .or. &
        .not. ieee_is_finite(node_elevation) .or. .not. ieee_is_finite(compartment_thickness) .or. &
        .not. ieee_is_finite(matrix_saturated_level) .or. .not. ieee_is_finite(darcy_reciprocal_resistance) .or. &
        .not. ieee_is_finite(ksat_horizontal) .or. .not. ieee_is_finite(pore_diameter) .or. &
        .not. ieee_is_finite(domain_volume_fraction) .or. .not. ieee_is_finite(saturation_fraction) .or. &
        .not. ieee_is_finite(shape_factor) .or. &
        .not. ieee_is_finite(pi) .or. .not. ieee_is_finite(flow_reduction) .or. &
        .not. ieee_is_finite(time_step)) return
    if (compartment < 1 .or. matrix_saturated_compartment < 0 .or. saturated_zone_top_compartment < 0 .or. &
        compartment_thickness <= 0.0_real64 .or. pore_diameter <= 0.0_real64 .or. &
        domain_volume_fraction < 0.0_real64 .or. domain_volume_fraction > 1.0_real64 .or. &
        ksat_horizontal < 0.0_real64 .or. saturation_fraction < 0.0_real64 .or. saturation_fraction > 1.0_real64 .or. &
        darcy_reciprocal_resistance < 0.0_real64 .or. shape_factor < 0.0_real64 .or. pi <= 0.0_real64 .or. &
        flow_reduction < 0.0_real64 .or. time_step < 0.0_real64) return

    ! Source: B1.11 SWAP/macrorate.f90 SATFLOW, task 1, lines 1519-1565.
    macropore_head = reference_level - node_elevation
    if (macropore_head < 1.0e-8_real64) macropore_head = 0.0_real64
    head_difference = macropore_head - matrix_head
    if (macropore_head < 1.0e-8_real64 .and. head_difference > 0.0_real64) head_difference = 0.0_real64
    if (abs(head_difference) < 1.0e-8_real64) head_difference = 0.0_real64
    if (matrix_head < 0.0_real64) head_difference = 0.0_real64

    if (head_difference > 0.0_real64) then
      reciprocal_resistance = darcy_reciprocal_resistance
      if (compartment == matrix_saturated_compartment) reciprocal_resistance = &
           saturation_fraction*reciprocal_resistance
      signed_potential_flux = -flow_reduction*reciprocal_resistance*head_difference*time_step
    else if (head_difference < 0.0_real64) then
      if (macropore_head > 0.0_real64) then
        reciprocal_resistance = darcy_reciprocal_resistance
        if (compartment == saturated_zone_top_compartment) reciprocal_resistance = reciprocal_resistance * &
             (matrix_saturated_level-(node_elevation-0.5_real64*compartment_thickness))/compartment_thickness
        signed_potential_flux = -flow_reduction*reciprocal_resistance*head_difference*time_step
      else if (seepage_switch == 1) then
        if (ksat_horizontal <= 0.0_real64) return
        res_horizontal = pore_diameter**2/(8.0_real64*compartment_thickness*ksat_horizontal)
        res_vertical = compartment_thickness/ksat_horizontal
        res_radial = pore_diameter*log(10.0_real64)/(pi*ksat_horizontal)
        reciprocal_resistance = domain_volume_fraction/(res_horizontal+res_vertical+res_radial)
        if (compartment == saturated_zone_top_compartment) reciprocal_resistance = reciprocal_resistance * &
             (matrix_saturated_level-(node_elevation-0.5_real64*compartment_thickness))/compartment_thickness
        signed_potential_flux = -flow_reduction*reciprocal_resistance*head_difference*time_step
      else
        reciprocal_resistance = shape_factor*16.0_real64/pore_diameter**2 * &
                                ksat_horizontal*compartment_thickness
        if (compartment == saturated_zone_top_compartment) reciprocal_resistance = reciprocal_resistance * &
             (matrix_saturated_level-(node_elevation-0.5_real64*compartment_thickness))/compartment_thickness
        signed_potential_flux = -flow_reduction*reciprocal_resistance*head_difference*time_step
      end if
    end if

    if (.not. ieee_is_finite(head_difference) .or. .not. ieee_is_finite(signed_potential_flux)) then
      head_difference = 0.0_real64
      signed_potential_flux = 0.0_real64
      return
    end if
    status = PPA_WU05A3_SATFLOW_OK
  end subroutine ppa_wu05a3_satflow_exchange

end module mod_ppa_wu05a3_satflow_exchange
