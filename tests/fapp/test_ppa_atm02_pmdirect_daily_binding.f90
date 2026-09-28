program test_ppa_atm02_pmdirect_daily_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_ppa_atm02_typed_meteo_ingestion, only: ppa_atm02_decoded_daily_meteo_t, &
       ppa_atm02_generic_interval_t, ppa_atm02_meteo_provenance_t
  use mod_ppa_atm02_pmdirect_daily_binding
  use mod_pmdirect_swetr0_process, only: pmdirect_swetr0_site_t, pmdirect_swetr0_canopy_t, &
       pmdirect_swetr0_daily_result_t, pmdirect_swetr0_weather_t, pmdirect_swetr0_diagnostics_t, &
       evaluate_pmdirect_swetr0_daily, PMDIRECT_SWETR0_OK
  implicit none
  real(real64), parameter :: tol = 1.0e-12_real64
  type(ppa_atm02_decoded_daily_meteo_t) :: decoded, invalid
  type(ppa_atm02_generic_interval_t) :: interval
  type(pmdirect_swetr0_site_t) :: site
  type(pmdirect_swetr0_canopy_t) :: canopy
  type(pmdirect_swetr0_daily_result_t) :: bound, direct
  type(ppa_atm02_meteo_provenance_t) :: provenance
  type(ppa_atm02_pmdirect_diagnostics_t) :: diagnostics
  type(pmdirect_swetr0_diagnostics_t) :: direct_diagnostics
  type(pmdirect_swetr0_weather_t) :: weather

  call set_site(site)
  canopy = pmdirect_swetr0_canopy_t(.true., 3.12683333333333335_real64, 0.755141552325116483_real64, &
    0.25_real64, 0.23_real64, 70.0_real64, 0.0_real64, 1.0_real64)
  decoded%source_id = 431001_int64
  decoded%source_record_index = 161_int64
  decoded%day_of_year = 161
  decoded%t0 = 4100.0_real64
  decoded%t1 = 4101.0_real64
  decoded%radiation_j_m2_d = 1.2450e7_real64
  decoded%minimum_air_temperature_c = 11.0_real64
  decoded%maximum_air_temperature_c = 18.1_real64
  decoded%vapour_pressure_kpa = 1.315514_real64
  decoded%wind_speed_m_s = 4.92_real64
  decoded%gross_rain_cm_d = 0.47_real64
  interval%t0 = 4100.25_real64
  interval%t1 = 4100.50_real64

  call evaluate_ppa_atm02_pmdirect_daily(decoded, interval, site, canopy, bound, provenance, diagnostics)
  call require(diagnostics%status == PPA_ATM02_PMDIRECT_OK .and. diagnostics%daily_result_produced, 'bound PMdirect accepted')
  weather = pmdirect_swetr0_weather_t(161, 1.2450e7_real64, 11.0_real64, 18.1_real64, 1.315514_real64, 4.92_real64, 0.47_real64)
  call evaluate_pmdirect_swetr0_daily(weather, site, canopy, direct, direct_diagnostics)
  call require(direct_diagnostics%status == PMDIRECT_SWETR0_OK, 'direct PMdirect accepted')
  call require(abs(bound%potential_soil_evaporation_cm_per_day - direct%potential_soil_evaporation_cm_per_day) <= tol, 'soil demand identity')
  call require(abs(bound%potential_transpiration_dry_cm_per_day - direct%potential_transpiration_dry_cm_per_day) <= tol, 'dry transpiration identity')
  call require(abs(bound%interception_evaporation_capacity_cm_per_day - direct%interception_evaporation_capacity_cm_per_day) <= tol, 'interception capacity identity')
  call require(provenance%source_id == decoded%source_id, 'provenance retained')
  invalid = decoded
  invalid%day_of_year = 0
  call evaluate_ppa_atm02_pmdirect_daily(invalid, interval, site, canopy, bound, provenance, diagnostics)
  call require(diagnostics%status == PPA_ATM02_PMDIRECT_INGESTION_REJECTED .and. .not. diagnostics%daily_result_produced, 'ingestion rejection preserved')

  print '(a)', 'PPA_ATM02_PMDIRECT_DIRECT_IDENTITY=PASS'
  print '(a)', 'PPA_ATM02_PMDIRECT_PROVENANCE_RETAINED=PASS'
  print '(a)', 'PPA_ATM02_PMDIRECT_INGESTION_FAIL_CLOSED=PASS'
contains
  subroutine set_site(value)
    type(pmdirect_swetr0_site_t), intent(out) :: value
    value%latitude_degrees = 52.0_real64; value%altitude_m = 10.0_real64
    value%wind_measurement_height_m = 10.0_real64; value%humidity_measurement_height_m = 1.5_real64
    value%angstrom_a = 0.25_real64; value%angstrom_b = 0.5_real64
    value%wind_function_factor = 1.0_real64; value%soil_surface_resistance_s_m = 600.0_real64
  end subroutine set_site
  subroutine require(ok, label)
    logical, intent(in) :: ok
    character(*), intent(in) :: label
    if (.not. ok) then
      write(*, '(a)') trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ppa_atm02_pmdirect_daily_binding
