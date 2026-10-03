module mod_strip01_c1_research_context
  use, intrinsic :: iso_c_binding, only: c_char, c_double, c_int, c_int64_t, c_null_char
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: TX_TEMPORAL_MODEL_CERTIFICATE, transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, kernel_candidate_state_t, kernel_diagnostics_t, kernel_reference_floor_result_t, kernel_reference_floor_candidate_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_b110_temporal_indicator_state_t, fmr_serialized_reference_backend_t, &
       fmr_serialized_physical_observation_t, fmr_new_b110_committed_state, fmr_new_b110_temporal_indicator_committed_state
  use mod_fmr_groundwater_head_forcing_adapter, only: fmr_groundwater_head_forcing_materializer_t
  use mod_fmr_groundwater_participant_registry, only: fmr_groundwater_participant_registry_t, FMR_GW_REGISTRY_OK
  use mod_fmr_groundwater_application_context, only: fmr_groundwater_application_context_t, FMR_GW_APP_CONTEXT_OK
  use mod_fmr_groundwater_application_c_api, only: register_fmr_groundwater_application_context, FMR_GW_APP_C_API_OK
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, &
       groundwater_interface_mass_snapshot_t, GW_MASS_LEDGER_OK
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t, groundwater_coupling_window_t
  use mod_groundwater_topology_composition, only: groundwater_topology_tile_t, groundwater_topology_cell_t, &
       groundwater_topology_t, materialize_groundwater_topology, GW_TOPOLOGY_OK, &
       GW_STORAGE_STATE_ROLE_HEAD_STATE_CAPACITANCE, GW_DRAINAGE_OWNER_MODFLOW
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

  integer, parameter :: NPART = 50
  integer :: id_index
  real(real64), parameter :: FRACTION(NPART) = 1.0_real64
  integer(int64), parameter :: TILE_ID(NPART) = [(610000_int64+int(id_index,int64),id_index=1,NPART)]
  integer(int64), parameter :: LEDGER_ID(NPART) = [(710000_int64+int(id_index,int64),id_index=1,NPART)]
  integer(int64), parameter :: CELL_ID(NPART) = [(7000_int64+int(id_index,int64),id_index=1,NPART)]
  integer(int64), parameter :: COUPLING_ID(NPART) = [(810000_int64+int(id_index,int64),id_index=1,NPART)]
  integer(int64), parameter :: GW_LINEAGE_ID(NPART) = [(910000_int64+int(id_index,int64),id_index=1,NPART)]
  integer(int64), parameter :: GW_SERVICE_ID = 9001_int64
  real(real64), parameter :: H0_CM = -95.0_real64
  real(real64), parameter :: DURATION_DAY = 0.001_real64
  real(real64), parameter :: TOL = 1.0e-12_real64
  real(real64), parameter :: PREDICTOR_QBOT = -0.001_real64
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
  public :: strip01_diagnose_telemetry_c
  public :: fgc49d_fixture_state_c, strip01_observe_c, strip01_diagnose_c, strip01_floor_c, strip01_ledger_counts_c, strip01_fields_c

contains

  integer(c_int) function fgc49d_fixture_initialize_c(context_handle, href1, href2) &
       bind(C, name="fgc49d_fixture_initialize_c") result(c_status)
    integer(c_int64_t), intent(out) :: context_handle
    real(c_double), intent(out) :: href1, href2

    type(groundwater_topology_tile_t) :: tiles(NPART)
    type(groundwater_topology_cell_t) :: cells(NPART)
    type(groundwater_tile_predictor_input_t) :: predictors(NPART)
    type(groundwater_cell_area_input_t) :: areas(NPART)
    type(groundwater_topology_t) :: topology
    type(groundwater_head_datum_t) :: datum
    integer(int64) :: handle
    logical :: ok
    integer :: i, status
    real(real64) :: cell_origin_head

    c_status = 1_c_int
    context_handle = 0_c_int64_t
    href1 = 0.0_c_double
    href2 = 0.0_c_double
    if (initialized) return

    call initialize_parameters(parameters)
    call initialize_forcing(base_forcing, 0.0_real64)
    call initialize_config(config)
    call backend%initialize(top)
    call materializer%initialize(base_forcing)

    datum%available = .true.
    datum%datum_id = 610049_int64
    datum%bottom_boundary_elevation_m = -2.0_real64
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

    do i = 1, NPART
      call set_tile(tiles(i), TILE_ID(i), TILE_ID(i), LEDGER_ID(i), CELL_ID(i), 1.0_real64)
      call set_cell(cells(i), CELL_ID(i), COUPLING_ID(i), GW_SERVICE_ID, GW_LINEAGE_ID(i), i, i)
      cell_origin_head = reference_head_m
      if (i == NPART) cell_origin_head = cell_origin_head + 0.5_real64
      call make_predictor(predictors(i), TILE_ID(i), TILE_ID(i), COUPLING_ID(i), GW_SERVICE_ID, GW_LINEAGE_ID(i), &
           cell_origin_head, cell_origin_head)
      areas(i)%groundwater_cell_id = CELL_ID(i)
      areas(i)%cell_area_m2 = 1.0_real64
    end do
    call materialize_groundwater_topology(tiles, cells, topology, status)
    if (status /= GW_TOPOLOGY_OK .or. .not. topology%ready()) return

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

  integer(c_int) function strip01_observe_c(storage, revisions) bind(C,name="strip01_observe_c") result(c_status)
    real(c_double), intent(out) :: storage(NPART)
    integer(c_int), intent(out) :: revisions(NPART)
    class(transaction_state_t), allocatable :: copy
    integer :: i
    logical :: ok
    c_status = 1
    do i = 1, NPART
      call committed(i)%snapshot(copy, ok)
      if (.not. ok) return
      select type (copy)
      class is (fmr_b110_physical_state_t)
        storage(i) = 0.01_real64 * (sum(copy%water_content * parameters%dz) + copy%ponding_depth)
      class default
        return
      end select
      revisions(i) = int(committed(i)%current_revision(), c_int)
    end do
    c_status = 0
  end function strip01_observe_c

  integer(c_int) function strip01_diagnose_c(slot, head, duration, tangent_on, codes, complete_t) &
       bind(C,name="strip01_diagnose_c") result(c_status)
    integer(c_int), value :: slot, tangent_on
    real(c_double), value :: head, duration
    integer(c_int), intent(out) :: codes(8)
    real(c_double), intent(out) :: complete_t
    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    type(canonical_numerical_config_t) :: numerical
    type(fmr_b110_physical_forcing_t) :: forcing
    logical :: ok
    c_status = 1
    if (slot < 1 .or. slot > NPART) return
    call committed(slot)%capture_checkpoint(checkpoint, ok)
    if (.not. ok) return
    forcing = base_forcing
    forcing%bottom_head = (head + 2.0_real64) * 100.0_real64
    numerical = config
    numerical%accepted_trajectory_direction%requested = tangent_on /= 0
    numerical%accepted_trajectory_direction%control_coordinate = 5
    call backend%run_trial(columns(slot), templates(slot), parameters, committed(slot), forcing, numerical, &
         0.0_real64, duration, checkpoint, result, candidate, diagnostics)
    codes = [result%status, diagnostics%accepted_substeps, diagnostics%solver_rejections, &
         diagnostics%temporal_rejections, diagnostics%mass_rejections, diagnostics%admission_rejections, &
         diagnostics%attempts, diagnostics%retries]
    complete_t = result%completed_t
    if (candidate%ready()) call backend%discard_trial_candidate(candidate, diagnostics)
    c_status = 0
  end function strip01_diagnose_c

  integer(c_int) function strip01_diagnose_telemetry_c(slot, head, duration, codes, telemetry_i, telemetry_r, &
       solver_route, temporal_route, certificate_reason) &
       bind(C,name="strip01_diagnose_telemetry_c") result(c_status)
    integer(c_int), value :: slot
    real(c_double), value :: head, duration
    integer(c_int), intent(out) :: codes(8), telemetry_i(14)
    real(c_double), intent(out) :: telemetry_r(5)
    character(kind=c_char), intent(out) :: solver_route(32), temporal_route(40), certificate_reason(48)
    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    type(canonical_numerical_config_t) :: numerical
    type(fmr_b110_physical_forcing_t) :: forcing
    type(fmr_serialized_physical_observation_t) :: observation
    logical :: ok
    integer :: i, ncopy
    c_status = 1
    if (slot < 1 .or. slot > NPART) return
    call committed(slot)%capture_checkpoint(checkpoint, ok)
    if (.not. ok) return
    forcing = base_forcing
    forcing%bottom_head = (head + 6.0_real64) * 100.0_real64
    numerical = config
    numerical%accepted_trajectory_direction%requested = .false.
    call backend%run_trial(columns(slot), templates(slot), parameters, committed(slot), forcing, numerical, &
         0.0_real64, duration, checkpoint, result, candidate, diagnostics)
    observation = backend%observation()
    codes = [result%status, diagnostics%accepted_substeps, diagnostics%solver_rejections, &
         diagnostics%temporal_rejections, diagnostics%mass_rejections, diagnostics%admission_rejections, &
         diagnostics%attempts, diagnostics%retries]
    telemetry_i = [merge(1,0,observation%solver_executed), observation%solver_status, &
         observation%solver_diagnostics%nonlinear_iterations, observation%solver_diagnostics%linear_solves, &
         merge(1,0,observation%solver_equation_residual_available), &
         merge(1,0,observation%temporal_indicator_enabled), merge(1,0,observation%temporal_previous_derivative_available), &
         merge(1,0,observation%temporal_current_derivative_available), observation%temporal_indicator_status, &
         merge(1,0,observation%temporal_indicator_available), merge(1,0,observation%temporal_head_budget_supplied), &
         merge(1,0,observation%temporal_head_budget_valid), merge(1,0,observation%temporal_certificate_available), &
         observation%temporal_additional_tridiagonal_solves]
    telemetry_r = [observation%solver_equation_residual, observation%temporal_head_inf_bound, &
         observation%temporal_head_budget, observation%temporal_normalized_indicator, real(result%completed_t,real64)]
    solver_route = c_null_char
    temporal_route = c_null_char
    certificate_reason = c_null_char
    ncopy = min(len_trim(observation%solver_diagnostics%route), size(solver_route))
    do i = 1, ncopy
      solver_route(i) = observation%solver_diagnostics%route(i:i)
    end do
    ncopy = min(len_trim(observation%temporal_indicator_route), size(temporal_route))
    do i = 1, ncopy
      temporal_route(i) = observation%temporal_indicator_route(i:i)
    end do
    ncopy = min(len_trim(observation%temporal_certificate_unavailable_reason), size(certificate_reason))
    do i = 1, ncopy
      certificate_reason(i) = observation%temporal_certificate_unavailable_reason(i:i)
    end do
    if (candidate%ready()) call backend%discard_trial_candidate(candidate, diagnostics)
    c_status = 0
  end function strip01_diagnose_telemetry_c

  integer(c_int) function strip01_floor_c(slot, head, duration, codes, values) &
       bind(C,name="strip01_floor_c") result(c_status)
    integer(c_int), value :: slot
    real(c_double), value :: head, duration
    integer(c_int), intent(out) :: codes(4)
    real(c_double), intent(out) :: values(4)
    type(kernel_reference_floor_result_t) :: result
    type(kernel_reference_floor_candidate_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    type(fmr_b110_physical_forcing_t) :: forcing
    type(fmr_b110_physical_state_t) :: plain
    type(kernel_committed_state_t) :: floor_committed
    type(fmr_template_t) :: floor_template
    class(transaction_state_t), allocatable :: snapshot
    logical :: ok
    c_status = 1
    if (slot < 1 .or. slot > NPART) return
    call committed(slot)%snapshot(snapshot, ok)
    if (.not. ok) return
    select type (snapshot)
    class is (fmr_b110_physical_state_t)
      plain%active_nodes = snapshot%active_nodes
      plain%pressure_head = snapshot%pressure_head
      plain%water_content = snapshot%water_content
      plain%ponding_depth = snapshot%ponding_depth
      plain%groundwater_level = snapshot%groundwater_level
    class default
      return
    end select
    call fmr_new_b110_committed_state(floor_committed, TILE_ID(slot), plain, 0.0_real64, ok)
    if (.not. ok) return
    floor_template = templates(slot)
    floor_template%numerical_continuation_layout_id = 0
    forcing = base_forcing
    forcing%bottom_head = (head + 2.0_real64) * 100.0_real64
    call backend%run_reference_floor_sample(columns(slot), floor_template, parameters, floor_committed, forcing, &
         0.0_real64, duration, TOL, result, candidate, diagnostics)
    codes = [result%status, merge(1,0,result%sample_valid), result%nonlinear_iterations, result%internal_retries]
    values = [result%accepted_dt, result%mass%residual, result%mass%storage_change, result%bottom_outward_exchange_native]
    if (candidate%ready()) call backend%discard_reference_floor_candidate(candidate, diagnostics)
    c_status = 0
  end function strip01_floor_c

  integer(c_int) function strip01_ledger_counts_c(counts) bind(C,name="strip01_ledger_counts_c") result(c_status)
    integer(c_int), intent(out) :: counts(NPART)
    type(groundwater_interface_mass_snapshot_t) :: snapshot
    integer :: i
    c_status = 1
    do i = 1, NPART
      call ledgers(i)%snapshot(snapshot)
      if (.not. snapshot%available) return
      counts(i) = int(snapshot%committed_exchange_count, c_int)
    end do
    c_status = 0
  end function strip01_ledger_counts_c

  integer(c_int) function strip01_fields_c(fields) bind(C,name="strip01_fields_c") result(c_status)
    real(c_double), intent(out) :: fields(3*numnod+3,NPART)
    class(transaction_state_t), allocatable :: snapshot
    real(real64), allocatable :: history(:)
    integer :: i
    logical :: ok
    c_status = 1
    do i = 1, NPART
      call committed(i)%snapshot(snapshot, ok)
      if (.not. ok) return
      select type (snapshot)
      type is (fmr_b110_temporal_indicator_state_t)
        call snapshot%temporal_history_snapshot(history, ok)
        if (.not. ok) return
        fields(1:numnod,i) = snapshot%pressure_head
        fields(numnod+1:2*numnod,i) = snapshot%water_content
        fields(2*numnod+1:3*numnod,i) = history
        fields(3*numnod+1,i) = snapshot%ponding_depth
        fields(3*numnod+2,i) = snapshot%groundwater_level
        call committed(i)%current_time(fields(3*numnod+3,i), ok)
        if (.not. ok) return
      class default
        return
      end select
    end do
    c_status = 0
  end function strip01_fields_c

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
    ! Unqualified numerical seed for a diagnostic service probe. This is not
    ! a measured physical predictor derivative; accepted-origin corrector flux
    ! remains mandatory. No E2E qualification may be claimed from this seed.
    call compose_modflow6_swap_predictor_response(window, lineage, PREDICTOR_QBOT, h0, h1, -100.0_real64, &
         MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT, coverage, 'heuristic-seed-hint', 'strip01-research-probe', input%response, status)
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
      p%cofgen(1,k) = 0.02_real64
      p%cofgen(2,k) = 0.42749391_real64
      p%cofgen(3,k) = 31.22501566_real64
      p%cofgen(4,k) = 0.02165898_real64
      p%cofgen(5,k) = 0.98087016_real64
      p%cofgen(6,k) = 1.73473668_real64
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
    value%transaction%max_retries = 0
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
    if (lineage_id == TILE_ID(NPART)) heads(1) = H0_CM + 50.0_real64
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
    physical%groundwater_level = heads(1) + p%z(1)
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
    call materialize_modflow6_prescribed_qbot_bottom_face(heads(numnod), conductivity(numnod), 0.0_real64, &
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
    cell%drainage_owner = GW_DRAINAGE_OWNER_MODFLOW
  end subroutine set_cell

end module mod_strip01_c1_research_context
