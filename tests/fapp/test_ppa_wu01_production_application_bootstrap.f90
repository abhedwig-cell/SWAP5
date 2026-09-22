program test_ppa_wu01_production_application_bootstrap
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
  use mod_ppa_atm02_pmdirect_production_forcing_adapter, only: ppa_atm02_production_forcing_diagnostics_t, &
       materialize_ppa_atm02_pmdirect_production_forcing, PPA_ATM02_PRODUCTION_FORCING_OK
  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t
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

  ! Standalone authority: use the already-qualified serialized Reference
  ! profile rather than inventing a new mode-5 standalone trajectory.
  call initialize_application_config(config)
  call app%initialize(config, status)
  call require(status == FMR_APP_BOOT_OK, 'standalone production bootstrap initialize')
  call require(app%ready(), 'standalone production bootstrap ready')
  call require(app%tile_count() == NTILE, 'standalone production bootstrap tile count')

  call app%copy_committed_revisions(revisions, status)
  call require(status == FMR_APP_BOOT_OK .and. all(revisions == 0_int64), 'initial committed revisions')

  call app%run_standalone(T0, T1, results, status)
  if (status /= FMR_APP_BOOT_OK) then
    write(*,'(a,1x,i0)') 'PPA_WU01_DEBUG_STANDALONE_STATUS', status
    if (allocated(results)) then
      do i = 1, size(results)
        write(*,'(a,1x,i0,1x,a,1x,i0,1x,l1,1x,l1,1x,l1,1x,i0)') 'PPA_WU01_DEBUG_RESULT', i, &
             trim(results(i)%admission_status), results(i)%kernel_status, results(i)%admitted, &
             results(i)%completed, results(i)%committed, results(i)%accepted_substeps
      end do
    end if
  end if
  call require(status == FMR_APP_BOOT_OK, 'standalone run status')
  call require(allocated(results) .and. size(results) == NTILE, 'standalone result count')
  call require(all(results%completed) .and. all(results%committed), 'standalone accepted commits')
  call require(maxval(abs(results%mass%residual)) <= HARD_MASS_GATE, 'standalone hard mass')
  call app%copy_committed_revisions(revisions, status)
  call require(status == FMR_APP_BOOT_OK .and. all(revisions == 1_int64), 'standalone owner committed revisions')
  call app%close(status)
  call require(status == FMR_APP_BOOT_OK .and. .not. app%ready(), 'clean standalone owner close')

  ! PPA-WU01-ROOT-PROFILE: retain the existing owner, transaction and mass
  ! ledger. Only the already-qualified concrete prescribed root sink becomes
  ! active on the standalone mode-7 base route.
  root_config = config
  do i = 1, NTILE
    root_config%tiles(i)%parameters%root_extraction_active = .true.
    root_config%tiles(i)%base_forcing%root_extraction_sink = 0.0_real64
    root_config%tiles(i)%base_forcing%root_extraction_sink(1:min(4, numnod)) = 0.005_real64
  end do
  call root_app%initialize(root_config, status)
  call require(status == FMR_APP_BOOT_OK .and. root_app%ready(), 'root-enabled standalone initialize')
  call root_app%run_standalone(T0, T1, results, status)
  call require(status == FMR_APP_BOOT_OK, 'root-enabled standalone run status')
  call require(all(results%completed) .and. all(results%committed), 'root-enabled accepted commits')
  call require(maxval(abs(results%mass%residual)) <= HARD_MASS_GATE, 'root-enabled hard mass')
  call root_app%copy_committed_revisions(revisions, status)
  call require(status == FMR_APP_BOOT_OK .and. all(revisions == 1_int64), 'root-enabled committed revisions')
  call root_app%close(status)
  call require(status == FMR_APP_BOOT_OK .and. .not. root_app%ready(), 'clean root-enabled owner close')

  call run_atm02_pmdirect_owner_profile(config)

  ! Groundwater authority: the same production bootstrap type owns an admitted
  ! bottom_mode=5 participant registry and creates F-GC49D from typed inputs.
  gw_config = config
  do i = 1, NTILE
    gw_config%tiles(i)%parameters%bottom_mode = 5
  end do
  call gw_app%initialize(gw_config, status)
  call require(status == FMR_APP_BOOT_OK .and. gw_app%ready(), 'groundwater production bootstrap initialize')

  call compute_reference_head(gw_config%tiles(1)%parameters, gw_config%tiles(1)%groundwater_datum, &
       reference_head_m, status)
  call require(status == MODFLOW6_BOTTOM_FACE_OK, 'groundwater reference head')

  do i = 1, NTILE
    topology_tiles(i)%tile_id = gw_config%tiles(i)%tile_id
    topology_tiles(i)%swap_lineage_id = gw_config%tiles(i)%tile_id
    topology_tiles(i)%ledger_id = gw_config%tiles(i)%ledger_id
    topology_tiles(i)%groundwater_cell_id = 7000_int64 + int(i, int64)
    topology_tiles(i)%area_fraction = 1.0_real64

    topology_cells(i)%groundwater_cell_id = topology_tiles(i)%groundwater_cell_id
    topology_cells(i)%coupling_id = 8000_int64 + int(i, int64)
    topology_cells(i)%groundwater_service_id = 9001_int64
    topology_cells(i)%groundwater_lineage_id = 9000_int64 + int(i, int64)
    topology_cells(i)%package_slot = i
    topology_cells(i)%modflow_node_id = i

    call make_predictor(predictors(i), topology_tiles(i), topology_cells(i), reference_head_m, i)
    areas(i)%groundwater_cell_id = topology_cells(i)%groundwater_cell_id
    areas(i)%cell_area_m2 = 1.0_real64
  end do

  call materialize_groundwater_topology(topology_tiles, topology_cells, topology, topology_status)
  call require(topology_status == GW_TOPOLOGY_OK .and. topology%ready(), 'typed topology')

  call gw_app%materialize_groundwater_context(topology, predictors, areas, context_handle, status)
  call require(status == FMR_APP_BOOT_OK .and. context_handle > 0_int64, 'owned F-GC49D context materialization')

  ncell = 0_c_int
  ntile_count = 0_c_int
  c_status = fgc49d_context_counts_c(int(context_handle, c_int64_t), ncell, ntile_count)
  call require(c_status == 0_c_int, 'registered context handle')
  call require(ncell == int(NTILE, c_int) .and. ntile_count == int(NTILE, c_int), 'registered context counts')

  call gw_app%release_groundwater_context(status)
  call require(status == FMR_APP_BOOT_OK, 'context release')
  c_status = fgc49d_context_counts_c(int(context_handle, c_int64_t), ncell, ntile_count)
  call require(c_status /= 0_c_int, 'released context handle fails closed')
  call gw_app%close(status)
  call require(status == FMR_APP_BOOT_OK .and. .not. gw_app%ready(), 'clean groundwater owner close')

  bad_config = config
  bad_config%tiles(1)%parameters%bottom_mode = 6
  call bad_app%initialize(bad_config, status)
  call require(status == FMR_APP_BOOT_PROFILE_NOT_ADMITTED, 'non-WU01 profile fails closed')
  call require(.not. bad_app%ready(), 'failed bootstrap owns no live runtime')

  ! PUB-GC E7 current-canonical boundary: mode-5 groundwater ownership must
  ! remain fail-closed for active root extraction and active drainage response.
  ! These checks qualify the owner boundary only; they do not widen it.
  root_bad_config = gw_config
  root_bad_config%tiles(1)%parameters%root_extraction_active = .true.
  call root_bad_app%initialize(root_bad_config, status)
  call require(status == FMR_APP_BOOT_PROFILE_NOT_ADMITTED, &
       'groundwater owner with root extraction fails closed')
  call require(.not. root_bad_app%ready(), 'root-extraction rejection owns no live runtime')

  drainage_bad_config = gw_config
  drainage_bad_config%tiles(1)%parameters%drainage_response_active = .true.
  call drainage_bad_app%initialize(drainage_bad_config, status)
  call require(status == FMR_APP_BOOT_PROFILE_NOT_ADMITTED, &
       'groundwater owner with drainage response fails closed')
  call require(.not. drainage_bad_app%ready(), 'drainage-response rejection owns no live runtime')

  print '(a)', 'PPA_WU01_TYPED_CONFIG_TO_FMR_OWNER=PASS'
  print '(a)', 'PPA_WU01_STANDALONE_REFERENCE_RICHARDS_RUNTIME=PASS'
  print '(a)', 'PPA_WU01_STANDALONE_HARD_MASS=PASS'
  print '(a)', 'PPA_WU01_ROOT_PROFILE_STANDALONE_RUNTIME=PASS'
  print '(a)', 'PPA_WU01_ROOT_PROFILE_HARD_MASS=PASS'
  print '(a)', 'PPA_WU01_ROOT_PROFILE_COMMITTED_OWNER=PASS'
  print '(a)', 'PPA_ATM02_PRODUCTION_OWNER_COMPOSITION=PASS'
  print '(a)', 'PPA_ATM02_PRODUCTION_OWNER_HARD_MASS=PASS'
  print '(a)', 'PPA_ATM02_OWNER_COMMITTED_TOP_SNAPSHOT=PASS'
  print '(a)', 'PPA_ATM02_TWO_INTERVAL_OWNER_CONTINUATION=PASS'
  print '(a)', 'PPA_ATM02_TWO_INTERVAL_HARD_MASS=PASS'
  print '(a)', 'PPA_ATM02_OWNER_RESTART_CONTINUATION=PASS'
  print '(a)', 'PPA_WU04C_OWNER_ACCEPTED_RECEIPTS=PASS'
  print '(a)', 'PPA_WU01_COMMITTED_STATE_FORTRAN_OWNED=PASS'
  print '(a)', 'PPA_WU01_FGC49B_REGISTRY_FORTRAN_OWNED=PASS'
  print '(a)', 'PPA_WU01_MASS_LEDGERS_FORTRAN_OWNED=PASS'
  print '(a)', 'PPA_WU01_FGC49D_CONTEXT_FROM_PRODUCTION_OWNER=PASS'
  print '(a)', 'PPA_WU01_NO_QUALIFICATION_FIXTURE_BOOTSTRAP=PASS'
  print '(a)', 'PPA_WU01_UNADMITTED_PROFILE_FAILS_CLOSED=PASS'
  print '(a)', 'PPA_WU01_GROUNDWATER_ROOT_EXTRACTION_FAIL_CLOSED=PASS'
  print '(a)', 'PPA_WU01_GROUNDWATER_DRAINAGE_RESPONSE_FAIL_CLOSED=PASS'
  print '(a)', 'PPA_WU01_GROUNDWATER_ACTIVE_PROCESS_COMPOSITION_FAIL_CLOSED=PASS'
  print '(a)', 'PPA-WU01 PRODUCTION APPLICATION BOOTSTRAP GATE PASS'

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

  subroutine make_predictor(input, tile, cell, href, slot)
    type(groundwater_tile_predictor_input_t), intent(out) :: input
    type(groundwater_topology_tile_t), intent(in) :: tile
    type(groundwater_topology_cell_t), intent(in) :: cell
    real(real64), intent(in) :: href
    integer, intent(in) :: slot

    type(modflow6_swap_predictor_lineage_t) :: lineage
    type(modflow6_derivative_coverage_t) :: coverage
    type(groundwater_coupling_window_t) :: window
    integer :: local_status

    input%tile_id = tile%tile_id
    window%t0 = T0
    window%t1 = T1
    lineage%coupling_id = cell%coupling_id
    lineage%swap_lineage_id = tile%swap_lineage_id
    lineage%swap_origin_revision = 0_int64
    lineage%groundwater_service_id = cell%groundwater_service_id
    lineage%groundwater_lineage_id = cell%groundwater_lineage_id
    lineage%groundwater_origin_revision = 0_int64
    coverage%lower_face_head_semantics_covered = .true.
    coverage%richards_hydraulic_response_covered = .true.
    coverage%constitutive_response_covered = .true.
    call compose_modflow6_swap_predictor_response(window, lineage, 0.001_real64, href, &
         href + real(slot, real64) * 0.001_real64, 0.25_real64, MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT, &
         coverage, 'ppa-wu01', 'typed-production-bootstrap', input%response, local_status)
    call require(local_status == MODFLOW6_PREDICTOR_OK .and. input%response%valid, 'predictor response')
  end subroutine make_predictor

  subroutine compute_reference_head(p, datum, head_m, local_status)
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    type(groundwater_head_datum_t), intent(in) :: datum
    real(real64), intent(out) :: head_m
    integer, intent(out) :: local_status

    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    type(modflow6_prescribed_qbot_bottom_face_t) :: face
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)

    heads = H0_CM
    call initialize_b110_default_mvg_parameters(hp, p%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, T1 - T0)
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    call materialize_modflow6_prescribed_qbot_bottom_face(heads(numnod), conductivity(numnod), PREDICTOR_QBOT, &
         0.5_real64 * p%dz(numnod), datum, face, local_status)
    if (local_status == MODFLOW6_BOTTOM_FACE_OK) then
      head_m = face%hydraulic_head_m
    else
      head_m = 0.0_real64
    end if
  end subroutine compute_reference_head

  subroutine run_atm02_pmdirect_owner_profile(base_config)
    type(fmr_production_application_config_t), intent(in) :: base_config
    type(fmr_production_application_config_t) :: atm_config
    type(fmr_production_application_bootstrap_t) :: atm_app
    type(ppa_atm02_decoded_daily_meteo_t) :: decoded
    type(ppa_atm02_generic_interval_t) :: forcing_interval
    type(pmdirect_swetr0_site_t) :: site
    type(pmdirect_swetr0_canopy_t) :: canopy
    type(crop_root_uptake_input_t) :: root_input
    type(soil_water_parameter_set_t) :: geometry
    type(b110_default_mvg_parameters_t) :: hydraulics
    type(b110_dynamic_top_boundary_request_t) :: top_request
    type(ppa_atm02_meteo_provenance_t) :: provenance
    type(ppa_atm02_production_forcing_diagnostics_t) :: atm_diagnostics
    type(fmr_committed_top_state_t), allocatable :: committed_top(:)
    type(fmr_serialized_commit_receipt_record_t), allocatable :: receipts(:)
    type(fmr_committed_restart_bundle_t) :: restart_bundle
    logical :: restart_exported, restart_restored
    integer :: tile, local_status, node
    real(real64) :: t2

    atm_config = base_config
    do tile = 1, NTILE
      atm_config%tiles(tile)%parameters%root_extraction_active = .true.
    end do
    allocate(atm02_forcing(NTILE))
    forcing_interval%t0 = T0; forcing_interval%t1 = T1
    decoded%source_id = 9201_int64; decoded%source_record_index = 44
    decoded%day_of_year = 180; decoded%t0 = T0 - 0.25_real64; decoded%t1 = T1 + 0.25_real64
    decoded%radiation_j_m2_d = 18.0e6_real64; decoded%minimum_air_temperature_c = 12.0_real64
    decoded%maximum_air_temperature_c = 24.0_real64; decoded%vapour_pressure_kpa = 1.3_real64
    decoded%wind_speed_m_s = 2.0_real64; decoded%gross_rain_cm_d = 0.0_real64
    site%latitude_degrees = 52.0_real64; site%altitude_m = 10.0_real64
    site%wind_measurement_height_m = 2.0_real64; site%humidity_measurement_height_m = 2.0_real64
    site%angstrom_a = 0.25_real64; site%angstrom_b = 0.50_real64; site%soil_surface_resistance_s_m = 100.0_real64
    canopy%crop_emerged = .true.; canopy%lai = 3.0_real64; canopy%vegetation_cover_fraction = 0.7_real64
    canopy%cofab_cm = 0.5_real64; canopy%albedo = 0.23_real64
    canopy%dry_canopy_resistance_s_m = 70.0_real64; canopy%wet_canopy_resistance_s_m = 30.0_real64
    do tile = 1, NTILE
      geometry%parameter_set_id = atm_config%tiles(tile)%parameters%parameter_set_id
      geometry%active_nodes = atm_config%tiles(tile)%parameters%active_nodes
      allocate(geometry%z(geometry%active_nodes), geometry%dz(geometry%active_nodes), geometry%node_distance(geometry%active_nodes))
      geometry%z = atm_config%tiles(tile)%parameters%z; geometry%dz = atm_config%tiles(tile)%parameters%dz
      geometry%node_distance = atm_config%tiles(tile)%parameters%node_distance
      call initialize_b110_default_mvg_parameters(hydraulics, atm_config%tiles(tile)%parameters%cofgen)
      root_input%crop_emerged = .true.; root_input%rooted_nodes = min(4, geometry%active_nodes)
      allocate(root_input%cumulative_root_fraction(root_input%rooted_nodes + 1))
      do node = 1, root_input%rooted_nodes + 1
        root_input%cumulative_root_fraction(node) = real(node - 1, real64) / real(root_input%rooted_nodes, real64)
      end do
      top_request = b110_dynamic_top_boundary_request_t()
      top_request%conductivity_mean_method = atm_config%tiles(tile)%parameters%swkmean
      top_request%pressure_head_top_cm = atm_config%tiles(tile)%initial_state%pressure_head(1)
      top_request%water_content_top = atm_config%tiles(tile)%initial_state%water_content(1)
      top_request%ponding_max_cm = 2.0_real64; top_request%runoff_resistance_day = 1.0_real64; top_request%runoff_exponent = 1.0_real64
      call materialize_ppa_atm02_pmdirect_production_forcing(decoded, forcing_interval, site, canopy, 0.0_real64, root_input, &
           geometry, hydraulics, top_request, atm_config%tiles(tile)%base_forcing, atm02_forcing(tile), provenance, atm_diagnostics)
      call require(atm_diagnostics%status == PPA_ATM02_PRODUCTION_FORCING_OK .and. atm_diagnostics%result_produced, 'ATM02 forcing composition')
      deallocate(geometry%z, geometry%dz, geometry%node_distance, root_input%cumulative_root_fraction)
    end do
    call atm_app%initialize(atm_config, local_status)
    call require(local_status == FMR_APP_BOOT_OK .and. atm_app%ready(), 'ATM02 owner initialize')
    call atm_app%run_standalone_with_forcing_receipts(T0, T1, atm02_forcing, results, receipts, local_status)
    call require(local_status == FMR_APP_BOOT_OK .and. all(results%completed) .and. all(results%committed), 'ATM02 owner commit')
    call require(size(receipts) == NTILE .and. receipts(1)%receipt%ready() .and. receipts(2)%receipt%ready(), &
         'ATM02 owner accepted receipts')
    call require(maxval(abs(results%mass%residual)) <= HARD_MASS_GATE, 'ATM02 owner hard mass')
    call atm_app%copy_committed_top_states(committed_top, local_status)
    call require(local_status == FMR_APP_BOOT_OK .and. size(committed_top) == NTILE .and. all(committed_top%available), &
         'ATM02 committed top snapshot')
    call require(all(committed_top%revision == 1_int64) .and. all(committed_top%committed_time == T1), &
         'ATM02 committed top provenance')
    call atm_app%export_committed_restart(9901_int64, restart_bundle, restart_exported, local_status)
    call require(local_status == FMR_APP_BOOT_OK .and. restart_exported, 'ATM02 owner restart export')
    call atm_app%restore_committed_restart(restart_bundle, 9901_int64, restart_restored, local_status)
    call require(local_status == FMR_APP_BOOT_OK .and. restart_restored, 'ATM02 owner restart restore')
    t2 = T1 + (T1 - T0)
    forcing_interval%t0 = T1; forcing_interval%t1 = t2
    decoded%source_record_index = 45
    decoded%t0 = T1 - 0.25_real64; decoded%t1 = t2 + 0.25_real64
    do tile = 1, NTILE
      geometry%parameter_set_id = atm_config%tiles(tile)%parameters%parameter_set_id
      geometry%active_nodes = atm_config%tiles(tile)%parameters%active_nodes
      allocate(geometry%z(geometry%active_nodes), geometry%dz(geometry%active_nodes), geometry%node_distance(geometry%active_nodes))
      geometry%z = atm_config%tiles(tile)%parameters%z; geometry%dz = atm_config%tiles(tile)%parameters%dz
      geometry%node_distance = atm_config%tiles(tile)%parameters%node_distance
      call initialize_b110_default_mvg_parameters(hydraulics, atm_config%tiles(tile)%parameters%cofgen)
      root_input%crop_emerged = .true.; root_input%rooted_nodes = min(4, geometry%active_nodes)
      allocate(root_input%cumulative_root_fraction(root_input%rooted_nodes + 1))
      do node = 1, root_input%rooted_nodes + 1
        root_input%cumulative_root_fraction(node) = real(node - 1, real64) / real(root_input%rooted_nodes, real64)
      end do
      top_request = b110_dynamic_top_boundary_request_t()
      top_request%conductivity_mean_method = atm_config%tiles(tile)%parameters%swkmean
      top_request%pressure_head_top_cm = committed_top(tile)%pressure_head_top_cm
      top_request%water_content_top = committed_top(tile)%water_content_top
      top_request%previous_ponding_depth_cm = committed_top(tile)%ponding_depth_cm
      top_request%ponding_max_cm = 2.0_real64; top_request%runoff_resistance_day = 1.0_real64; top_request%runoff_exponent = 1.0_real64
      call materialize_ppa_atm02_pmdirect_production_forcing(decoded, forcing_interval, site, canopy, 0.0_real64, root_input, &
           geometry, hydraulics, top_request, atm_config%tiles(tile)%base_forcing, atm02_forcing(tile), provenance, atm_diagnostics)
      call require(atm_diagnostics%status == PPA_ATM02_PRODUCTION_FORCING_OK .and. atm_diagnostics%result_produced, &
           'ATM02 continuation forcing composition')
      deallocate(geometry%z, geometry%dz, geometry%node_distance, root_input%cumulative_root_fraction)
    end do
    call atm_app%run_standalone_with_forcing(T1, t2, atm02_forcing, results, local_status)
    call require(local_status == FMR_APP_BOOT_OK .and. all(results%completed) .and. all(results%committed), &
         'ATM02 continuation owner commit')
    call require(maxval(abs(results%mass%residual)) <= HARD_MASS_GATE, 'ATM02 continuation hard mass')
    call atm_app%copy_committed_revisions(revisions, local_status)
    call require(local_status == FMR_APP_BOOT_OK .and. all(revisions == 2_int64), 'ATM02 owner revisions')
    call atm_app%close(local_status)
    call require(local_status == FMR_APP_BOOT_OK, 'ATM02 owner close')
    deallocate(atm02_forcing)
  end subroutine run_atm02_pmdirect_owner_profile

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a,1x,a)') 'PPA_WU01_FAIL', trim(message)
      error stop 1
    end if
  end subroutine require

end program test_ppa_wu01_production_application_bootstrap
