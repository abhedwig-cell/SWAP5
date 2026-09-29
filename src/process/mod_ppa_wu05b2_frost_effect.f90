module mod_ppa_wu05b2_frost_effect
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_WU05B2_OK = 0
  integer, parameter, public :: PPA_WU05B2_INVALID_INPUT = 1

  public :: evaluate_ppa_wu05b2_frost_factor
  public :: apply_ppa_wu05b2_hydraulic_frost_effect

contains

  subroutine evaluate_ppa_wu05b2_frost_factor(sw_frost, frost_start_c, frost_end_c, soil_temperature_c, &
      reduction_factor, status)
    integer, intent(in) :: sw_frost
    real(real64), intent(in) :: frost_start_c, frost_end_c, soil_temperature_c(:)
    real(real64), intent(out) :: reduction_factor(:)
    integer, intent(out) :: status

    integer :: node

    reduction_factor = 0.0_real64
    status = PPA_WU05B2_INVALID_INPUT
    if (sw_frost /= 0 .and. sw_frost /= 1) return
    if (size(soil_temperature_c) == 0 .or. size(reduction_factor) /= size(soil_temperature_c)) return
    if (.not. ieee_is_finite(frost_start_c) .or. .not. ieee_is_finite(frost_end_c)) return
    if (any(.not. ieee_is_finite(soil_temperature_c))) return

    if (sw_frost == 0) then
      reduction_factor = 1.0_real64
      status = PPA_WU05B2_OK
      return
    end if

    do node = 1, size(soil_temperature_c)
      reduction_factor(node) = 1.0_real64
      if (soil_temperature_c(node) >= frost_start_c) then
        reduction_factor(node) = 1.0_real64
      else if (soil_temperature_c(node) <= frost_end_c) then
        reduction_factor(node) = 0.0_real64
      else if (soil_temperature_c(node) < frost_start_c .and. soil_temperature_c(node) > frost_end_c) then
        reduction_factor(node) = (soil_temperature_c(node)-frost_end_c)/(frost_start_c-frost_end_c)
      end if
    end do
    status = PPA_WU05B2_OK
  end subroutine evaluate_ppa_wu05b2_frost_factor

  subroutine apply_ppa_wu05b2_hydraulic_frost_effect(sw_frost, reduction_factor, conductivity_base, &
      conductivity_floor, derivative_base, conductivity, derivative, status)
    integer, intent(in) :: sw_frost
    real(real64), intent(in) :: reduction_factor(:), conductivity_base(:), conductivity_floor
    real(real64), intent(in) :: derivative_base(:)
    real(real64), intent(out) :: conductivity(:), derivative(:)
    integer, intent(out) :: status

    conductivity = 0.0_real64
    derivative = 0.0_real64
    status = PPA_WU05B2_INVALID_INPUT
    if (sw_frost /= 0 .and. sw_frost /= 1) return
    if (size(reduction_factor) == 0 .or. size(conductivity_base) /= size(reduction_factor) .or. &
        size(derivative_base) /= size(reduction_factor) .or. size(conductivity) /= size(reduction_factor) .or. &
        size(derivative) /= size(reduction_factor)) return
    if (.not. ieee_is_finite(conductivity_floor) .or. conductivity_floor < 0.0_real64) return
    if (any(.not. ieee_is_finite(reduction_factor)) .or. any(reduction_factor < 0.0_real64) .or. &
        any(reduction_factor > 1.0_real64)) return
    if (any(.not. ieee_is_finite(conductivity_base)) .or. any(conductivity_base < 0.0_real64)) return
    if (any(.not. ieee_is_finite(derivative_base))) return

    if (sw_frost == 0) then
      conductivity = conductivity_base
      derivative = derivative_base
    else
      ! Preserve B1.11 hconduc/dhconduc arithmetic and SWAP-011 base derivative authority.
      conductivity = conductivity_base * reduction_factor + conductivity_floor * (1.0_real64 - reduction_factor)
      derivative = derivative_base * reduction_factor
    end if
    status = PPA_WU05B2_OK
  end subroutine apply_ppa_wu05b2_hydraulic_frost_effect

end module mod_ppa_wu05b2_frost_effect
