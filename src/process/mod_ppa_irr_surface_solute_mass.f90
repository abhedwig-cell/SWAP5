module mod_ppa_irr_surface_solute_mass
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: IRR_SURFACE_SOLUTE_OK = 0
  integer, parameter, public :: IRR_SURFACE_SOLUTE_INVALID_INPUT = 1

  public :: calculate_surface_irrigation_solute_mass, accumulate_surface_solute_amount

contains

  pure subroutine calculate_surface_irrigation_solute_mass(net_irrigation_cm_per_day, &
      concentration_mg_per_cm3, interval_days, source_mass_mg_per_cm2, status)
    real(real64), intent(in) :: net_irrigation_cm_per_day
    real(real64), intent(in) :: concentration_mg_per_cm3
    real(real64), intent(in) :: interval_days
    real(real64), intent(out) :: source_mass_mg_per_cm2
    integer, intent(out) :: status
    real(real64) :: source_rate_mg_per_cm2_day

    ! Source: B1.11 solute.f90 task 2 surface accumulation and task 3 sqirrig = nird*cirr*dt.
    source_mass_mg_per_cm2 = 0.0_real64
    status = IRR_SURFACE_SOLUTE_INVALID_INPUT
    if (.not. ieee_is_finite(net_irrigation_cm_per_day) .or. &
        .not. ieee_is_finite(concentration_mg_per_cm3) .or. .not. ieee_is_finite(interval_days)) return
    if (net_irrigation_cm_per_day < 0.0_real64 .or. concentration_mg_per_cm3 < 0.0_real64 .or. &
        concentration_mg_per_cm3 > 100.0_real64 .or. interval_days < 0.0_real64) return
    if (net_irrigation_cm_per_day > 1.0_real64 .and. concentration_mg_per_cm3 > 1.0_real64) then
      if (net_irrigation_cm_per_day > huge(1.0_real64)/concentration_mg_per_cm3) return
    end if

    source_rate_mg_per_cm2_day = net_irrigation_cm_per_day*concentration_mg_per_cm3
    if (source_rate_mg_per_cm2_day > 1.0_real64 .and. interval_days > 1.0_real64) then
      if (interval_days > huge(1.0_real64)/source_rate_mg_per_cm2_day) return
    end if
    source_mass_mg_per_cm2 = source_rate_mg_per_cm2_day*interval_days
    if (.not. ieee_is_finite(source_mass_mg_per_cm2)) then
      source_mass_mg_per_cm2 = 0.0_real64
      return
    end if
    status = IRR_SURFACE_SOLUTE_OK
  end subroutine calculate_surface_irrigation_solute_mass

  pure subroutine accumulate_surface_solute_amount(net_irrigation_rate, irrigation_concentration, &
      net_rain_rate, precipitation_concentration, interval_days, previous_surface_amount, &
      surface_amount, status)
    real(real64), intent(in) :: net_irrigation_rate, irrigation_concentration
    real(real64), intent(in) :: net_rain_rate, precipitation_concentration, interval_days
    real(real64), intent(in) :: previous_surface_amount
    real(real64), intent(out) :: surface_amount
    integer, intent(out) :: status
    real(real64) :: irrigation_rate_mass, rain_rate_mass, total_rate_mass, interval_mass

    ! Source: B1.11 solute.f90 task 2: csurf=(nird*cirr+nraidt*cpre)*dtsolu+csurf.
    surface_amount = 0.0_real64
    status = IRR_SURFACE_SOLUTE_INVALID_INPUT
    if (.not. ieee_is_finite(net_irrigation_rate) .or. .not. ieee_is_finite(irrigation_concentration) .or. &
        .not. ieee_is_finite(net_rain_rate) .or. .not. ieee_is_finite(precipitation_concentration) .or. &
        .not. ieee_is_finite(interval_days) .or. .not. ieee_is_finite(previous_surface_amount)) return
    if (net_irrigation_rate < 0.0_real64 .or. net_rain_rate < 0.0_real64 .or. &
        irrigation_concentration < 0.0_real64 .or. irrigation_concentration > 100.0_real64 .or. &
        precipitation_concentration < 0.0_real64 .or. precipitation_concentration > 100.0_real64 .or. &
        interval_days < 0.0_real64 .or. previous_surface_amount < 0.0_real64) return

    if (net_irrigation_rate > 1.0_real64 .and. irrigation_concentration > 1.0_real64) then
      if (net_irrigation_rate > huge(1.0_real64)/irrigation_concentration) return
    end if
    if (net_rain_rate > 1.0_real64 .and. precipitation_concentration > 1.0_real64) then
      if (net_rain_rate > huge(1.0_real64)/precipitation_concentration) return
    end if
    irrigation_rate_mass = net_irrigation_rate*irrigation_concentration
    rain_rate_mass = net_rain_rate*precipitation_concentration
    if (rain_rate_mass > huge(1.0_real64)-irrigation_rate_mass) return
    total_rate_mass = irrigation_rate_mass+rain_rate_mass
    if (total_rate_mass > 1.0_real64 .and. interval_days > 1.0_real64) then
      if (interval_days > huge(1.0_real64)/total_rate_mass) return
    end if
    interval_mass = total_rate_mass*interval_days
    if (interval_mass > huge(1.0_real64)-previous_surface_amount) return
    surface_amount = previous_surface_amount+interval_mass
    if (.not. ieee_is_finite(surface_amount)) then
      surface_amount = 0.0_real64
      return
    end if
    status = IRR_SURFACE_SOLUTE_OK
  end subroutine accumulate_surface_solute_amount

end module mod_ppa_irr_surface_solute_mass
