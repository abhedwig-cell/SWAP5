program test_fmr20_parallel_physical_one_worker
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK
  use mod_fmr_parallel_physical_scheduler, only: fmr_parallel_assignment_t, fmr_build_parallel_schedule, &
       FMR_PARALLEL_SCHEDULE_OK, FMR_PARALLEL_SCHEDULE_INVALID_WORKER_COUNT
  use mod_fmr_parallel_worker_pool, only: fmr_run_parallel_physical_multiswap, FMR_PARALLEL_POOL_OK, &
       FMR_PARALLEL_POOL_INVALID_WORKER_COUNT, FMR_PARALLEL_POOL_MULTIWORKER_NOT_ADMITTED
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  integer, parameter :: ncol = 8
  integer, parameter :: batch_size = 3
  real(real64), parameter :: t0 = 1000.125_real64
  real(real64), parameter :: t1 = 1000.625_real64
  real(real64), parameter :: head0 = -75.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64

  type(fmr_logical_column_t) :: columns(ncol), reversed(ncol)
  type(fmr_template_t) :: templates(2)
  type(fmr_b110_physical_parameters_t) :: parameters(1)
  type(fmr_b110_physical_forcing_t) :: forcings(ncol)
  type(kernel_committed_state_t) :: direct_states(ncol), pool_states(ncol), rejected_states(ncol)
  type(fmr_serialized_column_result_t), allocatable :: direct_results(:), pool_results(:), rejected_results(:)
  type(fmr_column_diagnostics_t), allocatable :: direct_diag(:), pool_diag(:), rejected_diag(:)
  type(fmr_aggregate_diagnostics_t) :: direct_aggregate, pool_aggregate, rejected_aggregate
  type(fmr_serialized_batch_diagnostics_t) :: direct_runtime, pool_runtime, rejected_runtime
  type(fmr_parallel_assignment_t), allocatable :: schedule_a(:), schedule_b(:), invalid_schedule(:)
  type(fmr_b110_physical_state_t) :: initial_state
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(canonical_numerical_config_t) :: config
  integer(int64) :: rejected_before(ncol)
  real(real64) :: conductivity0
  integer :: direct_status, serialized_status, pool_status, schedule_status, i

  call configure_templates(templates)
  call configure_parameters(parameters(1), initial_state, conductivity0)
  call configure_transaction(config)
  call configure_columns_and_forcings(columns, forcings, conductivity0)
  call initialize_state_set(columns, initial_state, direct_states)
  call initialize_state_set(columns, initial_state, pool_states)
  call initialize_state_set(columns, initial_state, rejected_states)
  do i = 1, ncol
    rejected_before(i) = committed_fingerprint(rejected_states(i))
  end do

  reversed = columns(ncol:1:-1)
  call fmr_build_parallel_schedule(columns, 4, schedule_a, schedule_status)
  call require(schedule_status == FMR_PARALLEL_SCHEDULE_OK, 'canonical schedule status')
  call fmr_build_parallel_schedule(reversed, 4, schedule_b, schedule_status)
  call require(schedule_status == FMR_PARALLEL_SCHEDULE_OK, 'reversed schedule status')
  call require(schedules_identical(schedule_a, schedule_b), 'schedule input-order identity')
  do i = 1, size(schedule_a)
    call require(schedule_a(i)%canonical_position == i, 'canonical position identity')
    call require(schedule_a(i)%worker_id == mod(i-1,4)+1, 'static worker formula')
  end do
  call fmr_build_parallel_schedule(columns, 0, invalid_schedule, schedule_status)
  call require(schedule_status == FMR_PARALLEL_SCHEDULE_INVALID_WORKER_COUNT, 'invalid worker schedule rejection')
  call require(size(invalid_schedule) == 0, 'invalid worker schedule empty')
  write(*,'(A)') 'FMR20_PRODUCTION_SCHEDULER_CANONICAL_IDENTITY=PASS'
  write(*,'(A)') 'FMR20_PRODUCTION_SCHEDULER_INVALID_WORKER_FAIL_CLOSED=PASS'

  call reset_legacy_globals()
  call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, direct_states, config, &
       top_provider, t0, t1, batch_size, direct_results, direct_diag, direct_aggregate, direct_status, direct_runtime)
  call require(direct_status == FMR_SERIAL_DISPATCH_OK, 'direct MQ23 dispatch')

  call reset_legacy_globals()
  call fmr_run_parallel_physical_multiswap(columns, templates, parameters, forcings, pool_states, config, &
       top_provider, t0, t1, batch_size, 1, pool_results, pool_diag, pool_aggregate, serialized_status, pool_status, &
       pool_runtime)
  call require(pool_status == FMR_PARALLEL_POOL_OK, 'one-worker pool status')
  call require(serialized_status == direct_status, 'serialized dispatch status identity')
  call require(result_sets_identical(direct_results, pool_results), 'one-worker result identity')
  call require(diagnostic_sets_identical(direct_diag, pool_diag), 'one-worker diagnostics identity')
  call require(aggregates_identical(direct_aggregate, pool_aggregate), 'one-worker aggregate identity')
  call require(runtime_diagnostics_identical(direct_runtime, pool_runtime), 'one-worker runtime diagnostics identity')
  call require(state_sets_identical(direct_states, pool_states), 'one-worker committed-state identity')
  call require(max_abs_residual(pool_results) <= hard_mass_gate, 'one-worker hard mass gate')
  write(*,'(A)') 'FMR20_ONE_WORKER_MQ23_RESULT_IDENTITY=PASS'
  write(*,'(A)') 'FMR20_ONE_WORKER_MQ23_DIAGNOSTIC_IDENTITY=PASS'
  write(*,'(A)') 'FMR20_ONE_WORKER_MQ23_AGGREGATE_IDENTITY=PASS'
  write(*,'(A)') 'FMR20_ONE_WORKER_MQ23_RUNTIME_DIAGNOSTIC_IDENTITY=PASS'
  write(*,'(A)') 'FMR20_ONE_WORKER_MQ23_COMMITTED_STATE_IDENTITY=PASS'
  write(*,'(A)') 'FMR20_ONE_WORKER_HARD_MASS_GATE=PASS'

  call reset_legacy_globals()
  call fmr_run_parallel_physical_multiswap(columns, templates, parameters, forcings, rejected_states, config, &
       top_provider, t0, t1, batch_size, 2, rejected_results, rejected_diag, rejected_aggregate, serialized_status, &
       pool_status, rejected_runtime)
  call require(pool_status == FMR_PARALLEL_POOL_MULTIWORKER_NOT_ADMITTED, 'multiworker not admitted status')
  call require(serialized_status == -1, 'multiworker serialized backend not called')
  call require(rejected_runtime%physical_solve_count == 0, 'multiworker zero physical solves')
  call require(rejected_runtime%number_committed == 0, 'multiworker zero commits')
  do i = 1, ncol
    call require(rejected_states(i)%current_revision() == 0_int64, 'multiworker revision unchanged')
    call require(committed_fingerprint(rejected_states(i)) == rejected_before(i), 'multiworker state unchanged')
    call require(.not. rejected_results(i)%solver_executed, 'multiworker solver not executed')
    call require(.not. rejected_results(i)%committed, 'multiworker result not committed')
    call require(rejected_diag(i)%accepted == 0 .and. rejected_diag(i)%rejected == 1, 'multiworker diagnostic rejection')
    call require(trim(rejected_diag(i)%failure_classification) == 'MULTIWORKER_NOT_ADMITTED', &
         'multiworker failure classification')
  end do
  write(*,'(A)') 'FMR20_MULTIWORKER_REAL_PHYSICS_NOT_ADMITTED=PASS'
  write(*,'(A)') 'FMR20_MULTIWORKER_ZERO_PHYSICAL_SOLVES=PASS'
  write(*,'(A)') 'FMR20_MULTIWORKER_COMMITTED_STATE_NONMUTATION=PASS'

  call reset_legacy_globals()
  call fmr_run_parallel_physical_multiswap(columns, templates, parameters, forcings, rejected_states, config, &
       top_provider, t0, t1, batch_size, 0, rejected_results, rejected_diag, rejected_aggregate, serialized_status, &
       pool_status, rejected_runtime)
  call require(pool_status == FMR_PARALLEL_POOL_INVALID_WORKER_COUNT, 'zero worker pool rejection')
  call require(serialized_status == -1, 'zero worker serialized backend not called')
  call require(rejected_runtime%physical_solve_count == 0, 'zero worker zero physical solves')
  write(*,'(A)') 'FMR20_ZERO_WORKER_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FMR20_PARALLEL_PHYSICAL_ONE_WORKER_TEST PASS'

contains

  subroutine configure_templates(values)
    type(fmr_template_t), intent(out) :: values(2)
    values(1)%template_id = 520_int64
    values(1)%physics_topology_id = 52001_int64
    values(1)%vertical_layout_id = 52002_int64
    values(1)%state_layout_id = 52003_int64
    values(1)%solver_interface_id = 52004_int64
    values(1)%optional_state_layout_id = 0_int64
    values(1)%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    values(2) = values(1)
    values(2)%template_id = 521_int64
  end subroutine configure_templates

  subroutine configure_columns_and_forcings(values, force_values, conductivity0)
    type(fmr_logical_column_t), intent(out) :: values(ncol)
    type(fmr_b110_physical_forcing_t), intent(out) :: force_values(ncol)
    real(real64), intent(in) :: conductivity0
    integer :: k
    do k = 1, ncol
      values(k)%column_id = 520000_int64 + int(k,int64)
      if (mod(k,2) == 1) then
        values(k)%template_id = templates(1)%template_id
      else
        values(k)%template_id = templates(2)%template_id
      end if
      values(k)%parameter_ref = 1_int64
      values(k)%state_handle = int(k,int64)
      values(k)%forcing_handle = int(k,int64)
      values(k)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
      call configure_forcing(force_values(k), conductivity0, 1.0_real64 + 0.01_real64*real(k,real64))
    end do
  end subroutine configure_columns_and_forcings

  subroutine configure_parameters(value, state, conductivity0)
    type(fmr_b110_physical_parameters_t), intent(out) :: value
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: conductivity0
    type(b110_default_mvg_parameters_t), target :: hyd_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: k

    value%parameter_set_id = 52001_int64
    value%active_nodes = numnod
    allocate(value%z(numnod), value%dz(numnod), value%node_distance(numnod), value%cofgen(24,numnod))
    value%z = z
    value%dz = dz
    value%node_distance = disnod(1:numnod)
    value%cofgen = 0.0_real64
    do k = 1, numnod
      value%cofgen(1,k) = 0.032_real64
      value%cofgen(2,k) = 0.423_real64
      value%cofgen(3,k) = 4.75_real64
      value%cofgen(4,k) = 0.0135_real64
      value%cofgen(5,k) = 0.365_real64
      value%cofgen(6,k) = 1.455_real64
      value%cofgen(7,k) = 1.0_real64 - 1.0_real64/value%cofgen(6,k)
      value%cofgen(8,k) = value%cofgen(4,k)
      value%cofgen(9,k) = 0.0_real64
      value%cofgen(10,k) = value%cofgen(3,k)
      value%cofgen(11,k) = 0.999_real64
      value%cofgen(12,k) = 0.99_real64*value%cofgen(3,k)
      value%cofgen(22,k) = -1.0e6_real64
      value%cofgen(23,k) = 1.0e-12_real64
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

  subroutine configure_forcing(value, conductivity0, scale)
    type(fmr_b110_physical_forcing_t), intent(out) :: value
    real(real64), intent(in) :: conductivity0, scale
    integer :: k
    value%top_flux = -conductivity0
    value%top_head = head0
    value%bottom_flux = -conductivity0
    value%bottom_head = -100.0_real64
    allocate(value%drainage_flux_by_level(2,numnod), value%subsurface_irrigation_source(numnod), &
             value%root_extraction_sink(numnod))
    do k = 1, numnod
      value%drainage_flux_by_level(1,k) = scale*1.0e-5_real64*real(k,real64)
      value%drainage_flux_by_level(2,k) = -scale*2.0e-6_real64*real(k+1,real64)
      value%subsurface_irrigation_source(k) = value%drainage_flux_by_level(1,k) + value%drainage_flux_by_level(2,k)
      value%root_extraction_sink(k) = 0.0_real64
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

  subroutine initialize_state_set(column_values, state, states)
    type(fmr_logical_column_t), intent(in) :: column_values(:)
    type(fmr_b110_physical_state_t), intent(in) :: state
    type(kernel_committed_state_t), intent(out) :: states(:)
    logical :: ok
    integer :: k
    do k = 1, size(states)
      call fmr_new_b110_committed_state(states(k), column_values(k)%column_id, state, t0, ok)
      call require(ok, 'committed-state initialization')
    end do
  end subroutine initialize_state_set

  subroutine reset_legacy_globals()
    legacy_qdra = 12345.0_real64
    legacy_qssdi = -54321.0_real64
    legacy_qrot = 0.0_real64
    swmacro = 0
    melt = 0.0_real64
  end subroutine reset_legacy_globals

  logical function schedules_identical(left, right) result(equal)
    type(fmr_parallel_assignment_t), intent(in) :: left(:), right(:)
    integer :: k
    equal = size(left) == size(right)
    if (.not. equal) return
    do k = 1, size(left)
      if (left(k)%canonical_position /= right(k)%canonical_position .or. &
          left(k)%column_id /= right(k)%column_id .or. left(k)%template_id /= right(k)%template_id .or. &
          left(k)%worker_id /= right(k)%worker_id) then
        equal = .false.
        return
      end if
    end do
  end function schedules_identical

  logical function result_sets_identical(left, right) result(equal)
    type(fmr_serialized_column_result_t), intent(in) :: left(:), right(:)
    integer :: k
    equal = size(left) == size(right)
    if (.not. equal) return
    do k = 1, size(left)
      if (.not. column_results_identical(left(k), right(k))) then
        equal = .false.
        return
      end if
    end do
  end function result_sets_identical

  logical function column_results_identical(left, right) result(equal)
    type(fmr_serialized_column_result_t), intent(in) :: left, right
    equal = left%column_id == right%column_id .and. left%dispatch_ordinal == right%dispatch_ordinal .and. &
         same_bits(left%requested_t0,right%requested_t0) .and. same_bits(left%requested_t1,right%requested_t1) .and. &
         left%admission_assessed .eqv. right%admission_assessed .and. left%admitted .eqv. right%admitted .and. &
         trim(left%admission_status) == trim(right%admission_status) .and. &
         left%kernel_status == right%kernel_status .and. left%commit_status == right%commit_status .and. &
         left%completed .eqv. right%completed .and. left%committed .eqv. right%committed .and. &
         left%solver_executed .eqv. right%solver_executed .and. trim(left%solver_route) == trim(right%solver_route) .and. &
         left%solver_iterations == right%solver_iterations .and. left%initial_revision == right%initial_revision .and. &
         left%final_revision == right%final_revision .and. &
         same_bits(left%final_committed_time,right%final_committed_time) .and. &
         left%final_committed_time_bound .eqv. right%final_committed_time_bound .and. &
         mass_identical(left%mass,right%mass)
  end function column_results_identical

  logical function diagnostic_sets_identical(left, right) result(equal)
    type(fmr_column_diagnostics_t), intent(in) :: left(:), right(:)
    integer :: k
    equal = size(left) == size(right)
    if (.not. equal) return
    do k = 1, size(left)
      equal = left(k)%column_id == right(k)%column_id .and. left(k)%template_id == right(k)%template_id .and. &
           left(k)%backend == right(k)%backend .and. left(k)%execution_class == right(k)%execution_class .and. &
           left(k)%committed_revision == right(k)%committed_revision .and. &
           same_bits(left(k)%committed_time,right(k)%committed_time) .and. &
           left(k)%committed_time_bound .eqv. right(k)%committed_time_bound .and. &
           left(k)%checkpoint_captures == right(k)%checkpoint_captures .and. &
           left(k)%checkpoint_replays == right(k)%checkpoint_replays .and. &
           left(k)%runtime_attempts == right(k)%runtime_attempts .and. left(k)%attempts == right(k)%attempts .and. &
           left(k)%retries == right(k)%retries .and. left(k)%accepted == right(k)%accepted .and. &
           left(k)%rejected == right(k)%rejected .and. left(k)%synthetic_cost == right(k)%synthetic_cost .and. &
           trim(left(k)%failure_classification) == trim(right(k)%failure_classification) .and. &
           same_bits(left(k)%unrounded_mass_residual,right(k)%unrounded_mass_residual)
      if (.not. equal) return
      if (allocated(left(k)%worker_assignments) .neqv. allocated(right(k)%worker_assignments)) then
        equal = .false.; return
      end if
      if (allocated(left(k)%worker_assignments)) then
        if (size(left(k)%worker_assignments) /= size(right(k)%worker_assignments)) then
          equal = .false.; return
        end if
        if (any(left(k)%worker_assignments /= right(k)%worker_assignments)) then
          equal = .false.; return
        end if
      end if
    end do
  end function diagnostic_sets_identical

  logical function aggregates_identical(left, right) result(equal)
    type(fmr_aggregate_diagnostics_t), intent(in) :: left, right
    equal = left%columns == right%columns .and. left%templates == right%templates .and. &
         left%batches == right%batches .and. left%workers == right%workers .and. &
         left%attempts == right%attempts .and. left%retries == right%retries .and. left%failures == right%failures .and. &
         left%max_cost == right%max_cost .and. same_bits(left%mean_cost,right%mean_cost) .and. &
         same_bits(left%p95_cost,right%p95_cost) .and. &
         same_bits(left%aggregate_unrounded_mass_residual,right%aggregate_unrounded_mass_residual)
    if (.not. equal) return
    if (allocated(left%work_distribution) .neqv. allocated(right%work_distribution)) then
      equal = .false.; return
    end if
    if (allocated(left%work_distribution)) then
      equal = size(left%work_distribution) == size(right%work_distribution)
      if (equal) equal = all(left%work_distribution == right%work_distribution)
    end if
  end function aggregates_identical

  logical function runtime_diagnostics_identical(left, right) result(equal)
    type(fmr_serialized_batch_diagnostics_t), intent(in) :: left, right
    equal = left%number_requested == right%number_requested .and. left%number_admitted == right%number_admitted .and. &
         left%number_executed == right%number_executed .and. left%number_committed == right%number_committed .and. &
         left%number_rejected == right%number_rejected .and. left%physical_solve_count == right%physical_solve_count .and. &
         left%max_simultaneous_real_physical_solves == right%max_simultaneous_real_physical_solves .and. &
         left%deterministic_collection .eqv. right%deterministic_collection .and. &
         same_bits(left%effective_t0,right%effective_t0) .and. same_bits(left%effective_t1,right%effective_t1) .and. &
         same_bits(left%max_abs_column_mass_residual,right%max_abs_column_mass_residual) .and. &
         mass_identical(left%authoritative_aggregate_mass,right%authoritative_aggregate_mass)
  end function runtime_diagnostics_identical

  logical function mass_identical(left, right) result(equal)
    use mod_canonical_contracts, only: canonical_mass_accounting_t
    type(canonical_mass_accounting_t), intent(in) :: left, right
    equal = left%complete .eqv. right%complete .and. &
         left%missing_contribution_mask == right%missing_contribution_mask .and. &
         left%origin_lineage_id == right%origin_lineage_id .and. left%origin_revision == right%origin_revision .and. &
         left%accepted_transaction_count == right%accepted_transaction_count .and. &
         same_bits(left%interval_t0,right%interval_t0) .and. same_bits(left%interval_t1,right%interval_t1) .and. &
         same_bits(left%storage_start,right%storage_start) .and. same_bits(left%storage_end,right%storage_end) .and. &
         same_bits(left%storage_change,right%storage_change) .and. same_bits(left%total_in,right%total_in) .and. &
         same_bits(left%total_out,right%total_out) .and. same_bits(left%residual,right%residual)
  end function mass_identical

  logical function state_sets_identical(left, right) result(equal)
    type(kernel_committed_state_t), intent(in) :: left(:), right(:)
    integer :: k
    equal = size(left) == size(right)
    if (.not. equal) return
    do k = 1, size(left)
      if (left(k)%current_lineage_id() /= right(k)%current_lineage_id() .or. &
          left(k)%current_revision() /= right(k)%current_revision() .or. &
          committed_fingerprint(left(k)) /= committed_fingerprint(right(k))) then
        equal = .false.
        return
      end if
    end do
  end function state_sets_identical

  integer(int64) function committed_fingerprint(state) result(fp)
    type(kernel_committed_state_t), intent(in) :: state
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    integer :: k
    call state%snapshot(snapshot, got)
    call require(got, 'committed snapshot')
    fp = 1469598103934665603_int64
    select type (physical => snapshot)
    type is (fmr_b110_physical_state_t)
      fp = ieor(fp, int(physical%active_nodes,int64))
      do k = 1, physical%active_nodes
        fp = ieor(fp, transfer(physical%pressure_head(k),fp))
        fp = ieor(fp, transfer(physical%water_content(k),fp))
      end do
      fp = ieor(fp, transfer(physical%ponding_depth,fp))
      fp = ieor(fp, transfer(physical%groundwater_level,fp))
    class default
      error stop 'F-MR20 unexpected physical state type'
    end select
  end function committed_fingerprint

  real(real64) function max_abs_residual(results) result(value)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    integer :: k
    value = 0.0_real64
    do k = 1, size(results)
      if (results(k)%committed) value = max(value, abs(results(k)%mass%residual))
    end do
  end function max_abs_residual

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
      write(*,'(A,1X,A)') 'FMR20_PHYSICAL_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fmr20_parallel_physical_one_worker
