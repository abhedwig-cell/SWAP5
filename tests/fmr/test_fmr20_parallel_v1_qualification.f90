program test_fmr20_parallel_v1_qualification
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t, canonical_mass_accounting_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, fmr_serialized_batch_diagnostics_t, &
       fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK
  use mod_fmr_parallel_worker_pool, only: fmr_run_parallel_physical_multiswap, FMR_PARALLEL_POOL_OK, &
       FMR_PARALLEL_POOL_MULTIWORKER_NOT_ADMITTED
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  integer, parameter :: ncol = 32
  integer, parameter :: batch_size = 9
  integer, parameter :: perturb_index = 7
  real(real64), parameter :: t0 = 2000.125_real64
  real(real64), parameter :: t1 = 2000.625_real64
  real(real64), parameter :: head0 = -75.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64

  type(fmr_logical_column_t) :: columns(ncol), reversed(ncol)
  type(fmr_template_t) :: templates(1)
  type(fmr_b110_physical_parameters_t) :: parameters(1), parameters_reference(1), parameters_bad(1)
  type(fmr_b110_physical_forcing_t) :: forcings(ncol), forcings_perturbed(ncol)
  type(kernel_committed_state_t) :: states_serial(ncol), states_2a(ncol), states_4(ncol), states_2b(ncol)
  type(kernel_committed_state_t) :: states_rev4(ncol), states_perturbed(ncol), states_reject(ncol), states_reject_reference(ncol)
  type(fmr_serialized_column_result_t), allocatable :: results_serial(:), results_2a(:), results_4(:), results_2b(:)
  type(fmr_serialized_column_result_t), allocatable :: results_rev4(:), results_perturbed(:), results_reject(:)
  type(fmr_column_diagnostics_t), allocatable :: diag_serial(:), diag_2a(:), diag_4(:), diag_2b(:)
  type(fmr_column_diagnostics_t), allocatable :: diag_rev4(:), diag_perturbed(:), diag_reject(:)
  type(fmr_aggregate_diagnostics_t) :: agg_serial, agg_2a, agg_4, agg_2b, agg_rev4, agg_perturbed, agg_reject
  type(fmr_serialized_batch_diagnostics_t) :: runtime_serial, runtime_2a, runtime_4, runtime_2b
  type(fmr_serialized_batch_diagnostics_t) :: runtime_rev4, runtime_perturbed, runtime_reject
  type(fmr_b110_physical_state_t) :: initial_state
  type(fixed_flux_top_boundary_provider_t), target :: top_provider
  type(canonical_numerical_config_t) :: config
  real(real64) :: conductivity0
  integer :: direct_status, serialized_status, pool_status, i

  call configure_template(templates(1))
  call configure_parameters(parameters(1), initial_state, conductivity0)
  parameters_reference = parameters
  call configure_transaction(config)

  do i = 1, ncol
    columns(i)%column_id = 920000_int64 + int(i,int64)
    columns(i)%template_id = templates(1)%template_id
    columns(i)%parameter_ref = 1_int64
    columns(i)%state_handle = int(i,int64)
    columns(i)%forcing_handle = int(i,int64)
    columns(i)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    call configure_forcing(forcings(i), conductivity0, 1.0_real64 + 0.01_real64*real(i,real64))
  end do
  reversed = columns(ncol:1:-1)
  forcings_perturbed = forcings
  forcings_perturbed(perturb_index)%top_flux = 0.95_real64 * forcings(perturb_index)%top_flux

  call initialize_states(states_serial, columns, initial_state)
  call initialize_states(states_2a, columns, initial_state)
  call initialize_states(states_4, columns, initial_state)
  call initialize_states(states_2b, columns, initial_state)
  call initialize_states(states_rev4, columns, initial_state)
  call initialize_states(states_perturbed, columns, initial_state)
  call initialize_states(states_reject, columns, initial_state)
  call initialize_states(states_reject_reference, columns, initial_state)

  call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, states_serial, config, &
       top_provider, t0, t1, batch_size, results_serial, diag_serial, agg_serial, direct_status, runtime_serial)
  call require(direct_status == FMR_SERIAL_DISPATCH_OK, 'serialized reference dispatch')
  call require(all_committed(results_serial), 'serialized reference all committed')
  call require(max_abs_residual(results_serial) <= hard_mass_gate, 'serialized reference hard mass gate')
  write(*,'(A)') 'FMR20_V1_SERIAL_REFERENCE=PASS'

  call fmr_run_parallel_physical_multiswap(columns, templates, parameters, forcings, states_2a, config, &
       top_provider, t0, t1, batch_size, 2, results_2a, diag_2a, agg_2a, serialized_status, pool_status, runtime_2a)
  call require(pool_status == FMR_PARALLEL_POOL_OK .and. serialized_status == FMR_SERIAL_DISPATCH_OK, '2-worker status')
  call require(all_committed(results_2a), '2-worker all committed')
  call require(max_abs_residual(results_2a) <= hard_mass_gate, '2-worker hard mass gate')
  call require(runtime_2a%max_simultaneous_real_physical_solves >= 2, '2-worker real solve overlap')
  call require(runtime_2a%max_simultaneous_real_physical_solves <= 2, '2-worker overlap bound')
  call require(worker_assignment_formula_ok(results_2a, diag_2a, 2), '2-worker assignment formula')
  write(*,'(A)') 'FMR20_V1_REAL_OVERLAP_2_WORKERS=PASS'

  call fmr_run_parallel_physical_multiswap(columns, templates, parameters, forcings, states_4, config, &
       top_provider, t0, t1, batch_size, 4, results_4, diag_4, agg_4, serialized_status, pool_status, runtime_4)
  call require(pool_status == FMR_PARALLEL_POOL_OK .and. serialized_status == FMR_SERIAL_DISPATCH_OK, '4-worker status')
  call require(all_committed(results_4), '4-worker all committed')
  call require(max_abs_residual(results_4) <= hard_mass_gate, '4-worker hard mass gate')
  call require(runtime_4%max_simultaneous_real_physical_solves >= 2, '4-worker real solve overlap')
  call require(runtime_4%max_simultaneous_real_physical_solves <= 4, '4-worker overlap bound')
  call require(worker_assignment_formula_ok(results_4, diag_4, 4), '4-worker assignment formula')
  write(*,'(A)') 'FMR20_V1_REAL_OVERLAP_4_WORKERS=PASS'

  call require(result_sets_by_id_identical(results_serial, results_2a), 'serialized vs 2-worker result identity')
  call require(diagnostics_by_id_semantically_identical(diag_serial, diag_2a), 'serialized vs 2-worker diagnostic identity')
  call require(state_sets_identical(states_serial, states_2a), 'serialized vs 2-worker state identity')
  call require(aggregate_semantically_identical(agg_serial, agg_2a), 'serialized vs 2-worker aggregate identity')
  call require(runtime_semantically_identical(runtime_serial, runtime_2a), 'serialized vs 2-worker runtime identity')
  write(*,'(A)') 'FMR20_V1_SERIAL_VS_2_WORKER_IDENTITY=PASS'

  call require(result_sets_by_id_identical(results_serial, results_4), 'serialized vs 4-worker result identity')
  call require(diagnostics_by_id_semantically_identical(diag_serial, diag_4), 'serialized vs 4-worker diagnostic identity')
  call require(state_sets_identical(states_serial, states_4), 'serialized vs 4-worker state identity')
  call require(aggregate_semantically_identical(agg_serial, agg_4), 'serialized vs 4-worker aggregate identity')
  call require(runtime_semantically_identical(runtime_serial, runtime_4), 'serialized vs 4-worker runtime identity')
  write(*,'(A)') 'FMR20_V1_SERIAL_VS_4_WORKER_IDENTITY=PASS'

  call require(result_sets_by_id_identical(results_2a, results_4), '2-vs-4 result identity')
  call require(diagnostics_by_id_semantically_identical(diag_2a, diag_4), '2-vs-4 diagnostic identity')
  call require(state_sets_identical(states_2a, states_4), '2-vs-4 state identity')
  call require(aggregate_semantically_identical(agg_2a, agg_4), '2-vs-4 aggregate identity')
  call require(runtime_semantically_identical(runtime_2a, runtime_4), '2-vs-4 runtime identity')
  write(*,'(A)') 'FMR20_V1_WORKER_COUNT_INDEPENDENCE=PASS'

  call fmr_run_parallel_physical_multiswap(columns, templates, parameters, forcings, states_2b, config, &
       top_provider, t0, t1, batch_size, 2, results_2b, diag_2b, agg_2b, serialized_status, pool_status, runtime_2b)
  call require(pool_status == FMR_PARALLEL_POOL_OK, '2-worker repeat status')
  call require(result_sets_by_id_identical(results_2a, results_2b), 'A-B-A result repeatability')
  call require(diagnostics_by_id_fully_identical(diag_2a, diag_2b), 'A-B-A full diagnostic repeatability')
  call require(state_sets_identical(states_2a, states_2b), 'A-B-A state repeatability')
  call require(aggregate_fully_identical(agg_2a, agg_2b), 'A-B-A aggregate repeatability')
  call require(runtime_semantically_identical(runtime_2a, runtime_2b), 'A-B-A runtime repeatability')
  write(*,'(A)') 'FMR20_V1_A_B_A_REPEATABILITY=PASS'

  call fmr_run_parallel_physical_multiswap(reversed, templates, parameters, forcings, states_rev4, config, &
       top_provider, t0, t1, batch_size, 4, results_rev4, diag_rev4, agg_rev4, serialized_status, pool_status, runtime_rev4)
  call require(pool_status == FMR_PARALLEL_POOL_OK, 'reversed 4-worker status')
  call require(result_sets_by_id_identical(results_4, results_rev4), 'input-order result identity')
  call require(diagnostics_by_id_fully_identical(diag_4, diag_rev4), 'input-order full diagnostic identity')
  call require(state_sets_identical(states_4, states_rev4), 'input-order state identity')
  call require(aggregate_fully_identical(agg_4, agg_rev4), 'input-order aggregate identity')
  call require(runtime_semantically_identical(runtime_4, runtime_rev4), 'input-order runtime identity')
  write(*,'(A)') 'FMR20_V1_INPUT_ORDER_INDEPENDENCE=PASS'

  call fmr_run_parallel_physical_multiswap(columns, templates, parameters, forcings_perturbed, states_perturbed, config, &
       top_provider, t0, t1, batch_size, 4, results_perturbed, diag_perturbed, agg_perturbed, serialized_status, pool_status, &
       runtime_perturbed)
  call require(pool_status == FMR_PARALLEL_POOL_OK, 'perturbed 4-worker status')
  call require(runtime_perturbed%number_committed == ncol-1 .and. runtime_perturbed%number_rejected == 1, &
       'perturbed local rejection cardinality')
  call require(max_abs_residual(results_perturbed) <= hard_mass_gate, 'perturbed committed-column hard mass gate')
  do i = 1, ncol
    if (i == perturb_index) cycle
    call require(results_perturbed(i)%committed, 'perturbed unaffected column committed')
    call require(column_result_identical(results_4(i), results_perturbed(i)), 'cross-column result isolation')
    call require(committed_state_identical(states_4(i), states_perturbed(i)), 'cross-column state isolation')
  end do
  call require(.not. results_perturbed(perturb_index)%committed, 'perturbed target locally rejected')
  call require(committed_state_identical(states_perturbed(perturb_index), states_reject_reference(perturb_index)), &
       'perturbed target rollback nonmutation')
  call require(.not. column_result_identical(results_4(perturb_index), results_perturbed(perturb_index)), &
       'perturbed target rejection observable')
  write(*,'(A)') 'FMR20_V1_CROSS_COLUMN_REJECTION_ISOLATION=PASS'

  parameters_bad = parameters
  parameters_bad(1)%bottom_mode = 5
  call fmr_run_parallel_physical_multiswap(columns, templates, parameters_bad, forcings, states_reject, config, &
       top_provider, t0, t1, batch_size, 2, results_reject, diag_reject, agg_reject, serialized_status, pool_status, &
       runtime_reject)
  call require(pool_status == FMR_PARALLEL_POOL_MULTIWORKER_NOT_ADMITTED, 'negative profile rejected')
  call require(serialized_status == -1, 'negative profile no serialized dispatch')
  call require(runtime_reject%physical_solve_count == 0 .and. runtime_reject%number_committed == 0, &
       'negative profile zero physics and commits')
  call require(state_sets_identical(states_reject, states_reject_reference), 'negative profile state nonmutation')
  call require(all_no_solver_execution(results_reject), 'negative profile no solver execution')
  write(*,'(A)') 'FMR20_V1_NEGATIVE_PROFILE_FAIL_CLOSED=PASS'

  call require(parameter_sets_identical(parameters, parameters_reference), 'shared immutable parameter integrity')
  call require(agg_2a%workers == 2 .and. size(agg_2a%work_distribution) == 2, '2-worker aggregate worker topology')
  call require(agg_4%workers == 4 .and. size(agg_4%work_distribution) == 4, '4-worker aggregate worker topology')
  call require(sum(agg_2a%work_distribution) == int(agg_2a%attempts,int64), '2-worker work distribution conservation')
  call require(sum(agg_4%work_distribution) == int(agg_4%attempts,int64), '4-worker work distribution conservation')
  write(*,'(A)') 'FMR20_V1_SHARED_PARAMETER_INTEGRITY=PASS'
  write(*,'(A)') 'FMR20_PARALLEL_V1_QUALIFICATION_TEST PASS'

contains

  subroutine configure_template(template)
    type(fmr_template_t), intent(out) :: template
    template%template_id = 9200_int64
    template%physics_topology_id = 920001_int64
    template%vertical_layout_id = 920002_int64
    template%state_layout_id = 920003_int64
    template%solver_interface_id = 920004_int64
    template%optional_state_layout_id = 0_int64
    template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_template

  subroutine configure_parameters(value, state, conductivity0)
    type(fmr_b110_physical_parameters_t), intent(out) :: value
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: conductivity0
    type(b110_default_mvg_parameters_t), target :: hyd_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: j

    value%parameter_set_id = 920001_int64
    value%active_nodes = numnod
    allocate(value%z(numnod), value%dz(numnod), value%node_distance(numnod), value%cofgen(24,numnod))
    value%z = z
    value%dz = dz
    value%node_distance = disnod(1:numnod)
    value%cofgen = 0.0_real64
    do j = 1, numnod
      value%cofgen(1,j) = 0.032_real64
      value%cofgen(2,j) = 0.423_real64
      value%cofgen(3,j) = 4.75_real64
      value%cofgen(4,j) = 0.0135_real64
      value%cofgen(5,j) = 0.365_real64
      value%cofgen(6,j) = 1.455_real64
      value%cofgen(7,j) = 1.0_real64 - 1.0_real64/value%cofgen(6,j)
      value%cofgen(8,j) = value%cofgen(4,j)
      value%cofgen(10,j) = value%cofgen(3,j)
      value%cofgen(11,j) = 0.999_real64
      value%cofgen(12,j) = 0.99_real64*value%cofgen(3,j)
      value%cofgen(22,j) = -1.0e6_real64
      value%cofgen(23,j) = 1.0e-12_real64
    end do
    value%bottom_mode = 7
    value%swkimpl = 0
    value%swkmean = 1
    value%swsophy = 0
    value%root_extraction_active = .false.
    value%macropore_active = .false.
    value%snow_active = .false.
    value%hysteresis_active = .false.
    value%tabulated_hydraulics_active = .false.
    value%elasticity_active = .false.
    value%frost_active = .false.

    call initialize_b110_default_mvg_parameters(hyd_parameters, value%cofgen)
    call bind_b110_default_mvg_provider(constitutive, hyd_parameters, t1-t0)
    heads = head0
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
    call require(all(conductivity == conductivity(1)), 'uniform conductivity fixture')
    conductivity0 = conductivity(1)
    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
  end subroutine configure_parameters

  subroutine configure_forcing(forcing, conductivity0, scale)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(in) :: conductivity0, scale
    integer :: j
    forcing%top_flux = -conductivity0
    forcing%top_head = head0
    forcing%bottom_flux = -conductivity0
    forcing%bottom_head = -100.0_real64
    allocate(forcing%drainage_flux_by_level(2,numnod), forcing%subsurface_irrigation_source(numnod), &
             forcing%root_extraction_sink(numnod))
    do j = 1, numnod
      forcing%drainage_flux_by_level(1,j) = scale*1.0e-5_real64*real(j,real64)
      forcing%drainage_flux_by_level(2,j) = -scale*2.0e-6_real64*real(j+1,real64)
      forcing%subsurface_irrigation_source(j) = forcing%drainage_flux_by_level(1,j) + &
           forcing%drainage_flux_by_level(2,j)
      forcing%root_extraction_sink(j) = 0.0_real64
    end do
  end subroutine configure_forcing

  subroutine configure_transaction(value)
    type(canonical_numerical_config_t), intent(out) :: value
    value%transaction%temporal_tolerance = 0.0_real64
    value%transaction%mass_tolerance = hard_mass_gate
    value%transaction%retry_scale = 0.5_real64
    value%transaction%max_retries = 2
    value%max_committed_substeps = 8
    value%progress_tolerance = 0.0_real64
  end subroutine configure_transaction

  subroutine initialize_states(states, column_registry, seed)
    type(kernel_committed_state_t), intent(out) :: states(:)
    type(fmr_logical_column_t), intent(in) :: column_registry(:)
    type(fmr_b110_physical_state_t), intent(in) :: seed
    type(fmr_b110_physical_state_t) :: state
    logical :: ok
    integer :: j
    call require(size(states) == size(column_registry), 'state registry shape')
    do j = 1, size(states)
      state = seed
      state%groundwater_level = -2.0_real64 - 0.01_real64*real(j,real64)
      call fmr_new_b110_committed_state(states(j), column_registry(j)%column_id, state, t0, ok)
      call require(ok, 'committed state initialization')
    end do
  end subroutine initialize_states

  logical function all_committed(results) result(ok_all)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    integer :: j
    ok_all = .true.
    do j = 1, size(results)
      if (.not. results(j)%completed .or. .not. results(j)%committed .or. .not. results(j)%mass%complete) then
        ok_all = .false.
        return
      end if
    end do
  end function all_committed

  logical function all_no_solver_execution(results) result(ok_all)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    integer :: j
    ok_all = .true.
    do j = 1, size(results)
      if (results(j)%solver_executed .or. results(j)%committed) then
        ok_all = .false.
        return
      end if
    end do
  end function all_no_solver_execution

  real(real64) function max_abs_residual(results) result(value)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    integer :: j
    value = 0.0_real64
    do j = 1, size(results)
      if (results(j)%committed) value = max(value, abs(results(j)%mass%residual))
    end do
  end function max_abs_residual

  logical function worker_assignment_formula_ok(results, diagnostics, workers) result(ok)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    type(fmr_column_diagnostics_t), intent(in) :: diagnostics(:)
    integer, intent(in) :: workers
    integer :: j, expected
    ok = size(results) == size(diagnostics)
    if (.not. ok) return
    do j = 1, size(results)
      if (.not. allocated(diagnostics(j)%worker_assignments) .or. size(diagnostics(j)%worker_assignments) /= 1) then
        ok = .false.; return
      end if
      expected = mod(results(j)%dispatch_ordinal-1, workers) + 1
      if (diagnostics(j)%worker_assignments(1) /= expected) then
        ok = .false.; return
      end if
    end do
  end function worker_assignment_formula_ok

  logical function result_sets_by_id_identical(left, right) result(equal)
    type(fmr_serialized_column_result_t), intent(in) :: left(:), right(:)
    integer :: i, j
    equal = size(left) == size(right)
    if (.not. equal) return
    do i = 1, size(left)
      j = find_result_index(right, left(i)%column_id)
      if (j <= 0 .or. .not. column_result_identical(left(i), right(j))) then
        equal = .false.; return
      end if
    end do
  end function result_sets_by_id_identical

  integer function find_result_index(values, column_id) result(index)
    type(fmr_serialized_column_result_t), intent(in) :: values(:)
    integer(int64), intent(in) :: column_id
    integer :: j
    index = 0
    do j = 1, size(values)
      if (values(j)%column_id == column_id) then
        index = j
        return
      end if
    end do
  end function find_result_index

  logical function column_result_identical(left, right) result(equal)
    type(fmr_serialized_column_result_t), intent(in) :: left, right
    equal = left%column_id == right%column_id .and. left%dispatch_ordinal == right%dispatch_ordinal .and. &
      same_bits(left%requested_t0,right%requested_t0) .and. same_bits(left%requested_t1,right%requested_t1) .and. &
      (left%admission_assessed .eqv. right%admission_assessed) .and. (left%admitted .eqv. right%admitted) .and. &
      trim(left%admission_status) == trim(right%admission_status) .and. left%kernel_status == right%kernel_status .and. &
      left%commit_status == right%commit_status .and. (left%completed .eqv. right%completed) .and. &
      (left%committed .eqv. right%committed) .and. (left%solver_executed .eqv. right%solver_executed) .and. &
      trim(left%solver_route) == trim(right%solver_route) .and. left%solver_iterations == right%solver_iterations .and. &
      left%accepted_substeps == right%accepted_substeps .and. &
      left%solver_nonlinear_iterations == right%solver_nonlinear_iterations .and. &
      left%solver_internal_retries == right%solver_internal_retries .and. &
      left%solver_headcalc_calls == right%solver_headcalc_calls .and. &
      left%solver_jacobian_builds == right%solver_jacobian_builds .and. &
      left%solver_linear_solves == right%solver_linear_solves .and. &
      left%solver_backtracking_attempts == right%solver_backtracking_attempts .and. &
      left%solver_alternative_solver_calls == right%solver_alternative_solver_calls .and. &
      left%initial_revision == right%initial_revision .and. left%final_revision == right%final_revision .and. &
      same_bits(left%final_committed_time,right%final_committed_time) .and. &
      (left%final_committed_time_bound .eqv. right%final_committed_time_bound) .and. mass_identical(left%mass,right%mass)
  end function column_result_identical

  logical function mass_identical(left, right) result(equal)
    type(canonical_mass_accounting_t), intent(in) :: left, right
    equal = (left%complete .eqv. right%complete) .and. left%missing_contribution_mask == right%missing_contribution_mask .and. &
      left%origin_lineage_id == right%origin_lineage_id .and. left%origin_revision == right%origin_revision .and. &
      left%accepted_transaction_count == right%accepted_transaction_count .and. &
      same_bits(left%interval_t0,right%interval_t0) .and. same_bits(left%interval_t1,right%interval_t1) .and. &
      same_bits(left%storage_start,right%storage_start) .and. same_bits(left%storage_end,right%storage_end) .and. &
      same_bits(left%storage_change,right%storage_change) .and. same_bits(left%total_in,right%total_in) .and. &
      same_bits(left%total_out,right%total_out) .and. same_bits(left%residual,right%residual)
  end function mass_identical

  logical function diagnostics_by_id_semantically_identical(left, right) result(equal)
    type(fmr_column_diagnostics_t), intent(in) :: left(:), right(:)
    integer :: i, j
    equal = size(left) == size(right)
    if (.not. equal) return
    do i = 1, size(left)
      j = find_diag_index(right, left(i)%column_id)
      if (j <= 0 .or. .not. diagnostic_semantically_identical(left(i), right(j))) then
        equal = .false.; return
      end if
    end do
  end function diagnostics_by_id_semantically_identical

  logical function diagnostics_by_id_fully_identical(left, right) result(equal)
    type(fmr_column_diagnostics_t), intent(in) :: left(:), right(:)
    integer :: i, j
    equal = size(left) == size(right)
    if (.not. equal) return
    do i = 1, size(left)
      j = find_diag_index(right, left(i)%column_id)
      if (j <= 0 .or. .not. diagnostic_semantically_identical(left(i), right(j))) then
        equal = .false.; return
      end if
      if ((allocated(left(i)%worker_assignments) .neqv. allocated(right(j)%worker_assignments))) then
        equal = .false.; return
      end if
      if (allocated(left(i)%worker_assignments)) then
        if (size(left(i)%worker_assignments) /= size(right(j)%worker_assignments)) then
          equal = .false.; return
        end if
        if (any(left(i)%worker_assignments /= right(j)%worker_assignments)) then
          equal = .false.; return
        end if
      end if
    end do
  end function diagnostics_by_id_fully_identical

  integer function find_diag_index(values, column_id) result(index)
    type(fmr_column_diagnostics_t), intent(in) :: values(:)
    integer(int64), intent(in) :: column_id
    integer :: j
    index = 0
    do j = 1, size(values)
      if (values(j)%column_id == column_id) then
        index = j
        return
      end if
    end do
  end function find_diag_index

  logical function diagnostic_semantically_identical(left, right) result(equal)
    type(fmr_column_diagnostics_t), intent(in) :: left, right
    equal = left%column_id == right%column_id .and. left%template_id == right%template_id .and. &
      left%backend == right%backend .and. left%execution_class == right%execution_class .and. &
      left%committed_revision == right%committed_revision .and. same_bits(left%committed_time,right%committed_time) .and. &
      (left%committed_time_bound .eqv. right%committed_time_bound) .and. &
      left%checkpoint_captures == right%checkpoint_captures .and. left%checkpoint_replays == right%checkpoint_replays .and. &
      left%runtime_attempts == right%runtime_attempts .and. left%attempts == right%attempts .and. &
      left%retries == right%retries .and. left%accepted == right%accepted .and. left%rejected == right%rejected .and. &
      left%synthetic_cost == right%synthetic_cost .and. &
      trim(left%failure_classification) == trim(right%failure_classification) .and. &
      same_bits(left%unrounded_mass_residual,right%unrounded_mass_residual)
  end function diagnostic_semantically_identical

  logical function aggregate_semantically_identical(left, right) result(equal)
    type(fmr_aggregate_diagnostics_t), intent(in) :: left, right
    equal = left%columns == right%columns .and. left%templates == right%templates .and. &
      left%batches == right%batches .and. left%attempts == right%attempts .and. left%retries == right%retries .and. &
      left%failures == right%failures .and. left%max_cost == right%max_cost .and. &
      same_bits(left%mean_cost,right%mean_cost) .and. same_bits(left%p95_cost,right%p95_cost) .and. &
      same_bits(left%aggregate_unrounded_mass_residual,right%aggregate_unrounded_mass_residual)
  end function aggregate_semantically_identical

  logical function aggregate_fully_identical(left, right) result(equal)
    type(fmr_aggregate_diagnostics_t), intent(in) :: left, right
    equal = aggregate_semantically_identical(left,right) .and. left%workers == right%workers
    if (.not. equal) return
    if (allocated(left%work_distribution) .neqv. allocated(right%work_distribution)) then
      equal = .false.; return
    end if
    if (allocated(left%work_distribution)) then
      if (size(left%work_distribution) /= size(right%work_distribution)) then
        equal = .false.; return
      end if
      equal = all(left%work_distribution == right%work_distribution)
    end if
  end function aggregate_fully_identical

  logical function runtime_semantically_identical(left, right) result(equal)
    type(fmr_serialized_batch_diagnostics_t), intent(in) :: left, right
    equal = left%number_requested == right%number_requested .and. left%number_admitted == right%number_admitted .and. &
      left%number_executed == right%number_executed .and. left%number_committed == right%number_committed .and. &
      left%number_rejected == right%number_rejected .and. left%physical_solve_count == right%physical_solve_count .and. &
      left%deterministic_collection .eqv. right%deterministic_collection .and. &
      same_bits(left%effective_t0,right%effective_t0) .and. same_bits(left%effective_t1,right%effective_t1) .and. &
      same_bits(left%max_abs_column_mass_residual,right%max_abs_column_mass_residual) .and. &
      mass_identical(left%authoritative_aggregate_mass,right%authoritative_aggregate_mass)
  end function runtime_semantically_identical

  logical function state_sets_identical(left, right) result(equal)
    type(kernel_committed_state_t), intent(in) :: left(:), right(:)
    integer :: j
    equal = size(left) == size(right)
    if (.not. equal) return
    do j = 1, size(left)
      if (.not. committed_state_identical(left(j),right(j))) then
        equal = .false.; return
      end if
    end do
  end function state_sets_identical

  logical function committed_state_identical(left, right) result(equal)
    type(kernel_committed_state_t), intent(in) :: left, right
    logical :: lb, rb
    real(real64) :: lt, rt
    equal = left%current_lineage_id() == right%current_lineage_id() .and. &
         left%current_revision() == right%current_revision() .and. committed_fingerprint(left) == committed_fingerprint(right)
    if (.not. equal) return
    call left%current_time(lt,lb)
    call right%current_time(rt,rb)
    equal = (lb .eqv. rb)
    if (equal .and. lb) equal = same_bits(lt,rt)
  end function committed_state_identical

  integer(int64) function committed_fingerprint(state) result(fp)
    type(kernel_committed_state_t), intent(in) :: state
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    integer :: j
    call state%snapshot(snapshot, got)
    call require(got, 'committed snapshot')
    fp = 1469598103934665603_int64
    select type (physical => snapshot)
    class is (fmr_b110_physical_state_t)
      fp = ieor(fp, int(physical%active_nodes,int64))
      do j = 1, physical%active_nodes
        fp = ieor(fp, transfer(physical%pressure_head(j),fp))
        fp = ieor(fp, transfer(physical%water_content(j),fp))
      end do
      fp = ieor(fp, transfer(physical%ponding_depth,fp))
      fp = ieor(fp, transfer(physical%groundwater_level,fp))
      fp = ieor(fp, merge(1_int64,0_int64,allocated(physical%snow)))
    class default
      error stop 'F-MR20 V1 unexpected committed state type'
    end select
  end function committed_fingerprint

  logical function parameter_sets_identical(left, right) result(equal)
    type(fmr_b110_physical_parameters_t), intent(in) :: left(:), right(:)
    integer :: i
    equal = size(left) == size(right)
    if (.not. equal) return
    do i = 1, size(left)
      if (left(i)%parameter_set_id /= right(i)%parameter_set_id .or. left(i)%active_nodes /= right(i)%active_nodes .or. &
          left(i)%bottom_mode /= right(i)%bottom_mode .or. left(i)%swkimpl /= right(i)%swkimpl .or. &
          left(i)%swkmean /= right(i)%swkmean .or. left(i)%swsophy /= right(i)%swsophy .or. &
          left(i)%max_iterations /= right(i)%max_iterations .or. left(i)%max_backtracking /= right(i)%max_backtracking .or. &
          (left(i)%root_extraction_active .neqv. right(i)%root_extraction_active) .or. &
          (left(i)%macropore_active .neqv. right(i)%macropore_active) .or. (left(i)%snow_active .neqv. right(i)%snow_active) .or. &
          (left(i)%hysteresis_active .neqv. right(i)%hysteresis_active) .or. &
          (left(i)%tabulated_hydraulics_active .neqv. right(i)%tabulated_hydraulics_active) .or. &
          (left(i)%elasticity_active .neqv. right(i)%elasticity_active) .or. (left(i)%frost_active .neqv. right(i)%frost_active)) then
        equal = .false.; return
      end if
      if (.not. same_bits(left(i)%min_step_duration,right(i)%min_step_duration) .or. &
          .not. same_bits(left(i)%compartment_balance_tolerance,right(i)%compartment_balance_tolerance) .or. &
          .not. same_bits(left(i)%total_balance_tolerance,right(i)%total_balance_tolerance) .or. &
          .not. same_bits(left(i)%head_abs_tolerance,right(i)%head_abs_tolerance) .or. &
          .not. same_bits(left(i)%head_rel_tolerance,right(i)%head_rel_tolerance) .or. &
          .not. same_bits(left(i)%ponding_tolerance,right(i)%ponding_tolerance)) then
        equal = .false.; return
      end if
      if (.not. real_vector_bits_identical(left(i)%z,right(i)%z) .or. &
          .not. real_vector_bits_identical(left(i)%dz,right(i)%dz) .or. &
          .not. real_vector_bits_identical(left(i)%node_distance,right(i)%node_distance) .or. &
          .not. real_matrix_bits_identical(left(i)%cofgen,right(i)%cofgen)) then
        equal = .false.; return
      end if
      if ((allocated(left(i)%snow) .neqv. allocated(right(i)%snow))) then
        equal = .false.; return
      end if
    end do
  end function parameter_sets_identical

  logical function real_vector_bits_identical(left, right) result(equal)
    real(real64), intent(in) :: left(:), right(:)
    integer :: j
    equal = size(left) == size(right)
    if (.not. equal) return
    do j = 1, size(left)
      if (.not. same_bits(left(j),right(j))) then
        equal = .false.; return
      end if
    end do
  end function real_vector_bits_identical

  logical function real_matrix_bits_identical(left, right) result(equal)
    real(real64), intent(in) :: left(:,:), right(:,:)
    integer :: i, j
    equal = all(shape(left) == shape(right))
    if (.not. equal) return
    do j = 1, size(left,2)
      do i = 1, size(left,1)
        if (.not. same_bits(left(i,j),right(i,j))) then
          equal = .false.; return
        end if
      end do
    end do
  end function real_matrix_bits_identical

  logical function same_bits(a,b)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia, ib
    ia = transfer(a,ia)
    ib = transfer(b,ib)
    same_bits = ia == ib
  end function same_bits

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A)') 'FMR20_V1_FAIL '//trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fmr20_parallel_v1_qualification
