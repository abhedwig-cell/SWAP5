program test_ppa_atm02_pmdirect_production_forcing_adapter
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_ppa_atm02_typed_meteo_ingestion, only: ppa_atm02_decoded_daily_meteo_t, ppa_atm02_generic_interval_t, &
       ppa_atm02_meteo_provenance_t
  use mod_pmdirect_swetr0_process, only: pmdirect_swetr0_site_t, pmdirect_swetr0_canopy_t
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, initialize_b110_default_mvg_parameters
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t
  use mod_ppa_atm02_pmdirect_production_forcing_adapter
  implicit none

  type(ppa_atm02_decoded_daily_meteo_t) :: decoded
  type(ppa_atm02_generic_interval_t) :: interval
  type(pmdirect_swetr0_site_t) :: site
  type(pmdirect_swetr0_canopy_t) :: canopy
  type(crop_root_uptake_input_t) :: root, invalid_root
  type(soil_water_parameter_set_t) :: geometry
  type(b110_default_mvg_parameters_t) :: hydraulics
  type(b110_dynamic_top_boundary_request_t) :: top
  type(fmr_b110_physical_forcing_t) :: base, forcing
  type(ppa_atm02_meteo_provenance_t) :: provenance
  type(ppa_atm02_production_forcing_diagnostics_t) :: diagnostics

  call initialize_fixture(decoded, interval, site, canopy, root, geometry, hydraulics, top, base)
  call materialize_ppa_atm02_pmdirect_production_forcing(decoded, interval, site, canopy, 0.0_real64, root, geometry, &
       hydraulics, top, base, forcing, provenance, diagnostics)
  call require(diagnostics%status == PPA_ATM02_PRODUCTION_FORCING_OK .and. diagnostics%result_produced, 'valid forcing rejected')
  call require(provenance%source_id == decoded%source_id .and. provenance%source_record_index == decoded%source_record_index, &
       'provenance lost')
  call require(allocated(forcing%root_extraction_sink) .and. size(forcing%root_extraction_sink) == 2, 'root sink absent')
  call require(sum(forcing%root_extraction_sink) > 0.0_real64 .and. &
       all(forcing%root_extraction_sink >= 0.0_real64), 'root sink not materialized')
  call require(forcing%top_flux == diagnostics%top_result%actual_top_flux_cm_per_day, 'top flux not carried')
  write(*,'(a)') 'PPA_ATM02_PRODUCTION_FORCING_COMPOSITION=PASS'
  write(*,'(a)') 'PPA_ATM02_PRODUCTION_FORCING_ROOT_CONSERVATION=PASS'

  invalid_root = root
  invalid_root%rooted_nodes = 3
  call materialize_ppa_atm02_pmdirect_production_forcing(decoded, interval, site, canopy, 0.0_real64, invalid_root, geometry, &
       hydraulics, top, base, forcing, provenance, diagnostics)
  call require(diagnostics%status == PPA_ATM02_PRODUCTION_FORCING_ROOT_REJECTED .and. .not. diagnostics%result_produced, &
       'invalid root geometry did not fail closed')
  write(*,'(a)') 'PPA_ATM02_PRODUCTION_FORCING_FAIL_CLOSED=PASS'

contains

  subroutine initialize_fixture(decoded, interval, site, canopy, root, geometry, hydraulics, top, forcing)
    type(ppa_atm02_decoded_daily_meteo_t), intent(out) :: decoded
    type(ppa_atm02_generic_interval_t), intent(out) :: interval
    type(pmdirect_swetr0_site_t), intent(out) :: site
    type(pmdirect_swetr0_canopy_t), intent(out) :: canopy
    type(crop_root_uptake_input_t), intent(out) :: root
    type(soil_water_parameter_set_t), intent(out) :: geometry
    type(b110_default_mvg_parameters_t), intent(out) :: hydraulics
    type(b110_dynamic_top_boundary_request_t), intent(out) :: top
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64) :: cofgen(24,2)
    integer :: i

    decoded%source_id = 17_int64; decoded%source_record_index = 4
    decoded%day_of_year = 180; decoded%t0 = 100.0_real64; decoded%t1 = 101.0_real64
    decoded%radiation_j_m2_d = 18.0e6_real64; decoded%minimum_air_temperature_c = 12.0_real64
    decoded%maximum_air_temperature_c = 24.0_real64; decoded%vapour_pressure_kpa = 1.3_real64
    decoded%wind_speed_m_s = 2.0_real64; decoded%gross_rain_cm_d = 0.0_real64
    interval%t0 = decoded%t0; interval%t1 = decoded%t1
    site%latitude_degrees = 52.0_real64; site%altitude_m = 10.0_real64
    site%wind_measurement_height_m = 2.0_real64; site%humidity_measurement_height_m = 2.0_real64
    site%angstrom_a = 0.25_real64; site%angstrom_b = 0.50_real64; site%soil_surface_resistance_s_m = 100.0_real64
    canopy%crop_emerged = .true.; canopy%lai = 3.0_real64; canopy%vegetation_cover_fraction = 0.7_real64
    canopy%cofab_cm = 0.5_real64; canopy%albedo = 0.23_real64; canopy%dry_canopy_resistance_s_m = 70.0_real64
    canopy%wet_canopy_resistance_s_m = 30.0_real64
    root%crop_emerged = .true.; root%rooted_nodes = 2
    allocate(root%cumulative_root_fraction(3)); root%cumulative_root_fraction = [0.0_real64, 0.4_real64, 1.0_real64]
    geometry%parameter_set_id = 1_int64; geometry%active_nodes = 2
    allocate(geometry%z(2), geometry%dz(2), geometry%node_distance(2))
    geometry%z = [-5.0_real64, -15.0_real64]; geometry%dz = [10.0_real64, 10.0_real64]
    geometry%node_distance = [5.0_real64, 10.0_real64]
    cofgen = 0.0_real64
    do i = 1, 2
      cofgen(1,i) = 0.032_real64; cofgen(2,i) = 0.423_real64; cofgen(3,i) = 4.75_real64
      cofgen(4,i) = 0.0135_real64; cofgen(5,i) = 0.365_real64; cofgen(6,i) = 1.455_real64
      cofgen(7,i) = 1.0_real64 - 1.0_real64 / cofgen(6,i); cofgen(8,i) = cofgen(4,i)
      cofgen(10,i) = cofgen(3,i); cofgen(11,i) = 0.999_real64; cofgen(12,i) = 0.99_real64 * cofgen(3,i)
      cofgen(22,i) = -1.0e6_real64; cofgen(23,i) = 1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hydraulics, cofgen)
    top%conductivity_mean_method = 1; top%pressure_head_top_cm = -100.0_real64; top%water_content_top = 0.2_real64
    top%ponding_max_cm = 2.0_real64; top%runoff_resistance_day = 1.0_real64; top%runoff_exponent = 1.0_real64
    forcing%top_flux = 0.0_real64; forcing%top_head = -100.0_real64; forcing%bottom_flux = 0.0_real64; forcing%bottom_head = -100.0_real64
  end subroutine initialize_fixture

  subroutine require(ok, label)
    logical, intent(in) :: ok
    character(*), intent(in) :: label
    if (.not. ok) then; write(*,'(a)') trim(label); error stop 1; end if
  end subroutine require
end program test_ppa_atm02_pmdirect_production_forcing_adapter
