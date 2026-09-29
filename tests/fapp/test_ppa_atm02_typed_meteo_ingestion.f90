program test_ppa_atm02_typed_meteo_ingestion
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_quiet_nan, ieee_value
  use mod_pmdirect_swetr0_process, only: pmdirect_swetr0_weather_t
  use mod_ppa_atm02_typed_meteo_ingestion
  implicit none

  type(ppa_atm02_decoded_daily_meteo_t) :: decoded, invalid
  type(ppa_atm02_generic_interval_t) :: request
  type(pmdirect_swetr0_weather_t) :: weather
  type(ppa_atm02_meteo_provenance_t) :: provenance
  type(ppa_atm02_diagnostics_t) :: diagnostics
  real(real64) :: nan_value

  decoded%source_id = 431001_int64
  decoded%source_record_index = 17_int64
  decoded%day_of_year = 161
  decoded%t0 = 4100.0_real64
  decoded%t1 = 4101.0_real64
  decoded%radiation_j_m2_d = 1.2450e7_real64
  decoded%minimum_air_temperature_c = 11.0_real64
  decoded%maximum_air_temperature_c = 18.1_real64
  decoded%vapour_pressure_kpa = 1.315514_real64
  decoded%wind_speed_m_s = 4.92_real64
  decoded%gross_rain_cm_d = 0.47_real64
  request%t0 = 4100.1875_real64
  request%t1 = 4100.4375_real64

  call materialize_ppa_atm02_pmdirect_weather(decoded, request, weather, provenance, diagnostics)
  call require(diagnostics%status == PPA_ATM02_OK .and. diagnostics%result_produced, 'covered record accepted')
  call require(diagnostics%source_covers_request, 'subdaily generic interval covered')
  call require(weather%day_of_year == decoded%day_of_year, 'day identity')
  call require(same_bits(weather%radiation_j_m2_d, decoded%radiation_j_m2_d), 'radiation identity')
  call require(same_bits(weather%minimum_air_temperature_c, decoded%minimum_air_temperature_c), 'minimum temperature identity')
  call require(same_bits(weather%maximum_air_temperature_c, decoded%maximum_air_temperature_c), 'maximum temperature identity')
  call require(same_bits(weather%vapour_pressure_kpa, decoded%vapour_pressure_kpa), 'vapour pressure identity')
  call require(same_bits(weather%wind_speed_m_s, decoded%wind_speed_m_s), 'wind identity')
  call require(same_bits(weather%gross_rain_cm_d, decoded%gross_rain_cm_d), 'rain identity')
  call require(provenance%source_id == decoded%source_id .and. &
    provenance%source_record_index == decoded%source_record_index, 'immutable provenance identity')

  invalid = decoded
  invalid%source_id = 0_int64
  call materialize_ppa_atm02_pmdirect_weather(invalid, request, weather, provenance, diagnostics)
  call require(diagnostics%status == PPA_ATM02_INVALID_IDENTITY .and. .not. diagnostics%result_produced, 'identity fails closed')
  invalid = decoded
  invalid%day_of_year = 367
  call materialize_ppa_atm02_pmdirect_weather(invalid, request, weather, provenance, diagnostics)
  call require(diagnostics%status == PPA_ATM02_INVALID_CALENDAR, 'calendar fails closed')
  invalid = decoded
  invalid%t1 = invalid%t0
  call materialize_ppa_atm02_pmdirect_weather(invalid, request, weather, provenance, diagnostics)
  call require(diagnostics%status == PPA_ATM02_INVALID_SOURCE_SPAN, 'source span fails closed')
  invalid = decoded
  invalid%t1 = request%t1 - 0.01_real64
  call materialize_ppa_atm02_pmdirect_weather(invalid, request, weather, provenance, diagnostics)
  call require(diagnostics%status == PPA_ATM02_SOURCE_DOES_NOT_COVER_REQUEST, 'coverage fails closed')
  nan_value = ieee_value(0.0_real64, ieee_quiet_nan)
  invalid = decoded
  invalid%wind_speed_m_s = nan_value
  call materialize_ppa_atm02_pmdirect_weather(invalid, request, weather, provenance, diagnostics)
  call require(diagnostics%status == PPA_ATM02_INVALID_WEATHER, 'nonfinite weather fails closed')
  invalid = decoded
  invalid%gross_rain_cm_d = -0.001_real64
  call materialize_ppa_atm02_pmdirect_weather(invalid, request, weather, provenance, diagnostics)
  call require(diagnostics%status == PPA_ATM02_INVALID_WEATHER, 'negative rain fails closed')

  print '(a)', 'PPA_ATM02_DECODED_DAILY_FIELD_IDENTITY=PASS'
  print '(a)', 'PPA_ATM02_GENERIC_SUBDAILY_COVERAGE=PASS'
  print '(a)', 'PPA_ATM02_PROVENANCE_PRESERVED=PASS'
  print '(a)', 'PPA_ATM02_INVALID_INPUT_FAIL_CLOSED=PASS'
contains
  pure logical function same_bits(a, b) result(same)
    real(real64), intent(in) :: a, b
    same = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function same_bits

  subroutine require(ok, label)
    logical, intent(in) :: ok
    character(*), intent(in) :: label
    if (.not. ok) then
      write(*, '(a)') trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ppa_atm02_typed_meteo_ingestion
