program test_ppa_free_drainage_owner
  use, intrinsic :: iso_c_binding, only: c_int, c_int64_t
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_fmr_runtime_core, only: fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_b110_physical_state_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_commit_receipt_record_t
  use mod_fmr_production_application_bootstrap, only: fmr_production_application_config_t, &
       fmr_production_application_bootstrap_t, fmr_committed_top_state_t, FMR_APP_BOOT_OK, FMR_APP_BOOT_PROFILE_NOT_ADMITTED
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t, groundwater_coupling_window_t
  use mod_groundwater_topology_composition, only: groundwater_topology_tile_t, groundwater_topology_cell_t, &
       groundwater_topology_t, materialize_groundwater_topology, GW_TOPOLOGY_OK
  use mod_groundwater_application_plan, only: groundwater_tile_predictor_input_t, groundwater_cell_area_input_t
  use mod_modflow6_swap_predictor_response, only: modflow6_swap_predictor_lineage_t, &
       modflow6_derivative_coverage_t, compose_modflow6_swap_predictor_response, MODFLOW6_PREDICTOR_OK, &
       MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT
  use mod_modflow6_swap_prescribed_qbot_bottom_face, only: modflow6_prescribed_qbot_bottom_face_t, &
       materialize_modflow6_prescribed_qbot_bottom_face, MODFLOW6_BOTTOM_FACE_OK
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fmr_groundwater_application_c_api, only: fgc49d_context_counts_c
  use mod_ppa_atm02_typed_meteo_ingestion, only: ppa_atm02_decoded_daily_meteo_t, ppa_atm02_generic_interval_t, &
       ppa_atm02_meteo_provenance_t
  use mod_pmdirect_swetr0_process, only: pmdirect_swetr0_site_t, pmdirect_swetr0_canopy_t
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_result_t, B110_DYN_TOP_AVAILABLE, &
       B110_DYN_TOP_REGIME_FLUX
  use mod_ppa_wu04c_dynamic_top_forcing_adapter, only: bind_ppa_wu04c_dynamic_top_to_effective_forcing, &
       PPA_WU04C_TOP_FORCING_OK, PPA_WU04C_TOP_FORCING_REJECTED
  use mod_vonhhbraden_interception, only: vonhhbraden_source_window_t
  use mod_ppa_wu04c_production_forcing_adapter, only: ppa_wu04c_production_forcing_diagnostics_t, &
       materialize_ppa_wu04c_production_forcing, PPA_WU04C_PRODUCTION_FORCING_OK
  use mod_gash_interception, only: gash_parameters_t
  use mod_ppa_wu04d_production_forcing_adapter, only: ppa_wu04d_production_forcing_diagnostics_t, &
       materialize_ppa_wu04d_production_forcing, PPA_WU04D_PRODUCTION_FORCING_OK
  use mod_ppa_atm02_pmdirect_production_forcing_adapter, only: ppa_atm02_production_forcing_diagnostics_t, &
       materialize_ppa_atm02_pmdirect_production_forcing, PPA_ATM02_PRODUCTION_FORCING_OK
  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t
  use mod_fmr_vonhhbraden_source_window_progress, only: fmr_vonhhbraden_source_window_progress_t, &
       fmr_vonhhbraden_source_window_restart_t, fmr_initialize_vonhhbraden_source_window_progress, &
       fmr_restore_vonhhbraden_source_window_progress, FMR_VONHHBRADEN_PROGRESS_OK
  use mod_ppa_wu04c_runtime_publication, only: publish_ppa_wu04c_accepted_progress, PPA_WU04C_PUBLICATION_OK
  use mod_ppa_free_drainage_temporal_indicator, only: evaluate_free_drainage_temporal_indicator
  use mod_transaction_reference, only: TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_fmr_runtime_core, only: FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  implicit none

  integer, parameter :: NTILE = 2
  real(real64), parameter :: T0 = 4100.1875_real64
  real(real64), parameter :: T1 = 4100.6875_real64
  real(real64), parameter :: H0_CM = -75.0_real64
  real(real64), parameter :: HARD_MASS_GATE = 1.0e-12_real64
  real(real64), parameter :: PREDICTOR_QBOT = 1.0e-6_real64

  type(fmr_production_application_config_t) :: config, root_config, gw_config, bad_config, root_bad_config, drainage_bad_config
  type(fmr_production_application_bootstrap_t) :: app, root_app, gw_app, bad_app, root_bad_app, drainage_bad_app
  type(fmr_serialized_column_result_t), allocatable :: results(:)
  type(fmr_b110_physical_forcing_t), allocatable :: atm02_forcing(:)
  type(fmr_b110_physical_forcing_t) :: wu04c_forcing
  type(b110_dynamic_top_boundary_result_t) :: wu04c_top
  type(groundwater_topology_tile_t) :: topology_tiles(NTILE)
  type(groundwater_topology_cell_t) :: topology_cells(NTILE)
  type(groundwater_topology_t) :: topology
  type(groundwater_tile_predictor_input_t) :: predictors(NTILE)
  type(groundwater_cell_area_input_t) :: areas(NTILE)
  integer(int64), allocatable :: revisions(:)
  integer(int64) :: context_handle
  integer :: i, status, topology_status
  integer(c_int) :: ncell, ntile_count, c_status
  real(real64) :: reference_head_m

  call initialize_application_config(config)
  config%free_drainage_indicator => evaluate_free_drainage_temporal_indicator
  config%numerical%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
  config%numerical%transaction%max_retries = 16
  config%numerical%transaction%max_committed_substeps = 16384
  config%numerical%model_temporal_indicator_budget_available = .true.
  config%numerical%model_temporal_indicator_budget = 1.0e-5_real64
  do i=1,NTILE
    config%tiles(i)%parameters%max_iterations = 40
    config%tiles(i)%template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    allocate(config%tiles(i)%initial_right_derivative(numnod))
    config%tiles(i)%initial_right_derivative = 0.0_real64
  end do
  call verify_wu04c_production_composition(config)
  write(*,'(a)') 'PPA_FREE_DRAINAGE_OWNER_COMPOSITION=PASS'
contains
  subroutine initialize_application_config(value)
    type(fmr_production_application_config_t), intent(out) :: value
    real(real64) :: conductivity0
    integer :: k

    value%initial_time = T0
    value%numerical%transaction%temporal_tolerance = 0.0_real64
    value%numerical%transaction%mass_tolerance = HARD_MASS_GATE
    value%numerical%transaction%retry_scale = 0.5_real64
    value%numerical%transaction%max_retries = 2
    value%numerical%max_committed_substeps = 8
    value%numerical%progress_tolerance = 0.0_real64

    allocate(value%tiles(NTILE))
    do k = 1, NTILE
      value%tiles(k)%tile_id = 610100_int64 + int(k, int64)
      value%tiles(k)%ledger_id = 710100_int64 + int(k, int64)
      value%tiles(k)%template%template_id = 610200_int64 + int(k, int64)
      value%tiles(k)%template%physics_topology_id = 610210_int64
      value%tiles(k)%template%vertical_layout_id = 610220_int64
      value%tiles(k)%template%state_layout_id = 610230_int64
      value%tiles(k)%template%solver_interface_id = 610240_int64
      value%tiles(k)%template%optional_state_layout_id = 0_int64
      value%tiles(k)%template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
      value%tiles(k)%template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

      call initialize_parameters(value%tiles(k)%parameters, 620000_int64 + int(k, int64))
      call initialize_state_and_forcing(value%tiles(k)%parameters, value%tiles(k)%initial_state, &
           value%tiles(k)%base_forcing, 1.0_real64 + 0.013_real64 * real(k, real64), conductivity0)
      value%tiles(k)%initial_state%groundwater_level = -2.0_real64 - 0.007_real64 * real(k, real64)

      value%tiles(k)%groundwater_datum%available = .true.
      value%tiles(k)%groundwater_datum%datum_id = 630000_int64 + int(k, int64)
      value%tiles(k)%groundwater_datum%bottom_boundary_elevation_m = 0.0_real64
    end do
  end subroutine initialize_application_config

  subroutine initialize_parameters(p, parameter_id)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer(int64), intent(in) :: parameter_id
    integer :: k

    p%parameter_set_id = parameter_id
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod), p%cofgen(24, numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)
    p%cofgen = 0.0_real64
    do k = 1, numnod
      p%cofgen(1,k) = 0.032_real64
      p%cofgen(2,k) = 0.423_real64
      p%cofgen(3,k) = 4.75_real64
      p%cofgen(4,k) = 0.0135_real64
      p%cofgen(5,k) = 0.365_real64
      p%cofgen(6,k) = 1.455_real64
      p%cofgen(7,k) = 1.0_real64 - 1.0_real64 / p%cofgen(6,k)
      p%cofgen(8,k) = p%cofgen(4,k)
      p%cofgen(10,k) = p%cofgen(3,k)
      p%cofgen(11,k) = 0.999_real64
      p%cofgen(12,k) = 0.99_real64 * p%cofgen(3,k)
      p%cofgen(22,k) = -1.0e6_real64
      p%cofgen(23,k) = 1.0e-12_real64
    end do
    p%bottom_mode = 7
    p%swkimpl = 0
    p%swkmean = 1
    p%swsophy = 0
    p%root_extraction_active = .false.
    p%macropore_active = .false.
    p%snow_active = .false.
    p%hysteresis_active = .false.
    p%tabulated_hydraulics_active = .false.
    p%elasticity_active = .false.
    p%frost_active = .false.
    p%soil_temperature_active = .false.
    p%drainage_response_active = .false.
  end subroutine initialize_parameters

  subroutine initialize_state_and_forcing(p, state, forcing, scale, conductivity0)
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(in) :: scale
    real(real64), intent(out) :: conductivity0

    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: i

    heads = H0_CM
    call initialize_b110_default_mvg_parameters(hp, p%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, T1 - T0)
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    conductivity0 = conductivity(1)

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64

    forcing%top_flux = -conductivity0
    forcing%top_head = H0_CM
    forcing%bottom_flux = -conductivity0
    forcing%bottom_head = -100.0_real64
    allocate(forcing%drainage_flux_by_level(2,numnod), forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    do i = 1, numnod
      forcing%drainage_flux_by_level(1,i) = scale * 1.0e-5_real64 * real(i,real64)
      forcing%drainage_flux_by_level(2,i) = -scale * 2.0e-6_real64 * real(i+1,real64)
      forcing%subsurface_irrigation_source(i) = forcing%drainage_flux_by_level(1,i) + &
           forcing%drainage_flux_by_level(2,i)
      forcing%root_extraction_sink(i) = 0.0_real64
    end do
  end subroutine initialize_state_and_forcing

  subroutine verify_wu04c_production_composition(value)
    type(fmr_production_application_config_t), intent(in) :: value
    type(soil_water_parameter_set_t) :: geometry
    type(b110_default_mvg_parameters_t) :: hydraulics
    type(b110_dynamic_top_boundary_request_t) :: request
    type(vonhhbraden_source_window_t) :: source
    type(fmr_b110_physical_forcing_t) :: forcing
    type(fmr_b110_physical_forcing_t), allocatable :: forcing_vector(:)
    type(fmr_production_application_bootstrap_t) :: production_app
    type(fmr_serialized_column_result_t), allocatable :: production_results(:)
    type(ppa_wu04c_production_forcing_diagnostics_t) :: diagnostics
    type(ppa_wu04d_production_forcing_diagnostics_t) :: gash_diagnostics
    type(gash_parameters_t) :: gash
    real(real64) :: interception
    integer :: tile, local_status

    geometry%parameter_set_id = value%tiles(1)%parameters%parameter_set_id
    geometry%active_nodes = value%tiles(1)%parameters%active_nodes
    allocate(geometry%z(geometry%active_nodes), geometry%dz(geometry%active_nodes), geometry%node_distance(geometry%active_nodes))
    geometry%z = value%tiles(1)%parameters%z
    geometry%dz = value%tiles(1)%parameters%dz
    geometry%node_distance = value%tiles(1)%parameters%node_distance
    call initialize_b110_default_mvg_parameters(hydraulics, value%tiles(1)%parameters%cofgen)
    request%conductivity_mean_method = value%tiles(1)%parameters%swkmean
    request%pressure_head_top_cm = value%tiles(1)%initial_state%pressure_head(1)
    request%water_content_top = value%tiles(1)%initial_state%water_content(1)
    request%step_duration_day = T1 - T0
    request%ponding_max_cm = 2.0_real64
    request%runoff_resistance_day = 1.0_real64
    request%runoff_exponent = 1.0_real64
    source%gross_rain_cm_per_day = 0.40_real64
    source%sprinkling_irrigation_cm_per_day = 0.20_real64
    source%leaf_area_index = 2.0_real64
    source%vegetation_cover_fraction = 0.5_real64
    call materialize_ppa_wu04c_production_forcing(value%tiles(1)%base_forcing, request, geometry, hydraulics, source, &
         0.12_real64, 0.20_real64, 0.10_real64, forcing, interception, diagnostics)
    call require(diagnostics%status == PPA_WU04C_PRODUCTION_FORCING_OK .and. diagnostics%result_produced, &
         'WU04C full forcing composition')
    call require(abs(interception - 0.06_real64) <= 1.e-14_real64 .and. forcing%top_flux == diagnostics%top_result%actual_top_flux_cm_per_day, &
         'WU04C full forcing values')
    gash%free_throughfall = 0.10_real64; gash%stemflow = 0.05_real64
    gash%canopy_storage_cm = 0.10_real64; gash%average_evaporation = 0.05_real64
    gash%average_precipitation = 0.40_real64
    call materialize_ppa_wu04d_production_forcing(value%tiles(1)%base_forcing, request, geometry, hydraulics, gash, source, &
         0.20_real64, 0.10_real64, forcing, interception, gash_diagnostics)
    call require(gash_diagnostics%status == PPA_WU04D_PRODUCTION_FORCING_OK .and. gash_diagnostics%result_produced, &
         'WU04D full forcing composition')
    deallocate(geometry%z, geometry%dz, geometry%node_distance)

    allocate(forcing_vector(NTILE))
    do tile = 1, NTILE
      geometry%parameter_set_id = value%tiles(tile)%parameters%parameter_set_id
      geometry%active_nodes = value%tiles(tile)%parameters%active_nodes
      allocate(geometry%z(geometry%active_nodes), geometry%dz(geometry%active_nodes), geometry%node_distance(geometry%active_nodes))
      geometry%z = value%tiles(tile)%parameters%z; geometry%dz = value%tiles(tile)%parameters%dz
      geometry%node_distance = value%tiles(tile)%parameters%node_distance
      call initialize_b110_default_mvg_parameters(hydraulics, value%tiles(tile)%parameters%cofgen)
      request = b110_dynamic_top_boundary_request_t()
      request%conductivity_mean_method = value%tiles(tile)%parameters%swkmean
      request%pressure_head_top_cm = value%tiles(tile)%initial_state%pressure_head(1)
      request%water_content_top = value%tiles(tile)%initial_state%water_content(1)
      request%step_duration_day = T1 - T0; request%ponding_max_cm = 2.0_real64
      request%runoff_resistance_day = 1.0_real64; request%runoff_exponent = 1.0_real64
      call materialize_ppa_wu04c_production_forcing(value%tiles(tile)%base_forcing, request, geometry, hydraulics, source, &
           0.12_real64, 0.20_real64, 0.10_real64, forcing_vector(tile), interception, diagnostics)
      call require(diagnostics%status == PPA_WU04C_PRODUCTION_FORCING_OK, 'WU04C tile forcing composition')
      deallocate(geometry%z, geometry%dz, geometry%node_distance)
    end do
    call production_app%initialize(value, local_status)
    call require(local_status == FMR_APP_BOOT_OK, 'WU04C production owner initialize')
    call production_app%run_standalone_with_forcing(T0, T1, forcing_vector, production_results, local_status)
    call require(local_status == FMR_APP_BOOT_OK .and. all(production_results%completed) .and. all(production_results%committed), &
         'WU04C production owner commit')
    call require(maxval(abs(production_results%mass%residual)) <= HARD_MASS_GATE, 'WU04C production hard mass')
    call production_app%close(local_status)
    call require(local_status == FMR_APP_BOOT_OK, 'WU04C production owner close')
    deallocate(forcing_vector)

    allocate(forcing_vector(NTILE))
    do tile = 1, NTILE
      geometry%parameter_set_id = value%tiles(tile)%parameters%parameter_set_id
      geometry%active_nodes = value%tiles(tile)%parameters%active_nodes
      allocate(geometry%z(geometry%active_nodes), geometry%dz(geometry%active_nodes), geometry%node_distance(geometry%active_nodes))
      geometry%z = value%tiles(tile)%parameters%z; geometry%dz = value%tiles(tile)%parameters%dz
      geometry%node_distance = value%tiles(tile)%parameters%node_distance
      call initialize_b110_default_mvg_parameters(hydraulics, value%tiles(tile)%parameters%cofgen)
      request = b110_dynamic_top_boundary_request_t()
      request%conductivity_mean_method = value%tiles(tile)%parameters%swkmean
      request%pressure_head_top_cm = value%tiles(tile)%initial_state%pressure_head(1)
      request%water_content_top = value%tiles(tile)%initial_state%water_content(1)
      request%step_duration_day = T1 - T0; request%ponding_max_cm = 2.0_real64
      request%runoff_resistance_day = 1.0_real64; request%runoff_exponent = 1.0_real64
      call materialize_ppa_wu04d_production_forcing(value%tiles(tile)%base_forcing, request, geometry, hydraulics, gash, source, &
           0.20_real64, 0.10_real64, forcing_vector(tile), interception, gash_diagnostics)
      call require(gash_diagnostics%status == PPA_WU04D_PRODUCTION_FORCING_OK, 'WU04D tile forcing composition')
      deallocate(geometry%z, geometry%dz, geometry%node_distance)
    end do
    call production_app%initialize(value, local_status)
    call require(local_status == FMR_APP_BOOT_OK, 'WU04D production owner initialize')
    call production_app%run_standalone_with_forcing(T0, T1, forcing_vector, production_results, local_status)
    call require(local_status == FMR_APP_BOOT_OK .and. all(production_results%completed) .and. all(production_results%committed), &
         'WU04D production owner commit')
    call require(maxval(abs(production_results%mass%residual)) <= HARD_MASS_GATE, 'WU04D production hard mass')
    call production_app%close(local_status)
    call require(local_status == FMR_APP_BOOT_OK, 'WU04D production owner close')
    deallocate(forcing_vector)
  end subroutine verify_wu04c_production_composition

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a,1x,a)') 'PPA_WU01_FAIL', trim(message)
      error stop 1
    end if
  end subroutine require

end program test_ppa_free_drainage_owner
