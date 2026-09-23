module mod_ppa_wu05a3_absorption_darcy
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_WU05A3_ABSORPTION_DARCY_OK = 0
  integer, parameter, public :: PPA_WU05A3_ABSORPTION_DARCY_INVALID_INPUT = 1
  integer, parameter, public :: PPA_WU05A3_ABSORPTION_DARCY_INACTIVE = 2

  public :: ppa_wu05a3_absorption_darcy_candidate

contains

  pure subroutine ppa_wu05a3_absorption_darcy_candidate(darcy_enabled, compartment, water_storage_top, &
       matrix_head, matrix_entry_head, macropore_water_level, node_elevation, theta_s, theta, theta_r, &
       sorptivity_alpha, sorptivity_factor_parameter, pore_diameter, domain_proportion, compartment_thickness, &
       hydraulic_conductivity, shape_factor, time_step, apply_wall_wetting, wall_wetting_factor, &
       head_difference, sorptivity_factor, darcy_potential, factor_defined, status)
    logical, intent(in) :: darcy_enabled, apply_wall_wetting
    integer, intent(in) :: compartment, water_storage_top
    real(real64), intent(in) :: matrix_head, matrix_entry_head, macropore_water_level, node_elevation
    real(real64), intent(in) :: theta_s, theta, theta_r, sorptivity_alpha, sorptivity_factor_parameter
    real(real64), intent(in) :: pore_diameter, domain_proportion, compartment_thickness
    real(real64), intent(in) :: hydraulic_conductivity, shape_factor, time_step, wall_wetting_factor
    real(real64), intent(out) :: head_difference, sorptivity_factor, darcy_potential
    logical, intent(out) :: factor_defined
    integer, intent(out) :: status
    real(real64) :: macropore_head, reciprocal_resistance, saturation_deficit

    head_difference=0.0_real64
    sorptivity_factor=0.0_real64
    darcy_potential=0.0_real64
    factor_defined=.false.
    status=PPA_WU05A3_ABSORPTION_DARCY_INVALID_INPUT
    if (.not. ieee_is_finite(matrix_head) .or. .not. ieee_is_finite(matrix_entry_head) .or. &
        .not. ieee_is_finite(macropore_water_level) .or. .not. ieee_is_finite(node_elevation) .or. &
        .not. ieee_is_finite(theta_s) .or. .not. ieee_is_finite(theta) .or. .not. ieee_is_finite(theta_r) .or. &
        .not. ieee_is_finite(sorptivity_alpha) .or. .not. ieee_is_finite(sorptivity_factor_parameter) .or. &
        .not. ieee_is_finite(pore_diameter) .or. .not. ieee_is_finite(domain_proportion) .or. &
        .not. ieee_is_finite(compartment_thickness) .or. .not. ieee_is_finite(hydraulic_conductivity) .or. &
        .not. ieee_is_finite(shape_factor) .or. .not. ieee_is_finite(time_step) .or. &
        .not. ieee_is_finite(wall_wetting_factor)) return
    if (compartment < 1 .or. water_storage_top < 0 .or. theta_s <= theta_r .or. &
        sorptivity_alpha <= 0.0_real64 .or. pore_diameter <= 0.0_real64 .or. &
        domain_proportion < 0.0_real64 .or. compartment_thickness <= 0.0_real64 .or. &
        hydraulic_conductivity < 0.0_real64 .or. shape_factor < 0.0_real64 .or. time_step < 0.0_real64 .or. &
        sorptivity_factor_parameter < 0.0_real64 .or. sorptivity_factor_parameter > 1.0_real64 .or. &
        wall_wetting_factor < 0.0_real64) return

    ! Source: B1.11 SWAP/macrorate.f90 ABSORPTION lines 1764-1787.
    if (.not. darcy_enabled .or. compartment <= water_storage_top) then
      status=PPA_WU05A3_ABSORPTION_DARCY_INACTIVE
      return
    end if
    macropore_head=max(0.0_real64,macropore_water_level-node_elevation)
    if (matrix_head < matrix_entry_head-1.0e-8_real64 .and. macropore_head > 1.0e-8_real64) then
      head_difference=max(0.0_real64,macropore_head-matrix_head)
    end if
    reciprocal_resistance=shape_factor*8.0_real64*domain_proportion*compartment_thickness* &
         hydraulic_conductivity/pore_diameter**2
    if (apply_wall_wetting .and. compartment == water_storage_top) &
         reciprocal_resistance=wall_wetting_factor*reciprocal_resistance
    darcy_potential=reciprocal_resistance*head_difference*time_step
    saturation_deficit=max(theta_s-theta,0.0_real64)
    sorptivity_factor=sorptivity_factor_parameter+(1.0_real64-sorptivity_factor_parameter) * &
         (1.0_real64-(saturation_deficit/(theta_s-theta_r))**sorptivity_alpha)
    factor_defined=.true.
    if (.not. ieee_is_finite(head_difference) .or. .not. ieee_is_finite(sorptivity_factor) .or. &
        .not. ieee_is_finite(darcy_potential)) then
      head_difference=0.0_real64
      sorptivity_factor=0.0_real64
      darcy_potential=0.0_real64
      factor_defined=.false.
      return
    end if
    status=PPA_WU05A3_ABSORPTION_DARCY_OK
  end subroutine ppa_wu05a3_absorption_darcy_candidate

end module mod_ppa_wu05a3_absorption_darcy
