module mod_fgc49d_application_context_fixture
  use, intrinsic :: iso_c_binding, only: c_double, c_int, c_int64_t
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_temporal_indicator_committed_state
  use mod_fmr_groundwater_head_forcing_adapter, only: fmr_groundwater_head_forcing_materializer_t
  use mod_fmr_groundwater_participant_registry, only: fmr_groundwater_participant_registry_t, FMR_GW_REGISTRY_OK
  use mod_fmr_groundwater_application_context, only: fmr_groundwater_application_context_t, FMR_GW_APP_CONTEXT_OK
  use mod_fmr_groundwater_application_c_api, only: register_fmr_groundwater_application_context, FMR_GW_APP_C_API_OK
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, &
       groundwater_interface_mass_snapshot_t, GW_MASS_LEDGER_OK
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t, groundwater_coupling_window_t
  use mod_groundwater_topology_composition, only: groundwater_topology_tile_t, groundwater_topology_cell_t, &
       groundwater_topology_t, materialize_groundwater_topology, GW_TOPOLOGY_OK, &
       GW_STORAGE_STATE_ROLE_HEAD_STATE_CAPACITANCE, GW_DRAINAGE_OWNER_NONE
  use mod_groundwater_application_plan, only: groundwater_tile_predictor_input_t, groundwater_cell_area_input_t, &
       groundwater_application_plan_t, materialize_groundwater_application_plan, GW_APP_PLAN_OK
  use mod_modflow6_swap_predictor_response, only: modflow6_swap_predictor_lineage_t, &
       modflow6_derivative_coverage_t, compose_modflow6_swap_predictor_response, MODFLOW6_PREDICTOR_OK, &
       MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT
  use mod_modflow6_swap_prescribed_qbot_bottom_face, only: modflow6_prescribed_qbot_bottom_face_t, &
       materialize_modflow6_prescribed_qbot_bottom_face, MODFLOW6_BOTTOM_FACE_OK
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none
  private

  integer, parameter :: NPART = 3
  real(real64), parameter :: FRACTION(NPART) = [0.35_real64, 0.65_real64, 1.0_real64]
  integer(int64), parameter :: TILE_ID(NPART) = [610049_int64, 610050_int64, 610051_int64]
  integer(int64), parameter :: LEDGER_ID(NPART) = [710049_int64, 710050_int64, 710051_int64]
  integer(int64), parameter :: CELL_ID(NPART) = [7001_int64, 7001_int64, 7002_int64]
  integer(int64), parameter :: COUPLING_ID(2) = [810049_int64, 810050_int64]
  integer(int64), parameter :: GW_LINEAGE_ID(2) = [910049_int64, 910050_int64]
  integer(int64), parameter :: GW_SERVICE_ID = 9001_int64
  real(real64), parameter :: H0_CM = -75.0_real64
  real(real64), parameter :: DURATION_DAY = 1.0e-4_real64
  real(real64), parameter :: TOL = 1.0e-12_real64
  real(real64), parameter :: PREDICTOR_QBOT = 1.0e-6_real64
  real(real64), parameter :: HEAD_BUDGET = 1.0e-5_real64

  type(fmr_b110_physical_parameters_t), target, save :: parameters
  type(fmr_b110_physical_forcing_t), save :: base_forcing
  type(fmr_logical_column_t), save :: columns(NPART)
  type(fmr_template_t), save :: templates(NPART)
  type(canonical_numerical_config_t), save :: config
  type(kernel_committed_state_t), target, save :: committed(NPART)
  type(fmr_serialized_reference_backend_t), target, save :: backend
  type(fmr_groundwater_head_forcing_materializer_t), target, save :: materializer
  type(fmr_groundwater_participant_registry_t), target, save :: registry
  type(groundwater_interface_mass_ledger_t), target, save :: ledgers(NPART)
  type(groundwater_application_plan_t), target, save :: plan
  type(fmr_groundwater_application_context_t), target, save :: context
  type(fixed_flux_top_boundary_provider_t), target, save :: top
  integer(int64), save :: handles(NPART) = 0_int64
  real(real64), save :: reference_head_m = 0.0_real64
  logical, save :: initialized = .false.

  public :: fgc49d_fixture_initialize_c
  public :: fgc49d_fixture_state_c

contains

  integer(c_int) function fgc49d_fixture_initialize_c(context_handle, href1, href2) &
       bind(C, name="fgc49d_fixture_initialize_c") result(c_status)
    integer(c_int64_t), intent(out) :: context_handle
    real(c_double), intent(out) :: href1, href2

    type(groundwater_topology_tile_t) :: tiles(NPART)
    type(groundwater_topology_cell_t) :: cells(2)
    type(groundwater_tile_predictor_input_t) :: predictors(NPART)
    type(groundwater_cell_area_input_t) :: areas(2)
    type(groundwater_topology_t) :: topology
    type(groundwater_head_datum_t) :: datum
    integer(int64) :: handle
    logical :: ok
    integer :: i, status

    c_status = 1_c_int
    context_handle = 0_c_int64_t
    href1 = 0.0_c_double
    href2 = 0.0_c_double
    if (initialized) return

    call initialize_parameters(parameters)
    call initialize_forcing(base_forcing, PREDICTOR_QBOT)
    call initialize_config(config)
    call backend%initialize(top)
    call materializer%initialize(base_forcing)

    datum%available = .true.
    datum%datum_id = 610049_int64
    datum%bottom_boundary_elevation_m = 0.0_real64
    call compute_origin_head(parameters, datum, reference_head_m, status)
    if (status /= MODFLOW6_BOTTOM_FACE_OK) return

    call registry%initialize(NPART, status)
    if (status /= FMR_GW_REGISTRY_OK) return

    do i = 1, NPART
      call initialize_column_template(columns(i), templates(i), TILE_ID(i), i)
      call initialize_committed(committed(i), parameters, TILE_ID(i), ok)
      if (.not. ok) return
      call registry%bind(TILE_ID(i), backend, columns(i), templates(i), parameters, committed(i), materializer, &
           config, datum, handles(i), status)
      if (status /= FMR_GW_REGISTRY_OK .or. handles(i) <= 0_int64) return
      call ledgers(i)%bind_identity(LEDGER_ID(i), status)
      if (status /= GW_MASS_LEDGER_OK) return
    end do

    call set_tile(tiles(1), TILE_ID(1), TILE_ID(1), LEDGER_ID(1), CELL_ID(1), FRACTION(1))
    call set_tile(tiles(2), TILE_ID(2), TILE_ID(2), LEDGER_ID(2), CELL_ID(2), FRACTION(2))
    call set_tile(tiles(3), TILE_ID(3), TILE_ID(3), LEDGER_ID(3), CELL_ID(3), FRACTION(3))
    call set_cell(cells(1), 7001_int64, COUPLING_ID(1), GW_SERVICE_ID, GW_LINEAGE_ID(1), 1, 2)
    call set_cell(cells(2), 7002_int64, COUPLING_ID(2), GW_SERVICE_ID, GW_LINEAGE_ID(2), 2, 3)
    call materialize_groundwater_topology(tiles, cells, topology, status)
    if (status /= GW_TOPOLOGY_OK .or. .not. topology%ready()) return

    call make_predictor(predictors(1), TILE_ID(1), TILE_ID(1), COUPLING_ID(1), GW_SERVICE_ID, GW_LINEAGE_ID(1), &
         reference_head_m, reference_head_m + 0.001_real64)
    call make_predictor(predictors(2), TILE_ID(2), TILE_ID(2), COUPLING_ID(1), GW_SERVICE_ID, GW_LINEAGE_ID(1), &
         reference_head_m, reference_head_m + 0.0015_real64)
    call make_predictor(predictors(3), TILE_ID(3), TILE_ID(3), COUPLING_ID(2), GW_SERVICE_ID, GW_LINEAGE_ID(2), &
         reference_head_m, reference_head_m - 0.001_real64)
    areas(1)%groundwater_cell_id = 7001_int64
    areas(1)%cell_area_m2 = 1.0_real64
    areas(2)%groundwater_cell_id = 7002_int64
    areas(2)%cell_area_m2 = 1.0_real64

    call materialize_groundwater_application_plan(topology, predictors, areas, plan, status)
    if (status /= GW_APP_PLAN_OK .or. .not. plan%ready()) return

    call context%bind(plan, registry, handles, ledgers, status)
    if (status /= FMR_GW_APP_CONTEXT_OK .or. .not. context%ready()) return
    call register_fmr_groundwater_application_context(context, handle, status)
    if (status /= FMR_GW_APP_C_API_OK .or. handle <= 0_int64) return

    context_handle = int(handle, c_int64_t)
    href1 = real(reference_head_m, c_double)
    href2 = real(reference_head_m, c_double)
    initialized = .true.
    c_status = 0_c_int
  end function fgc49d_fixture_initialize_c

  integer(c_int) function fgc49d_fixture_state_c(r1, r2, r3, c1, c2, c3) &
       bind(C, name="fgc49d_fixture_state_c") result(c_status)
    integer(c_int), intent(out) :: r1, r2, r3, c1, c2, c3

    type(groundwater_interface_mass_snapshot_t) :: snapshot(NPART)
    integer :: i

    c_status = 1_c_int
    r1 = -1_c_int
    r2 = -1_c_int
    r3 = -1_c_int
    c1 = -1_c_int
    c2 = -1_c_int
    c3 = -1_c_int
    if (.not. initialized) return

    do i = 1, NPART
      call ledgers(i)%snapshot(snapshot(i))
      if (.not. snapshot(i)%available) return
    end do

    r1 = int(committed(1)%current_revision(), c_int)
    r2 = int(committed(2)%current_revision(), c_int)
    r3 = int(committed(3)%current_revision(), c_int)
    c1 = int(snapshot(1)%committed_exchange_count, c_int)
    c2 = int(snapshot(2)%committed_exchange_count, c_int)
    c3 = int(snapshot(3)%committed_exchange_count, c_int)
    c_status = 0_c_int
  end function fgc49d_fixture_state_c

  subroutine make_predictor(input, tile_id, swap_lineage, coupling_id, service_id, gw_lineage, h0, h1)
    type(groundwater_tile_predictor_input_t), intent(out) :: input
    integer(int64), intent(in) :: tile_id, swap_lineage, coupling_id, service_id, gw_lineage
    real(real64), intent(in) :: h0, h1

    type(modflow6_swap_predictor_lineage_t) :: lineage
    type(modflow6_derivative_coverage_t) :: coverage
    type(groundwater_coupling_window_t) :: window
    integer :: status

    input%tile_id = tile_id
    window%t0 = 0.0_real64
    window%t1 = DURATION_DAY
    lineage%coupling_id = coupling_id
    lineage%swap_lineage_id = swap_lineage
    lineage%swap_origin_revision = 0_int64
    lineage%groundwater_service_id = service_id
    lineage%groundwater_lineage_id = gw_lineage
    lineage%groundwater_origin_revision = 0_int64
    coverage%lower_face_head_semantics_covered = .true.
    coverage%richards_hydraulic_response_covered = .true.
    coverage%constitutive_response_covered = .true.
    call compose_modflow6_swap_predictor_response(window, lineage, 0.001_real64, h0, h1, 0.25_real64, &
         MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT, coverage, 'fgc49d', 'production-abi-fixture', input%response, status)
    if (status /= MODFLOW6_PREDICTOR_OK .or. .not. input%response%valid) error stop 'F-GC49D fixture predictor'
  end subroutine make_predictor

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer :: k

    p%parameter_set_id = 610049_int64
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

  subroutine initialize_forcing(f, q)
    type(fmr_b110_physical_forcing_t), intent(out) :: f
    real(real64), intent(in) :: q

    f%top_flux = q
    f%top_head = H0_CM
    f%bottom_flux = q
    f%bottom_head = H0_CM
    allocate(f%drainage_flux_by_level(1,numnod), f%subsurface_irrigation_source(numnod), f%root_extraction_sink(numnod))
    f%drainage_flux_by_level = 0.0_real64
    f%subsurface_irrigation_source = 0.0_real64
    f%root_extraction_sink = 0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_column_template(column, template, id, slot)
    type(fmr_logical_column_t), intent(out) :: column
    type(fmr_template_t), intent(out) :: template
    integer(int64), intent(in) :: id
    integer, intent(in) :: slot

    template%template_id = 610000_int64 + int(slot, int64)
    template%physics_topology_id = 610010_int64
    template%vertical_layout_id = 610020_int64
    template%state_layout_id = 610030_int64
    template%solver_interface_id = 610040_int64
    template%optional_state_layout_id = 0_int64
    template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    column%column_id = id
    column%template_id = template%template_id
    column%parameter_ref = 1_int64
    column%state_handle = int(slot, int64)
    column%forcing_handle = 1_int64
    column%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_template

  subroutine initialize_config(value)
    type(canonical_numerical_config_t), intent(out) :: value

    value%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    value%transaction%temporal_tolerance = 0.0_real64
    value%transaction%mass_tolerance = TOL
    value%transaction%retry_scale = 0.5_real64
    value%transaction%max_retries = 8
    value%max_committed_substeps = 32
    value%progress_tolerance = 0.0_real64
    value%model_temporal_indicator_budget_available = .true.
    value%model_temporal_indicator_budget = HEAD_BUDGET
    value%accepted_trajectory_direction%requested = .false.
  end subroutine initialize_config

  subroutine initialize_committed(state, p, lineage_id, ok)
    type(kernel_committed_state_t), intent(out) :: state
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    integer(int64), intent(in) :: lineage_id
    logical, intent(out) :: ok

    type(fmr_b110_physical_state_t) :: physical
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    real(real64) :: accepted_predecessor_right_derivative(numnod)
    integer :: i

    heads(1) = H0_CM
    do i = 2, numnod
      heads(i) = heads(i-1) + p%node_distance(i)
    end do
    call initialize_b110_default_mvg_parameters(hp, p%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, DURATION_DAY)
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    physical%active_nodes = numnod
    allocate(physical%pressure_head(numnod), physical%water_content(numnod))
    physical%pressure_head = heads
    physical%water_content = water
    physical%ponding_depth = 0.0_real64
    physical%groundwater_level = -2.0_real64
    accepted_predecessor_right_derivative = 0.0_real64
    call fmr_new_b110_temporal_indicator_committed_state(state, lineage_id, physical, 0.0_real64, ok, &
         accepted_predecessor_right_derivative)
  end subroutine initialize_committed

  subroutine compute_origin_head(p, datum, head_m, status)
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    type(groundwater_head_datum_t), intent(in) :: datum
    real(real64), intent(out) :: head_m
    integer, intent(out) :: status

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
         0.5_real64 * p%dz(numnod), datum, face, status)
    if (status == MODFLOW6_BOTTOM_FACE_OK) then
      head_m = face%hydraulic_head_m
    else
      head_m = 0.0_real64
    end if
  end subroutine compute_origin_head

  subroutine set_tile(tile, tile_id, lineage_id, ledger_id, cell_id, fraction)
    type(groundwater_topology_tile_t), intent(out) :: tile
    integer(int64), intent(in) :: tile_id, lineage_id, ledger_id, cell_id
    real(real64), intent(in) :: fraction

    tile%tile_id = tile_id
    tile%swap_lineage_id = lineage_id
    tile%ledger_id = ledger_id
    tile%groundwater_cell_id = cell_id
    tile%area_fraction = fraction
  end subroutine set_tile

  subroutine set_cell(cell, cell_id, coupling_id, service_id, lineage_id, slot, node)
    type(groundwater_topology_cell_t), intent(out) :: cell
    integer(int64), intent(in) :: cell_id, coupling_id, service_id, lineage_id
    integer, intent(in) :: slot, node

    cell%groundwater_cell_id = cell_id
    cell%coupling_id = coupling_id
    cell%groundwater_service_id = service_id
    cell%groundwater_lineage_id = lineage_id
    cell%package_slot = slot
    cell%modflow_node_id = node
    cell%storage_state_role = GW_STORAGE_STATE_ROLE_HEAD_STATE_CAPACITANCE
    cell%drainage_owner = GW_DRAINAGE_OWNER_NONE
  end subroutine set_cell

end module mod_fgc49d_application_context_fixture
