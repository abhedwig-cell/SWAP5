module mod_ppa_atm02_pmdirect_production_forcing_adapter
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_ppa_atm02_typed_meteo_ingestion, only: ppa_atm02_decoded_daily_meteo_t, &
       ppa_atm02_generic_interval_t, ppa_atm02_meteo_provenance_t
  use mod_ppa_atm02_pmdirect_daily_binding, only: ppa_atm02_pmdirect_diagnostics_t, &
       evaluate_ppa_atm02_pmdirect_daily, PPA_ATM02_PMDIRECT_OK
  use mod_pmdirect_swetr0_process, only: pmdirect_swetr0_weather_t, pmdirect_swetr0_site_t, &
       pmdirect_swetr0_canopy_t, pmdirect_swetr0_daily_result_t, pmdirect_swetr0_interval_result_t, &
       pmdirect_swetr0_diagnostics_t, apply_swinter0_identity_interval, PMDIRECT_SWETR0_OK
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t
  use mod_ppa_atm02_pmdirect_prescribed_root_sink, only: ppa_atm02_root_sink_diagnostics_t, &
       materialize_ppa_atm02_prescribed_root_sink, PPA_ATM02_ROOT_SINK_OK
  use mod_restricted_surface_evaporation, only: surface_evaporation_demand_t
  use mod_fmr_pmdirect_surface_evaporation_binding, only: &
       fmr_pmdirect_surface_demand_binding_diagnostics_t, fmr_bind_pmdirect_surface_evaporation_demand, &
       FMR_PMDIRECT_SURFACE_DEMAND_BINDING_OK
  use mod_fmr_pmdirect_swinter0_dynamic_top_binding, only: fmr_pmdirect_swinter0_top_diagnostics_t, &
       fmr_bind_pmdirect_swinter0_surface_fluxes, FMR_PMDIRECT_SWINTER0_TOP_OK
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t, &
       b110_dynamic_top_boundary_result_t, evaluate_b110_dynamic_top_boundary, &
       B110_DYN_TOP_AVAILABLE, B110_DYN_TOP_REGIME_FLUX
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t
  implicit none
  private

  integer, parameter, public :: PPA_ATM02_PRODUCTION_FORCING_OK = 0
  integer, parameter, public :: PPA_ATM02_PRODUCTION_FORCING_DAILY_REJECTED = 1
  integer, parameter, public :: PPA_ATM02_PRODUCTION_FORCING_INTERVAL_REJECTED = 2
  integer, parameter, public :: PPA_ATM02_PRODUCTION_FORCING_SURFACE_REJECTED = 3
  integer, parameter, public :: PPA_ATM02_PRODUCTION_FORCING_TOP_REJECTED = 4
  integer, parameter, public :: PPA_ATM02_PRODUCTION_FORCING_ROOT_REJECTED = 5

  type, public :: ppa_atm02_production_forcing_diagnostics_t
    integer :: status = PPA_ATM02_PRODUCTION_FORCING_DAILY_REJECTED
    type(ppa_atm02_pmdirect_diagnostics_t) :: daily
    type(pmdirect_swetr0_diagnostics_t) :: interval
    type(fmr_pmdirect_surface_demand_binding_diagnostics_t) :: surface
    type(fmr_pmdirect_swinter0_top_diagnostics_t) :: top_binding
    type(b110_dynamic_top_boundary_result_t) :: top_result
    type(ppa_atm02_root_sink_diagnostics_t) :: root
    logical :: result_produced = .false.
  end type ppa_atm02_production_forcing_diagnostics_t

  public :: materialize_ppa_atm02_pmdirect_production_forcing

contains

  subroutine materialize_ppa_atm02_pmdirect_production_forcing(decoded, requested_interval, site, canopy, &
      gross_surface_irrigation_cm_per_day, crop_root_input, geometry, hydraulics, base_top_request, &
      base_forcing, forcing, provenance, diagnostics)
    type(ppa_atm02_decoded_daily_meteo_t), intent(in) :: decoded
    type(ppa_atm02_generic_interval_t), intent(in) :: requested_interval
    type(pmdirect_swetr0_site_t), intent(in) :: site
    type(pmdirect_swetr0_canopy_t), intent(in) :: canopy
    real(real64), intent(in) :: gross_surface_irrigation_cm_per_day
    type(crop_root_uptake_input_t), intent(in) :: crop_root_input
    type(soil_water_parameter_set_t), intent(in) :: geometry
    type(b110_default_mvg_parameters_t), intent(in) :: hydraulics
    type(b110_dynamic_top_boundary_request_t), intent(in) :: base_top_request
    type(fmr_b110_physical_forcing_t), intent(in) :: base_forcing
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    type(ppa_atm02_meteo_provenance_t), intent(out) :: provenance
    type(ppa_atm02_production_forcing_diagnostics_t), intent(out) :: diagnostics

    type(pmdirect_swetr0_daily_result_t) :: daily_result
    type(pmdirect_swetr0_interval_result_t) :: interval_result
    type(pmdirect_swetr0_weather_t) :: weather
    type(surface_evaporation_demand_t) :: surface_demand
    type(b110_dynamic_top_boundary_request_t) :: top_request
    real(real64) :: net_surface_irrigation_cm_per_day
    real(real64), allocatable :: root_sink(:)

    forcing = fmr_b110_physical_forcing_t()
    provenance = ppa_atm02_meteo_provenance_t()
    diagnostics = ppa_atm02_production_forcing_diagnostics_t()

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
    call apply_swinter0_identity_interval(weather, daily_result, gross_surface_irrigation_cm_per_day, interval_result, &
         net_surface_irrigation_cm_per_day, diagnostics%interval)
    if (diagnostics%interval%status /= PMDIRECT_SWETR0_OK .or. .not. diagnostics%interval%interval_result_produced) then
      diagnostics%status = PPA_ATM02_PRODUCTION_FORCING_INTERVAL_REJECTED
      return
    end if

    call fmr_bind_pmdirect_surface_evaporation_demand(daily_result, diagnostics%daily%process, surface_demand, diagnostics%surface)
    if (diagnostics%surface%status /= FMR_PMDIRECT_SURFACE_DEMAND_BINDING_OK) then
      diagnostics%status = PPA_ATM02_PRODUCTION_FORCING_SURFACE_REJECTED
      return
    end if
    call fmr_bind_pmdirect_swinter0_surface_fluxes(base_top_request, interval_result, net_surface_irrigation_cm_per_day, &
         diagnostics%interval, top_request, diagnostics%top_binding)
    if (diagnostics%top_binding%status /= FMR_PMDIRECT_SWINTER0_TOP_OK) then
      diagnostics%status = PPA_ATM02_PRODUCTION_FORCING_TOP_REJECTED
      return
    end if
    top_request%step_duration_day = requested_interval%t1 - requested_interval%t0
    top_request%potential_bare_soil_evaporation_cm_per_day = surface_demand%bare_soil_demand
    top_request%potential_pond_evaporation_cm_per_day = surface_demand%ponded_water_demand
    call evaluate_b110_dynamic_top_boundary(geometry, hydraulics, top_request, diagnostics%top_result)
    if (diagnostics%top_result%status /= B110_DYN_TOP_AVAILABLE .or. &
        diagnostics%top_result%regime /= B110_DYN_TOP_REGIME_FLUX .or. &
        .not. ieee_is_finite(diagnostics%top_result%actual_top_flux_cm_per_day) .or. &
        diagnostics%top_result%runoff_potential .or. &
        diagnostics%top_result%candidate_ponding_depth_cm /= 0.0_real64 .or. &
        diagnostics%top_result%runoff_depth_cm /= 0.0_real64) then
      diagnostics%status = PPA_ATM02_PRODUCTION_FORCING_TOP_REJECTED
      return
    end if

    call materialize_ppa_atm02_prescribed_root_sink(crop_root_input, geometry%active_nodes, interval_result, &
         diagnostics%interval, root_sink, diagnostics%root)
    if (diagnostics%root%status /= PPA_ATM02_ROOT_SINK_OK) then
      diagnostics%status = PPA_ATM02_PRODUCTION_FORCING_ROOT_REJECTED
      return
    end if
    forcing = base_forcing
    forcing%top_flux = diagnostics%top_result%actual_top_flux_cm_per_day
    if (allocated(forcing%root_extraction_sink)) deallocate(forcing%root_extraction_sink)
    call move_alloc(root_sink, forcing%root_extraction_sink)
    diagnostics%status = PPA_ATM02_PRODUCTION_FORCING_OK
    diagnostics%result_produced = .true.
  end subroutine materialize_ppa_atm02_pmdirect_production_forcing

end module mod_ppa_atm02_pmdirect_production_forcing_adapter
