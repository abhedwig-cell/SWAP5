module mod_ppa_wu05a3_absorption_diffusion
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_WU05A3_ABSORPTION_DIFFUSION_OK = 0
  integer, parameter, public :: PPA_WU05A3_ABSORPTION_DIFFUSION_INVALID_INPUT = 1

  public :: ppa_wu05a3_absorption_diffusion

contains

  pure subroutine ppa_wu05a3_absorption_diffusion(theta_s, theta, diffusivity_macropore_wall, &
       diffusivity_matrix_aggregate, pore_diameter, unsaturated_volume_fraction, domain_proportion, &
       compartment_thickness, time_step, apply_wall_wetting, wall_wetting_factor, absorbed_potential, status)
    real(real64), intent(in) :: theta_s, theta, diffusivity_macropore_wall, diffusivity_matrix_aggregate
    real(real64), intent(in) :: pore_diameter, unsaturated_volume_fraction, domain_proportion
    real(real64), intent(in) :: compartment_thickness, time_step, wall_wetting_factor
    logical, intent(in) :: apply_wall_wetting
    real(real64), intent(out) :: absorbed_potential
    integer, intent(out) :: status
    real(real64), parameter :: critical_deficit=1.0e-8_real64
    real(real64), parameter :: absorption_shape=8.0_real64
    real(real64), parameter :: gamma_scale=0.4_real64
    real(real64) :: saturation_deficit, average_diffusivity, sorption_rate

    absorbed_potential=0.0_real64
    status=PPA_WU05A3_ABSORPTION_DIFFUSION_INVALID_INPUT
    if (.not. ieee_is_finite(theta_s) .or. .not. ieee_is_finite(theta) .or. &
        .not. ieee_is_finite(diffusivity_macropore_wall) .or. .not. ieee_is_finite(diffusivity_matrix_aggregate) .or. &
        .not. ieee_is_finite(pore_diameter) .or. .not. ieee_is_finite(unsaturated_volume_fraction) .or. &
        .not. ieee_is_finite(domain_proportion) .or. .not. ieee_is_finite(compartment_thickness) .or. &
        .not. ieee_is_finite(time_step) .or. .not. ieee_is_finite(wall_wetting_factor)) return
    if (theta_s <= 0.0_real64 .or. diffusivity_macropore_wall < 0.0_real64 .or. &
        diffusivity_matrix_aggregate < 0.0_real64 .or. pore_diameter <= 0.0_real64 .or. &
        unsaturated_volume_fraction < 0.0_real64 .or. unsaturated_volume_fraction >= 1.0_real64 .or. &
        domain_proportion < 0.0_real64 .or. compartment_thickness <= 0.0_real64 .or. &
        time_step < 0.0_real64 .or. wall_wetting_factor < 0.0_real64) return

    ! Source: B1.11 SWAP/macrorate.f90 ABSORPTION diffusion branch, lines 1751-1762.
    saturation_deficit=max(theta_s-theta,0.0_real64)
    if (saturation_deficit >= critical_deficit) then
      average_diffusivity=(diffusivity_macropore_wall+diffusivity_matrix_aggregate)/2.0_real64
      sorption_rate=(4.0_real64*absorption_shape*average_diffusivity*gamma_scale) / &
           (pore_diameter**2*(1.0_real64-unsaturated_volume_fraction))*(theta_s-theta)
      absorbed_potential=sorption_rate*domain_proportion*compartment_thickness*time_step
    end if
    if (apply_wall_wetting) absorbed_potential=wall_wetting_factor*absorbed_potential
    if (.not. ieee_is_finite(absorbed_potential)) then
      absorbed_potential=0.0_real64
      return
    end if
    status=PPA_WU05A3_ABSORPTION_DIFFUSION_OK
  end subroutine ppa_wu05a3_absorption_diffusion

end module mod_ppa_wu05a3_absorption_diffusion
