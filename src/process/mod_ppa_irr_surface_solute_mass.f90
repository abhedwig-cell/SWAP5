module mod_ppa_irr_surface_solute_mass
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: IRR_SURFACE_SOLUTE_OK = 0
  integer, parameter, public :: IRR_SURFACE_SOLUTE_INVALID_INPUT = 1

  public :: calculate_surface_irrigation_solute_mass, accumulate_surface_solute_amount
  public :: ppa_irr_surface_solute_exchange
  public :: ppa_irr_bottom_solute_flux

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

  pure subroutine ppa_irr_surface_solute_exchange(surface_mass, pond_depth, top_flux, &
      macropore_area_fraction, interval_days, pond_concentration, surface_flux_mass, &
      updated_surface_mass, surface_flux, status)
    real(real64), intent(in) :: surface_mass, pond_depth, top_flux, macropore_area_fraction, interval_days
    real(real64), intent(out) :: pond_concentration, surface_flux_mass, updated_surface_mass, surface_flux
    integer, intent(out) :: status
    real(real64) :: denominator, matrix_flux, top_step_depth

    ! Source: B1.11 solute.f90 task 2 soil-surface pond exchange.
    pond_concentration = 0.0_real64
    surface_flux_mass = 0.0_real64
    updated_surface_mass = 0.0_real64
    surface_flux = 0.0_real64
    status = IRR_SURFACE_SOLUTE_INVALID_INPUT
    if (.not. all(ieee_is_finite([surface_mass,pond_depth,top_flux,macropore_area_fraction,interval_days]))) return
    if (surface_mass < 0.0_real64 .or. pond_depth < 0.0_real64 .or. &
        macropore_area_fraction < 0.0_real64 .or. macropore_area_fraction > 1.0_real64 .or. &
        interval_days <= 0.0_real64) return
    updated_surface_mass = surface_mass
    status = IRR_SURFACE_SOLUTE_OK
    if (top_flux >= -1.0e-6_real64) return

    if (interval_days > 1.0_real64) then
      if (abs(top_flux) > huge(1.0_real64)/interval_days) then
        status = IRR_SURFACE_SOLUTE_INVALID_INPUT
        updated_surface_mass = 0.0_real64
        return
      end if
    end if
    top_step_depth = top_flux*interval_days
    if (pond_depth > huge(1.0_real64)+top_step_depth) then
      status = IRR_SURFACE_SOLUTE_INVALID_INPUT
      updated_surface_mass = 0.0_real64
      return
    end if
    denominator = pond_depth-top_step_depth
    if (denominator <= 0.0_real64 .or. .not. ieee_is_finite(denominator)) then
      status = IRR_SURFACE_SOLUTE_INVALID_INPUT
      updated_surface_mass = 0.0_real64
      return
    end if
    if (denominator < 1.0_real64) then
      if (surface_mass > huge(1.0_real64)*denominator) then
        status = IRR_SURFACE_SOLUTE_INVALID_INPUT
        updated_surface_mass = 0.0_real64
        return
      end if
    end if
    pond_concentration = surface_mass/denominator
    matrix_flux = top_flux*(1.0_real64-macropore_area_fraction)
    if (pond_concentration > 1.0_real64 .and. abs(matrix_flux) > 1.0_real64) then
      if (abs(matrix_flux) > huge(1.0_real64)/pond_concentration) then
        status = IRR_SURFACE_SOLUTE_INVALID_INPUT
        pond_concentration = 0.0_real64
        updated_surface_mass = 0.0_real64
        return
      end if
    end if
    surface_flux = matrix_flux*pond_concentration
    if (abs(surface_flux) > 1.0_real64 .and. interval_days > 1.0_real64) then
      if (interval_days > huge(1.0_real64)/abs(surface_flux)) then
        status = IRR_SURFACE_SOLUTE_INVALID_INPUT
        pond_concentration = 0.0_real64
        surface_flux = 0.0_real64
        updated_surface_mass = 0.0_real64
        return
      end if
    end if
    surface_flux_mass = surface_flux*interval_days
    updated_surface_mass = surface_mass+surface_flux_mass
    if (.not. all(ieee_is_finite([pond_concentration,surface_flux_mass,updated_surface_mass,surface_flux]))) then
      pond_concentration = 0.0_real64
      surface_flux_mass = 0.0_real64
      updated_surface_mass = 0.0_real64
      surface_flux = 0.0_real64
      status = IRR_SURFACE_SOLUTE_INVALID_INPUT
    end if
  end subroutine ppa_irr_surface_solute_exchange

  pure subroutine ppa_irr_bottom_solute_flux(bottom_water_flux, seepage_concentration, &
      matrix_concentration, bottom_solute_flux, concentration_selected, status)
    real(real64), intent(in) :: bottom_water_flux, seepage_concentration, matrix_concentration
    real(real64), intent(out) :: bottom_solute_flux
    logical, intent(out) :: concentration_selected
    integer, intent(out) :: status
    real(real64) :: concentration

    ! Source: B1.11 solute.f90 task 2 bottom solute-flux sign partition.
    bottom_solute_flux = 0.0_real64
    concentration_selected = .false.
    status = IRR_SURFACE_SOLUTE_INVALID_INPUT
    if (.not. all(ieee_is_finite([bottom_water_flux,seepage_concentration,matrix_concentration]))) return
    if (seepage_concentration < 0.0_real64 .or. matrix_concentration < 0.0_real64) return
    if (bottom_water_flux > 0.0_real64) then
      concentration = seepage_concentration
      concentration_selected = .true.
    else
      concentration = matrix_concentration
    end if
    if (abs(bottom_water_flux) > 1.0_real64 .and. concentration > 1.0_real64) then
      if (abs(bottom_water_flux) > huge(1.0_real64)/concentration) then
        concentration_selected = .false.
        return
      end if
    end if
    bottom_solute_flux = bottom_water_flux*concentration
    if (.not. ieee_is_finite(bottom_solute_flux)) then
      bottom_solute_flux = 0.0_real64
      concentration_selected = .false.
      return
    end if
    status = IRR_SURFACE_SOLUTE_OK
  end subroutine ppa_irr_bottom_solute_flux

end module mod_ppa_irr_surface_solute_mass
