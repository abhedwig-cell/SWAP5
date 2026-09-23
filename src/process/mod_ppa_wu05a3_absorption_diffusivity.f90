module mod_ppa_wu05a3_absorption_diffusivity
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_WU05A3_DIFFUSIVITY_OK = 0
  integer, parameter, public :: PPA_WU05A3_DIFFUSIVITY_INVALID_INPUT = 1

  public :: ppa_wu05a3_absorption_diffusivity

contains

  pure subroutine ppa_wu05a3_absorption_diffusivity(alpha_mualem, saturated_conductivity, m_parameter, &
       theta_capacity_range, pressure_envelope_saturation, one_over_m, lambda_parameter, theta, theta_r, &
       diffusivity, effective_lambda, relative_saturation, status)
    real(real64), intent(in) :: alpha_mualem, saturated_conductivity, m_parameter
    real(real64), intent(in) :: theta_capacity_range, pressure_envelope_saturation, one_over_m, lambda_parameter
    real(real64), intent(in) :: theta, theta_r
    real(real64), intent(out) :: diffusivity, effective_lambda, relative_saturation
    integer, intent(out) :: status
    real(real64) :: help_term

    diffusivity=0.0_real64
    effective_lambda=0.0_real64
    relative_saturation=0.0_real64
    status=PPA_WU05A3_DIFFUSIVITY_INVALID_INPUT
    if (.not. ieee_is_finite(alpha_mualem) .or. .not. ieee_is_finite(saturated_conductivity) .or. &
        .not. ieee_is_finite(m_parameter) .or. .not. ieee_is_finite(theta_capacity_range) .or. &
        .not. ieee_is_finite(pressure_envelope_saturation) .or. .not. ieee_is_finite(one_over_m) .or. &
        .not. ieee_is_finite(lambda_parameter) .or. .not. ieee_is_finite(theta) .or. .not. ieee_is_finite(theta_r)) return
    if (alpha_mualem <= 0.0_real64 .or. saturated_conductivity < 0.0_real64 .or. &
        m_parameter <= 0.0_real64 .or. m_parameter >= 1.0_real64 .or. theta_capacity_range <= 0.0_real64 .or. &
        pressure_envelope_saturation <= 0.0_real64 .or. pressure_envelope_saturation >= 1.0_real64 .or. &
        one_over_m <= 0.0_real64) return

    ! Source: B1.11 SWAP/macrorate.f90 ABSORPTION diffusivity setup, lines 1691-1708.
    effective_lambda=max(lambda_parameter,-one_over_m)
    relative_saturation=(theta-theta_r)/theta_capacity_range
    relative_saturation=min(relative_saturation,pressure_envelope_saturation)
    if (relative_saturation <= 0.0_real64 .or. relative_saturation >= 1.0_real64) return
    help_term=1.0_real64-relative_saturation**one_over_m
    diffusivity=(((1.0_real64-m_parameter)*saturated_conductivity) / &
         (alpha_mualem*m_parameter*theta_capacity_range)) * &
         relative_saturation**(effective_lambda-one_over_m) * &
         (help_term**(-m_parameter)+help_term**m_parameter-2.0_real64)
    if (.not. ieee_is_finite(diffusivity) .or. .not. ieee_is_finite(effective_lambda) .or. &
        .not. ieee_is_finite(relative_saturation)) then
      diffusivity=0.0_real64
      effective_lambda=0.0_real64
      relative_saturation=0.0_real64
      return
    end if
    status=PPA_WU05A3_DIFFUSIVITY_OK
  end subroutine ppa_wu05a3_absorption_diffusivity

end module mod_ppa_wu05a3_absorption_diffusivity
