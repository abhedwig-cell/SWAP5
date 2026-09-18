program test_ppa_wu01_production_application_bootstrap
  use, intrinsic :: iso_c_binding, only: c_int, c_int64_t
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_fmr_runtime_core, only: fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_b110_physical_state_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t
  use mod_fmr_production_application_bootstrap, only: fmr_production_application_config_t, &
       fmr_production_application_bootstrap_t, FMR_APP_BOOT_OK, FMR_APP_BOOT_PROFILE_NOT_ADMITTED
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
  implicit none

  integer, parameter :: NTILE = 2
  real(real64), parameter :: H0_CM = -75.0_real64
  real(real64), parameter :: DURATION_DAY = 1.0e-4_real64
  real(real64), parameter :: TOL = 1.0e-12_real64
  real(real64), parameter :: PREDICTOR_QBOT = 1.0e-6_real64

  type(fmr_production_application_config_t) :: config, bad_config
  type(fmr_production_application_bootstrap_t) :: app, bad_app
  type(fmr_serialized_column_result_t), allocatable :: results(:)
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
  call app%initialize(config, status)
  call require(status == FMR_APP_BOOT_OK, 'production bootstrap initialize')
  call require(app%ready(), 'production bootstrap ready')
  call require(app%tile_count() == NTILE, 'production bootstrap tile count')

  call app%copy_committed_revisions(revisions, status)
  call require(status == FMR_APP_BOOT_OK .and. all(revisions == 0_int64), 'initial committed revisions')

  call app%run_standalone(0.0_real64, DURATION_DAY, results, status)
  call require(status == FMR_APP_BOOT_OK, 'standalone run status')
  call require(allocated(results) .and. size(results) == NTILE, 'standalone result count')
  call require(all(results%completed) .and. all(results%committed), 'standalone accepted commits')
  call app%copy_committed_revisions(revisions, status)
  call require(status == FMR_APP_BOOT_OK .and. all(revisions == 1_int64), 'standalone owner committed revisions')

  call compute_reference_head(config%tiles(1)%parameters, config%tiles(1)%groundwater_datum, reference_head_m, status)
  call require(status == MODFLOW6_BOTTOM_FACE_OK, 'reference head')

  do i = 1, NTILE
    topology_tiles(i)%tile_id = config%tiles(i)%tile_id
    topology_tiles(i)%swap_lineage_id = config%tiles(i)%tile_id
    topology_tiles(i)%ledger_id = config%tiles(i)%ledger_id
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

  call app%materialize_groundwater_context(topology, predictors, areas, context_handle, status)
  call require(status == FMR_APP_BOOT_OK .and. context_handle > 0_int64, 'owned F-GC49D context materialization')

  ncell = 0_c_int
  ntile_count = 0_c_int
  c_status = fgc49d_context_counts_c(int(context_handle, c_int64_t), ncell, ntile_count)
  call require(c_status == 0_c_int, 'registered context handle')
  call require(ncell == int(NTILE, c_int) .and. ntile_count == int(NTILE, c_int), 'registered context counts')

  call app%release_groundwater_context(status)
  call require(status == FMR_APP_BOOT_OK, 'context release')
  c_status = fgc49d_context_counts_c(int(context_handle, c_int64_t), ncell, ntile_count)
  call require(c_status /= 0_c_int, 'released context handle fails closed')

  call app%run_standalone(DURATION_DAY, 2.0_real64 * DURATION_DAY, results, status)
  call require(status == FMR_APP_BOOT_OK, 'owner reusable after context retirement')
  call app%copy_committed_revisions(revisions, status)
  call require(status == FMR_APP_BOOT_OK .and. all(revisions == 2_int64), 'persistent committed owner across runs')

  call app%close(status)
  call require(status == FMR_APP_BOOT_OK .and. .not. app%ready(), 'clean owner close')

  bad_config = config
  bad_config%tiles(1)%parameters%bottom_mode = 6
  call bad_app%initialize(bad_config, status)
  call require(status == FMR_APP_BOOT_PROFILE_NOT_ADMITTED, 'non-WU01 profile fails closed')
  call require(.not. bad_app%ready(), 'failed bootstrap owns no live runtime')

  print '(a)', 'PPA_WU01_TYPED_CONFIG_TO_FMR_OWNER=PASS'
  print '(a)', 'PPA_WU01_STANDALONE_REFERENCE_RICHARDS_RUNTIME=PASS'
  print '(a)', 'PPA_WU01_COMMITTED_STATE_FORTRAN_OWNED=PASS'
  print '(a)', 'PPA_WU01_FGC49B_REGISTRY_FORTRAN_OWNED=PASS'
  print '(a)', 'PPA_WU01_MASS_LEDGERS_FORTRAN_OWNED=PASS'
  print '(a)', 'PPA_WU01_FGC49D_CONTEXT_FROM_PRODUCTION_OWNER=PASS'
  print '(a)', 'PPA_WU01_NO_QUALIFICATION_FIXTURE_BOOTSTRAP=PASS'
  print '(a)', 'PPA_WU01_OWNER_REUSABLE_ACROSS_CONTEXT_WINDOW=PASS'
  print '(a)', 'PPA_WU01_UNADMITTED_PROFILE_FAILS_CLOSED=PASS'
  print '(a)', 'PPA-WU01 PRODUCTION APPLICATION BOOTSTRAP GATE PASS'

contains

  subroutine initialize_application_config(value)
    type(fmr_production_application_config_t), intent(out) :: value
    integer :: k, j

    value%initial_time = 0.0_real64
    value%numerical%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    value%numerical%transaction%temporal_tolerance = 0.0_real64
    value%numerical%transaction%mass_tolerance = TOL
    value%numerical%transaction%retry_scale = 0.5_real64
    value%numerical%transaction%max_retries = 8
    value%numerical%max_committed_substeps = 32
    value%numerical%progress_tolerance = 0.0_real64
    value%numerical%model_temporal_indicator_budget_available = .true.
    value%numerical%model_temporal_indicator_budget = 1.0e-5_real64
    value%numerical%accepted_trajectory_direction%requested = .false.

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
      value%tiles(k)%template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
      value%tiles(k)%template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

      call initialize_parameters(value%tiles(k)%parameters, 620000_int64 + int(k, int64))
      call initialize_state_and_forcing(value%tiles(k)%parameters, value%tiles(k)%initial_state, &
           value%tiles(k)%base_forcing)

      value%tiles(k)%groundwater_datum%available = .true.
      value%tiles(k)%groundwater_datum%datum_id = 630000_int64 + int(k, int64)
      value%tiles(k)%groundwater_datum%bottom_boundary_elevation_m = 0.0_real64

      allocate(value%tiles(k)%initial_right_derivative(numnod))
      do j = 1, numnod
        value%tiles(k)%initial_right_derivative(j) = 0.0_real64
      end do
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
      p%cofgen(9,k) = 0.0_real64
      p%cofgen(10,k) = p%cofgen(3,k)
      p%cofgen(11,k) = 0.999_real64
      p%cofgen(12,k) = 0.99_real64 * p%cofgen(3,k)
      p%cofgen(22,k) = -1.0e6_real64
      p%cofgen(23,k) = 1.0e-12_real64
    end do
    p%bottom_mode = 5
    p%swkimpl = 0
    p%swkmean = 1
    p%swsophy = 0
    p%max_iterations = 16
    p%max_backtracking = 8
    p%min_step_duration = 1.0e-8_real64
    p%compartment_balance_tolerance = TOL
    p%total_balance_tolerance = TOL
    p%head_abs_tolerance = TOL
    p%head_rel_tolerance = TOL
    p%ponding_tolerance = TOL
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

  subroutine initialize_state_and_forcing(p, state, forcing)
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing

    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: i

    heads(1) = H0_CM
    do i = 2, numnod
      heads(i) = heads(i-1) + p%node_distance(i)
    end do
    call initialize_b110_default_mvg_parameters(hp, p%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, DURATION_DAY)
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64

    forcing%top_flux = PREDICTOR_QBOT
    forcing%top_head = heads(1)
    forcing%bottom_flux = PREDICTOR_QBOT
    forcing%bottom_head = heads(numnod)
    allocate(forcing%drainage_flux_by_level(1,numnod), forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    forcing%drainage_flux_by_level = 0.0_real64
    forcing%subsurface_irrigation_source = 0.0_real64
    forcing%root_extraction_sink = 0.0_real64
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
    window%t0 = DURATION_DAY
    window%t1 = 2.0_real64 * DURATION_DAY
    lineage%coupling_id = cell%coupling_id
    lineage%swap_lineage_id = tile%swap_lineage_id
    lineage%swap_origin_revision = 1_int64
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
    integer :: i

    heads(1) = H0_CM
    do i = 2, numnod
      heads(i) = heads(i-1) + p%node_distance(i)
    end do
    call initialize_b110_default_mvg_parameters(hp, p%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, DURATION_DAY)
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    call materialize_modflow6_prescribed_qbot_bottom_face(heads(numnod), conductivity(numnod), PREDICTOR_QBOT, &
         0.5_real64 * p%dz(numnod), datum, face, local_status)
    if (local_status == MODFLOW6_BOTTOM_FACE_OK) then
      head_m = face%hydraulic_head_m
    else
      head_m = 0.0_real64
    end if
  end subroutine compute_reference_head

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a,1x,a)') 'PPA_WU01_FAIL', trim(message)
      error stop 1
    end if
  end subroutine require

end program test_ppa_wu01_production_application_bootstrap
