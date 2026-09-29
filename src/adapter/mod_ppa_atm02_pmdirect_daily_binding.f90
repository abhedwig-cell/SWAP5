module mod_ppa_atm02_pmdirect_daily_binding
  use mod_ppa_atm02_typed_meteo_ingestion, only: ppa_atm02_decoded_daily_meteo_t, &
       ppa_atm02_generic_interval_t, ppa_atm02_meteo_provenance_t, ppa_atm02_diagnostics_t, &
       materialize_ppa_atm02_pmdirect_weather, PPA_ATM02_OK
  use mod_pmdirect_swetr0_process, only: pmdirect_swetr0_weather_t, pmdirect_swetr0_site_t, pmdirect_swetr0_canopy_t, &
       pmdirect_swetr0_daily_result_t, pmdirect_swetr0_diagnostics_t, &
       evaluate_pmdirect_swetr0_daily, PMDIRECT_SWETR0_OK
  implicit none
  private

  integer, parameter, public :: PPA_ATM02_PMDIRECT_OK = 0
  integer, parameter, public :: PPA_ATM02_PMDIRECT_INGESTION_REJECTED = 1
  integer, parameter, public :: PPA_ATM02_PMDIRECT_PROCESS_REJECTED = 2

  type, public :: ppa_atm02_pmdirect_diagnostics_t
    integer :: status = PPA_ATM02_PMDIRECT_INGESTION_REJECTED
    type(ppa_atm02_diagnostics_t) :: ingestion
    type(pmdirect_swetr0_diagnostics_t) :: process
    logical :: daily_result_produced = .false.
  end type ppa_atm02_pmdirect_diagnostics_t

  public :: evaluate_ppa_atm02_pmdirect_daily

contains

  pure subroutine evaluate_ppa_atm02_pmdirect_daily(decoded, requested_interval, site, canopy, daily_result, provenance, diagnostics)
    type(ppa_atm02_decoded_daily_meteo_t), intent(in) :: decoded
    type(ppa_atm02_generic_interval_t), intent(in) :: requested_interval
    type(pmdirect_swetr0_site_t), intent(in) :: site
    type(pmdirect_swetr0_canopy_t), intent(in) :: canopy
    type(pmdirect_swetr0_daily_result_t), intent(out) :: daily_result
    type(ppa_atm02_meteo_provenance_t), intent(out) :: provenance
    type(ppa_atm02_pmdirect_diagnostics_t), intent(out) :: diagnostics

    type(pmdirect_swetr0_weather_t) :: weather

    daily_result = pmdirect_swetr0_daily_result_t()
    provenance = ppa_atm02_meteo_provenance_t()
    diagnostics = ppa_atm02_pmdirect_diagnostics_t()
    call materialize_ppa_atm02_pmdirect_weather(decoded, requested_interval, weather, provenance, diagnostics%ingestion)
    if (diagnostics%ingestion%status /= PPA_ATM02_OK) return
    call evaluate_pmdirect_swetr0_daily(weather, site, canopy, daily_result, diagnostics%process)
    if (diagnostics%process%status /= PMDIRECT_SWETR0_OK .or. .not. diagnostics%process%daily_result_produced) then
      diagnostics%status = PPA_ATM02_PMDIRECT_PROCESS_REJECTED
      daily_result = pmdirect_swetr0_daily_result_t()
      return
    end if
    diagnostics%status = PPA_ATM02_PMDIRECT_OK
    diagnostics%daily_result_produced = .true.
  end subroutine evaluate_ppa_atm02_pmdirect_daily

end module mod_ppa_atm02_pmdirect_daily_binding
