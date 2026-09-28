module mod_ppa_sol_age_surface
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_SOL_AGE_SURFACE_OK = 0
  integer, parameter, public :: PPA_SOL_AGE_SURFACE_INVALID_INPUT = 1
  public :: ppa_sol_age_surface_candidate

contains

  pure subroutine ppa_sol_age_surface_candidate(irrigation_rate, irrigation_age, precipitation_rate, precipitation_age, &
       interval_days, previous_pond_storage, previous_pond_age, top_water_flux, pond_storage, snow_fraction, &
       run_output_fraction, pond_age, top_age_amount, surface_age_rate, downward_age_amount, &
       surface_cumulative_age, status)
    real(real64), intent(in) :: irrigation_rate, irrigation_age, precipitation_rate, precipitation_age, interval_days
    real(real64), intent(in) :: previous_pond_storage, previous_pond_age, top_water_flux, pond_storage, snow_fraction
    real(real64), intent(in) :: run_output_fraction
    real(real64), intent(out) :: pond_age, top_age_amount, surface_age_rate, downward_age_amount, surface_cumulative_age
    integer, intent(out) :: status
    real(real64) :: surface_age

    pond_age = 0.0_real64
    top_age_amount = 0.0_real64
    surface_age_rate = 0.0_real64
    downward_age_amount = 0.0_real64
    surface_cumulative_age = 0.0_real64
    status = PPA_SOL_AGE_SURFACE_INVALID_INPUT
    if (.not. ieee_is_finite(irrigation_rate) .or. .not. ieee_is_finite(irrigation_age) .or. &
        .not. ieee_is_finite(precipitation_rate) .or. .not. ieee_is_finite(precipitation_age) .or. &
        .not. ieee_is_finite(interval_days) .or. .not. ieee_is_finite(previous_pond_storage) .or. &
        .not. ieee_is_finite(previous_pond_age) .or. .not. ieee_is_finite(top_water_flux) .or. &
        .not. ieee_is_finite(pond_storage) .or. .not. ieee_is_finite(snow_fraction) .or. &
        .not. ieee_is_finite(run_output_fraction)) return
    if (interval_days <= 0.0_real64 .or. previous_pond_storage < 0.0_real64 .or. pond_storage <= 0.0_real64 .or. &
        snow_fraction < 0.0_real64 .or. snow_fraction > 1.0_real64 .or. run_output_fraction < 0.0_real64) return

    surface_age = (irrigation_rate * irrigation_age + precipitation_rate * precipitation_age) * interval_days + &
         previous_pond_storage * previous_pond_age
    if (top_water_flux < -1.0e-6_real64) then
      if (pond_storage - top_water_flux * interval_days <= 0.0_real64) return
      pond_age = surface_age / (pond_storage - top_water_flux * interval_days)
      top_age_amount = top_water_flux * (1.0_real64 - snow_fraction) * pond_age * interval_days
      surface_age = surface_age + top_age_amount
      surface_age_rate = top_water_flux * (1.0_real64 - snow_fraction) * pond_age
      downward_age_amount = top_water_flux * (1.0_real64 - snow_fraction) * &
           0.5_real64 * (pond_age + previous_pond_age) * interval_days
    else
      pond_age = 0.0_real64
      top_age_amount = 0.0_real64
      surface_age_rate = 0.0_real64
    end if
    surface_cumulative_age = 0.5_real64 * (pond_age + previous_pond_age) * run_output_fraction
    if (.not. ieee_is_finite(pond_age) .or. .not. ieee_is_finite(top_age_amount) .or. &
        .not. ieee_is_finite(surface_age_rate) .or. .not. ieee_is_finite(downward_age_amount) .or. &
        .not. ieee_is_finite(surface_cumulative_age) .or. .not. ieee_is_finite(surface_age)) then
      pond_age = 0.0_real64
      top_age_amount = 0.0_real64
      surface_age_rate = 0.0_real64
      downward_age_amount = 0.0_real64
      surface_cumulative_age = 0.0_real64
      return
    end if
    status = PPA_SOL_AGE_SURFACE_OK
  end subroutine ppa_sol_age_surface_candidate

end module mod_ppa_sol_age_surface
