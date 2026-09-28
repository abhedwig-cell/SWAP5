module mod_ppa_atm02_typed_meteo_ingestion
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_pmdirect_swetr0_process, only: pmdirect_swetr0_weather_t
  implicit none
  private

  integer, parameter, public :: PPA_ATM02_OK = 0
  integer, parameter, public :: PPA_ATM02_INVALID_IDENTITY = 1
  integer, parameter, public :: PPA_ATM02_INVALID_CALENDAR = 2
  integer, parameter, public :: PPA_ATM02_INVALID_SOURCE_SPAN = 3
  integer, parameter, public :: PPA_ATM02_INVALID_REQUEST_SPAN = 4
  integer, parameter, public :: PPA_ATM02_SOURCE_DOES_NOT_COVER_REQUEST = 5
  integer, parameter, public :: PPA_ATM02_INVALID_WEATHER = 6

  type, public :: ppa_atm02_generic_interval_t
    real(real64) :: t0 = 0.0_real64
    real(real64) :: t1 = 0.0_real64
  end type ppa_atm02_generic_interval_t

  type, public :: ppa_atm02_decoded_daily_meteo_t
    integer(int64) :: source_id = 0_int64
    integer(int64) :: source_record_index = -1_int64
    integer :: day_of_year = 0
    real(real64) :: t0 = 0.0_real64
    real(real64) :: t1 = 0.0_real64
    real(real64) :: radiation_j_m2_d = 0.0_real64
    real(real64) :: minimum_air_temperature_c = 0.0_real64
    real(real64) :: maximum_air_temperature_c = 0.0_real64
    real(real64) :: vapour_pressure_kpa = 0.0_real64
    real(real64) :: wind_speed_m_s = 0.0_real64
    real(real64) :: gross_rain_cm_d = 0.0_real64
  end type ppa_atm02_decoded_daily_meteo_t

  type, public :: ppa_atm02_meteo_provenance_t
    integer(int64) :: source_id = 0_int64
    integer(int64) :: source_record_index = -1_int64
    real(real64) :: source_t0 = 0.0_real64
    real(real64) :: source_t1 = 0.0_real64
  end type ppa_atm02_meteo_provenance_t

  type, public :: ppa_atm02_diagnostics_t
    integer :: status = PPA_ATM02_INVALID_IDENTITY
    logical :: result_produced = .false.
    logical :: source_covers_request = .false.
  end type ppa_atm02_diagnostics_t

  public :: materialize_ppa_atm02_pmdirect_weather

contains

  pure subroutine materialize_ppa_atm02_pmdirect_weather(decoded, requested_interval, weather, provenance, diagnostics)
    type(ppa_atm02_decoded_daily_meteo_t), intent(in) :: decoded
    type(ppa_atm02_generic_interval_t), intent(in) :: requested_interval
    type(pmdirect_swetr0_weather_t), intent(out) :: weather
    type(ppa_atm02_meteo_provenance_t), intent(out) :: provenance
    type(ppa_atm02_diagnostics_t), intent(out) :: diagnostics

    weather = pmdirect_swetr0_weather_t()
    provenance = ppa_atm02_meteo_provenance_t()
    diagnostics = ppa_atm02_diagnostics_t()

    if (decoded%source_id <= 0_int64 .or. decoded%source_record_index < 0_int64) return
    if (decoded%day_of_year < 1 .or. decoded%day_of_year > 366) then
      diagnostics%status = PPA_ATM02_INVALID_CALENDAR
      return
    end if
    if (.not. finite_span(decoded%t0, decoded%t1)) then
      diagnostics%status = PPA_ATM02_INVALID_SOURCE_SPAN
      return
    end if
    if (.not. finite_span(requested_interval%t0, requested_interval%t1)) then
      diagnostics%status = PPA_ATM02_INVALID_REQUEST_SPAN
      return
    end if
    if (decoded%t0 > requested_interval%t0 .or. decoded%t1 < requested_interval%t1) then
      diagnostics%status = PPA_ATM02_SOURCE_DOES_NOT_COVER_REQUEST
      return
    end if
    diagnostics%source_covers_request = .true.
    if (.not. valid_weather(decoded)) then
      diagnostics%status = PPA_ATM02_INVALID_WEATHER
      return
    end if

    weather%day_of_year = decoded%day_of_year
    weather%radiation_j_m2_d = decoded%radiation_j_m2_d
    weather%minimum_air_temperature_c = decoded%minimum_air_temperature_c
    weather%maximum_air_temperature_c = decoded%maximum_air_temperature_c
    weather%vapour_pressure_kpa = decoded%vapour_pressure_kpa
    weather%wind_speed_m_s = decoded%wind_speed_m_s
    weather%gross_rain_cm_d = decoded%gross_rain_cm_d
    provenance%source_id = decoded%source_id
    provenance%source_record_index = decoded%source_record_index
    provenance%source_t0 = decoded%t0
    provenance%source_t1 = decoded%t1
    diagnostics%status = PPA_ATM02_OK
    diagnostics%result_produced = .true.
  end subroutine materialize_ppa_atm02_pmdirect_weather

  pure logical function finite_span(t0, t1) result(valid)
    real(real64), intent(in) :: t0, t1
    valid = ieee_is_finite(t0) .and. ieee_is_finite(t1) .and. t1 > t0
  end function finite_span

  pure logical function valid_weather(decoded) result(valid)
    type(ppa_atm02_decoded_daily_meteo_t), intent(in) :: decoded
    valid = ieee_is_finite(decoded%radiation_j_m2_d) .and. &
      ieee_is_finite(decoded%minimum_air_temperature_c) .and. &
      ieee_is_finite(decoded%maximum_air_temperature_c) .and. &
      ieee_is_finite(decoded%vapour_pressure_kpa) .and. &
      ieee_is_finite(decoded%wind_speed_m_s) .and. ieee_is_finite(decoded%gross_rain_cm_d)
    if (.not. valid) return
    valid = decoded%radiation_j_m2_d >= 0.0_real64 .and. &
      decoded%maximum_air_temperature_c >= decoded%minimum_air_temperature_c .and. &
      decoded%vapour_pressure_kpa >= 0.0_real64 .and. decoded%wind_speed_m_s >= 0.0_real64 .and. &
      decoded%gross_rain_cm_d >= 0.0_real64
  end function valid_weather

end module mod_ppa_atm02_typed_meteo_ingestion
