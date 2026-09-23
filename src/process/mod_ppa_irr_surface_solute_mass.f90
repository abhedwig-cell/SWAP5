module mod_ppa_irr_surface_solute_mass
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: IRR_SURFACE_SOLUTE_OK = 0
  integer, parameter, public :: IRR_SURFACE_SOLUTE_INVALID_INPUT = 1

  public :: calculate_surface_irrigation_solute_mass

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

end module mod_ppa_irr_surface_solute_mass
