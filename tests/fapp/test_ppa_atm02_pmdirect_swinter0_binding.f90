program test_ppa_atm02_pmdirect_swinter0_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_ppa_atm02_typed_meteo_ingestion, only: ppa_atm02_decoded_daily_meteo_t, ppa_atm02_generic_interval_t, &
       ppa_atm02_meteo_provenance_t
  use mod_ppa_atm02_pmdirect_swinter0_binding
  use mod_pmdirect_swetr0_process, only: pmdirect_swetr0_site_t, pmdirect_swetr0_canopy_t, &
       pmdirect_swetr0_interval_result_t
  implicit none
  type(ppa_atm02_decoded_daily_meteo_t) :: decoded
  type(ppa_atm02_generic_interval_t) :: span
  type(pmdirect_swetr0_site_t) :: site
  type(pmdirect_swetr0_canopy_t) :: canopy
  type(pmdirect_swetr0_interval_result_t) :: result
  type(ppa_atm02_meteo_provenance_t) :: provenance
  type(ppa_atm02_swinter0_diagnostics_t) :: diagnostics
  real(real64) :: net_irrigation

  call set_site(site)
  canopy = pmdirect_swetr0_canopy_t(.true., 3.0_real64, 0.7_real64, 0.25_real64, 0.23_real64, 70.0_real64, 0.0_real64, 1.0_real64)
  decoded%source_id = 431001_int64; decoded%source_record_index = 19_int64; decoded%day_of_year = 161
  decoded%t0 = 4100.0_real64; decoded%t1 = 4101.0_real64; span%t0 = 4100.25_real64; span%t1 = 4100.5_real64
  decoded%radiation_j_m2_d = 1.245e7_real64; decoded%minimum_air_temperature_c = 11.0_real64
  decoded%maximum_air_temperature_c = 18.1_real64; decoded%vapour_pressure_kpa = 1.315514_real64
  decoded%wind_speed_m_s = 4.92_real64; decoded%gross_rain_cm_d = 0.47_real64
  call evaluate_ppa_atm02_pmdirect_swinter0(decoded, span, site, canopy, 0.12_real64, result, net_irrigation, provenance, diagnostics)
  call require(diagnostics%status == PPA_ATM02_SWINTER0_OK .and. diagnostics%interval_result_produced, 'identity composition rejected')
  call require(abs(result%net_rain_cm_per_day - decoded%gross_rain_cm_d) <= 1.0e-12_real64, 'rain changed')
  call require(abs(net_irrigation - 0.12_real64) <= 1.0e-12_real64, 'irrigation changed')
  call require(abs(result%interception_rate_cm_per_day) <= 1.0e-12_real64, 'interception introduced')
  call require(provenance%source_id == decoded%source_id, 'provenance changed')
  call evaluate_ppa_atm02_pmdirect_swinter0(decoded, span, site, canopy, -0.01_real64, result, net_irrigation, provenance, diagnostics)
  call require(diagnostics%status == PPA_ATM02_SWINTER0_INTERVAL_REJECTED .and. .not. diagnostics%interval_result_produced, 'negative irrigation accepted')
  print '(a)', 'PPA_ATM02_SWINTER0_IDENTITY_COMPOSITION=PASS'
  print '(a)', 'PPA_ATM02_SWINTER0_FAIL_CLOSED=PASS'
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
      write(*, '(a)') trim(label); error stop 1
    end if
  end subroutine require
end program test_ppa_atm02_pmdirect_swinter0_binding
