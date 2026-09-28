module mod_ppa_atm02_pmdirect_swinter0_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_ppa_atm02_typed_meteo_ingestion, only: ppa_atm02_decoded_daily_meteo_t, &
       ppa_atm02_generic_interval_t, ppa_atm02_meteo_provenance_t
  use mod_ppa_atm02_pmdirect_daily_binding, only: ppa_atm02_pmdirect_diagnostics_t, &
       evaluate_ppa_atm02_pmdirect_daily, PPA_ATM02_PMDIRECT_OK
  use mod_pmdirect_swetr0_process, only: pmdirect_swetr0_weather_t, pmdirect_swetr0_site_t, pmdirect_swetr0_canopy_t, &
       pmdirect_swetr0_daily_result_t, pmdirect_swetr0_interval_result_t, pmdirect_swetr0_diagnostics_t, &
       apply_swinter0_identity_interval, PMDIRECT_SWETR0_OK
  implicit none
  private

  integer, parameter, public :: PPA_ATM02_SWINTER0_OK = 0
  integer, parameter, public :: PPA_ATM02_SWINTER0_DAILY_REJECTED = 1
  integer, parameter, public :: PPA_ATM02_SWINTER0_INTERVAL_REJECTED = 2

  type, public :: ppa_atm02_swinter0_diagnostics_t
    integer :: status = PPA_ATM02_SWINTER0_DAILY_REJECTED
    type(ppa_atm02_pmdirect_diagnostics_t) :: daily
    type(pmdirect_swetr0_diagnostics_t) :: interval
    logical :: interval_result_produced = .false.
  end type ppa_atm02_swinter0_diagnostics_t

  public :: evaluate_ppa_atm02_pmdirect_swinter0

contains

  pure subroutine evaluate_ppa_atm02_pmdirect_swinter0(decoded, requested_interval, site, canopy, &
      gross_surface_irrigation_cm_per_day, interval_result, net_surface_irrigation_cm_per_day, provenance, diagnostics)
    type(ppa_atm02_decoded_daily_meteo_t), intent(in) :: decoded
    type(ppa_atm02_generic_interval_t), intent(in) :: requested_interval
    type(pmdirect_swetr0_site_t), intent(in) :: site
    type(pmdirect_swetr0_canopy_t), intent(in) :: canopy
    real(real64), intent(in) :: gross_surface_irrigation_cm_per_day
    type(pmdirect_swetr0_interval_result_t), intent(out) :: interval_result
    real(real64), intent(out) :: net_surface_irrigation_cm_per_day
    type(ppa_atm02_meteo_provenance_t), intent(out) :: provenance
    type(ppa_atm02_swinter0_diagnostics_t), intent(out) :: diagnostics

    type(pmdirect_swetr0_daily_result_t) :: daily_result
    type(pmdirect_swetr0_weather_t) :: weather

    interval_result = pmdirect_swetr0_interval_result_t()
    net_surface_irrigation_cm_per_day = 0.0_real64
    provenance = ppa_atm02_meteo_provenance_t()
    diagnostics = ppa_atm02_swinter0_diagnostics_t()
    call evaluate_ppa_atm02_pmdirect_daily(decoded, requested_interval, site, canopy, daily_result, provenance, diagnostics%daily)
    if (diagnostics%daily%status /= PPA_ATM02_PMDIRECT_OK) return

    weather%day_of_year = decoded%day_of_year
    weather%radiation_j_m2_d = decoded%radiation_j_m2_d
    weather%minimum_air_temperature_c = decoded%minimum_air_temperature_c
    weather%maximum_air_temperature_c = decoded%maximum_air_temperature_c
    weather%vapour_pressure_kpa = decoded%vapour_pressure_kpa
    weather%wind_speed_m_s = decoded%wind_speed_m_s
    weather%gross_rain_cm_d = decoded%gross_rain_cm_d
    diagnostics%interval = pmdirect_swetr0_diagnostics_t()
    diagnostics%interval%daily_result_produced = .true.
    call apply_swinter0_identity_interval(weather, daily_result, gross_surface_irrigation_cm_per_day, &
      interval_result, net_surface_irrigation_cm_per_day, diagnostics%interval)
    if (diagnostics%interval%status /= PMDIRECT_SWETR0_OK .or. .not. diagnostics%interval%interval_result_produced) then
      diagnostics%status = PPA_ATM02_SWINTER0_INTERVAL_REJECTED
      interval_result = pmdirect_swetr0_interval_result_t()
      net_surface_irrigation_cm_per_day = 0.0_real64
      return
    end if
    diagnostics%status = PPA_ATM02_SWINTER0_OK
    diagnostics%interval_result_produced = .true.
  end subroutine evaluate_ppa_atm02_pmdirect_swinter0

end module mod_ppa_atm02_pmdirect_swinter0_binding
