module mod_ppa_wu05a3_sorptivity
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_WU05A3_SORPTIVITY_OK = 0
  integer, parameter, public :: PPA_WU05A3_SORPTIVITY_INVALID_INPUT = 1

  public :: ppa_wu05a3_sorptivity_absorption

contains

  pure subroutine ppa_wu05a3_sorptivity_absorption(theta_s, theta, theta_r, sorptivity_max, sorptivity_alpha, &
       event_time, time_step, domain_proportion, wetting_factor, compartment_thickness, pore_diameter, &
       wall_wetting_factor, apply_wall_wetting, sorptivity_reference_in, sorptivity_in, &
       sorptivity_reference_out, sorptivity_out, absorbed_potential, event_continues, status)
    real(real64), intent(in) :: theta_s, theta, theta_r, sorptivity_max, sorptivity_alpha
    real(real64), intent(in) :: event_time, time_step, domain_proportion, wetting_factor
    real(real64), intent(in) :: compartment_thickness, pore_diameter, wall_wetting_factor
    real(real64), intent(in) :: sorptivity_reference_in, sorptivity_in
    logical, intent(in) :: apply_wall_wetting
    real(real64), intent(out) :: sorptivity_reference_out, sorptivity_out, absorbed_potential
    logical, intent(out) :: event_continues
    integer, intent(out) :: status
    real(real64), parameter :: critical_saturation_deficit = 1.0e-8_real64
    real(real64), parameter :: critical_event_time = 1.0e-8_real64
    real(real64), parameter :: peak_rate = 1.0e3_real64
    real(real64) :: saturation_deficit, active_sorptivity

    sorptivity_reference_out = sorptivity_reference_in
    sorptivity_out = sorptivity_in
    absorbed_potential = 0.0_real64
    event_continues = .false.
    status = PPA_WU05A3_SORPTIVITY_INVALID_INPUT
    if (.not. ieee_is_finite(theta_s) .or. .not. ieee_is_finite(theta) .or. .not. ieee_is_finite(theta_r) .or. &
        .not. ieee_is_finite(sorptivity_max) .or. .not. ieee_is_finite(sorptivity_alpha) .or. &
        .not. ieee_is_finite(event_time) .or. .not. ieee_is_finite(time_step) .or. &
        .not. ieee_is_finite(domain_proportion) .or. .not. ieee_is_finite(wetting_factor) .or. &
        .not. ieee_is_finite(compartment_thickness) .or. .not. ieee_is_finite(pore_diameter) .or. &
        .not. ieee_is_finite(wall_wetting_factor) .or. .not. ieee_is_finite(sorptivity_reference_in) .or. &
        .not. ieee_is_finite(sorptivity_in)) return
    if (theta_s <= theta_r .or. sorptivity_max < 0.0_real64 .or. &
        sorptivity_alpha <= 0.0_real64 .or. event_time < 0.0_real64 .or. time_step <= 0.0_real64 .or. &
        domain_proportion < 0.0_real64 .or. wetting_factor < 0.0_real64 .or. &
        compartment_thickness <= 0.0_real64 .or. pore_diameter <= 0.0_real64 .or. &
        wall_wetting_factor < 0.0_real64) return

    ! Source: B1.11 SWAP/macrorate.f90 ABSORPTION, sorptivity task-1 slice.
    saturation_deficit = max(0.0_real64, theta_s-theta)
    active_sorptivity = 0.0_real64
    if (saturation_deficit >= critical_saturation_deficit) then
      if (event_time < critical_event_time) then
        sorptivity_reference_out = theta_s
        sorptivity_out = sorptivity_max * &
             (max(0.0_real64, theta_s-theta)/(theta_s-theta_r))**sorptivity_alpha
        active_sorptivity = sorptivity_out
      else if ((sorptivity_reference_in-theta) > critical_saturation_deficit) then
        active_sorptivity = sorptivity_max * &
             ((sorptivity_reference_in-theta)/(theta_s-theta_r))**sorptivity_alpha
      end if
      absorbed_potential = active_sorptivity*domain_proportion * &
           (4.0_real64*wetting_factor*compartment_thickness/pore_diameter) * &
           (sqrt(event_time+time_step)-sqrt(event_time))
      if (apply_wall_wetting) absorbed_potential = wall_wetting_factor*absorbed_potential
      absorbed_potential = min(peak_rate*time_step*compartment_thickness, absorbed_potential)
    end if
    event_continues = absorbed_potential/time_step > 1.0e-7_real64
    if (.not. ieee_is_finite(sorptivity_reference_out) .or. .not. ieee_is_finite(sorptivity_out) .or. &
        .not. ieee_is_finite(absorbed_potential)) then
      sorptivity_reference_out = sorptivity_reference_in
      sorptivity_out = sorptivity_in
      absorbed_potential = 0.0_real64
      event_continues = .false.
      return
    end if
    status = PPA_WU05A3_SORPTIVITY_OK
  end subroutine ppa_wu05a3_sorptivity_absorption

end module mod_ppa_wu05a3_sorptivity
