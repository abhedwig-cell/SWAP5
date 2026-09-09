program test_fmr20_authoritative_one_worker_identity
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t, canonical_mass_accounting_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, fmr_serialized_batch_diagnostics_t, &
       fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK
  use mod_fmr_parallel_physical_scheduler, only: fmr_parallel_assignment_t, fmr_build_parallel_schedule, &
       FMR_PARALLEL_SCHEDULE_OK, FMR_PARALLEL_SCHEDULE_INVALID_WORKER_COUNT
  use mod_fmr_parallel_worker_pool, only: fmr_run_parallel_physical_multiswap, FMR_PARALLEL_POOL_OK, &
       FMR_PARALLEL_POOL_INVALID_WORKER_COUNT, FMR_PARALLEL_POOL_MULTIWORKER_NOT_ADMITTED
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  integer, parameter :: ncol = 4
  integer, parameter :: batch_size = 2
  real(real64), parameter :: t0 = 1000.125_real64
  real(real64), parameter :: t1 = 1000.625_real64
  real(real64), parameter :: head0 = -75.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64

  type(fmr_logical_column_t) :: columns(ncol), reversed(ncol)
  type(fmr_template_t) :: templates(1)
  type(fmr_b110_physical_parameters_t) :: parameters(1)
  type(fmr_b110_physical_forcing_t) :: forcings(ncol)
  type(kernel_committed_state_t) :: direct_states(ncol), pool_states(ncol), rejected_states(ncol)
  type(fmr_serialized_column_result_t), allocatable :: direct_results(:), pool_results(:), rejected_results(:)
  type(fmr_column_diagnostics_t), allocatable :: direct_diag(:), pool_diag(:), rejected_diag(:)
  type(fmr_aggregate_diagnostics_t) :: direct_aggregate, pool_aggregate, rejected_aggregate
  type(fmr_serialized_batch_diagnostics_t) :: direct_runtime, pool_runtime, rejected_runtime
  type(fmr_parallel_assignment_t), allocatable :: schedule_a(:), schedule_b(:), invalid_schedule(:)
  type(fmr_b110_physical_state_t) :: initial_state, column_state
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(canonical_numerical_config_t) :: config
  integer(int64) :: rejected_fingerprint(ncol), rejected_revision(ncol)
  real(real64) :: rejected_time(ncol), conductivity0
  logical :: rejected_time_bound(ncol), ok
  integer :: direct_status, serialized_status, pool_status, schedule_status, i

  call configure_template(templates(1))
  call configure_parameters(parameters(1), initial_state, conductivity0)
  call configure_transaction(config)
  do i = 1, ncol
    columns(i)%column_id = 202000_int64 + int(i,int64)
    columns(i)%template_id = templates(1)%template_id
    columns(i)%parameter_ref = 1_int64
    columns(i)%state_handle = int(i,int64)
    columns(i)%forcing_handle = int(i,int64)
    columns(i)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    call configure_forcing(forcings(i), conductivity0, 1.0_real64 + 0.01_real64*real(i,real64))
    column_state = initial_state
    column_state%groundwater_level = -2.0_real64 - 0.01_real64*real(i,real64)
    call fmr_new_b110_committed_state(direct_states(i), columns(i)%column_id, column_state, t0, ok)
    call require(ok, 'direct state initialization')
    call fmr_new_b110_committed_state(pool_states(i), columns(i)%column_id, column_state, t0, ok)
    call require(ok, 'pool state initialization')
    call fmr_new_b110_committed_state(rejected_states(i), columns(i)%column_id, column_state, t0, ok)
    call require(ok, 'rejected state initialization')
    rejected_fingerprint(i) = committed_fingerprint(rejected_states(i))
    rejected_revision(i) = rejected_states(i)%current_revision()
    call rejected_states(i)%current_time(rejected_time(i), rejected_time_bound(i))
  end do

  reversed = columns(ncol:1:-1)
  call fmr_build_parallel_schedule(columns, 4, schedule_a, schedule_status)
  call require(schedule_status == FMR_PARALLEL_SCHEDULE_OK, 'schedule status')
  call fmr_build_parallel_schedule(reversed, 4, schedule_b, schedule_status)
  call require(schedule_status == FMR_PARALLEL_SCHEDULE_OK, 'reversed schedule status')
  call require(schedules_identical(schedule_a, schedule_b), 'canonical schedule input-order identity')
  do i = 1, ncol
    call require(schedule_a(i)%canonical_position == i, 'canonical position')
    call require(schedule_a(i)%worker_id == mod(i-1,4)+1, 'static assignment formula')
  end do
  call fmr_build_parallel_schedule(columns, 0, invalid_schedule, schedule_status)
  call require(schedule_status == FMR_PARALLEL_SCHEDULE_INVALID_WORKER_COUNT, 'invalid schedule status')
  call require(size(invalid_schedule) == 0, 'invalid schedule empty')
  write(*,'(A)') 'FMR20_AUTH_SCHEDULER_IDENTITY=PASS'

  call reset_legacy_globals()
  call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, direct_states, config, &
       top_provider, t0, t1, batch_size, direct_results, direct_diag, direct_aggregate, direct_status, direct_runtime)
  call require(direct_status == FMR_SERIAL_DISPATCH_OK, 'direct serialized dispatch')
  call require(all_committed(direct_results), 'direct committed')

  call reset_legacy_globals()
  call fmr_run_parallel_physical_multiswap(columns, templates, parameters, forcings, pool_states, config, &
       top_provider, t0, t1, batch_size, 1, pool_results, pool_diag, pool_aggregate, serialized_status, pool_status, &
       pool_runtime)
  call require(pool_status == FMR_PARALLEL_POOL_OK, 'one-worker pool status')
  call require(serialized_status == direct_status, 'dispatch status identity')
  call require(result_sets_identical(direct_results, pool_results), 'result identity')
  call require(diagnostic_sets_identical(direct_diag, pool_diag), 'column diagnostics identity')
  call require(aggregates_identical(direct_aggregate, pool_aggregate), 'aggregate identity')
  call require(runtime_diagnostics_identical(direct_runtime, pool_runtime), 'runtime diagnostics identity')
  call require(state_sets_identical(direct_states, pool_states), 'committed state identity')
  call require(max_abs_residual(pool_results) <= hard_mass_gate, 'hard mass gate')
  write(*,'(A)') 'FMR20_AUTH_ONE_WORKER_RESULT_IDENTITY=PASS'
  write(*,'(A)') 'FMR20_AUTH_ONE_WORKER_DIAGNOSTIC_IDENTITY=PASS'
  write(*,'(A)') 'FMR20_AUTH_ONE_WORKER_AGGREGATE_IDENTITY=PASS'
  write(*,'(A)') 'FMR20_AUTH_ONE_WORKER_RUNTIME_DIAGNOSTIC_IDENTITY=PASS'
  write(*,'(A)') 'FMR20_AUTH_ONE_WORKER_COMMITTED_STATE_TIME_IDENTITY=PASS'
  write(*,'(A)') 'FMR20_AUTH_ONE_WORKER_HARD_MASS_GATE=PASS'

  call reset_legacy_globals()
  call fmr_run_parallel_physical_multiswap(columns, templates, parameters, forcings, rejected_states, config, &
       top_provider, t0, t1, batch_size, 2, rejected_results, rejected_diag, rejected_aggregate, serialized_status, &
       pool_status, rejected_runtime)
  call require(pool_status == FMR_PARALLEL_POOL_MULTIWORKER_NOT_ADMITTED, 'multiworker rejection')
  call require(serialized_status == -1, 'multiworker serialized call absent')
  call require(rejected_runtime%physical_solve_count == 0, 'multiworker zero physical solves')
  call require(rejected_runtime%number_committed == 0, 'multiworker zero commits')
  do i = 1, ncol
    call require(rejected_states(i)%current_revision() == rejected_revision(i), 'rejected revision unchanged')
    call require(committed_fingerprint(rejected_states(i)) == rejected_fingerprint(i), 'rejected physical state unchanged')
    call verify_time_unchanged(rejected_states(i), rejected_time(i), rejected_time_bound(i))
    call require(.not. rejected_results(i)%solver_executed .and. .not. rejected_results(i)%committed, &
         'rejected result no execution')
  end do
  write(*,'(A)') 'FMR20_AUTH_MULTIWORKER_NOT_ADMITTED=PASS'
  write(*,'(A)') 'FMR20_AUTH_MULTIWORKER_ZERO_PHYSICAL_SOLVES=PASS'
  write(*,'(A)') 'FMR20_AUTH_MULTIWORKER_STATE_TIME_NONMUTATION=PASS'

  call fmr_run_parallel_physical_multiswap(columns, templates, parameters, forcings, rejected_states, config, &
       top_provider, t0, t1, batch_size, 0, rejected_results, rejected_diag, rejected_aggregate, serialized_status, &
       pool_status, rejected_runtime)
  call require(pool_status == FMR_PARALLEL_POOL_INVALID_WORKER_COUNT, 'zero worker rejected')
  call require(serialized_status == -1 .and. rejected_runtime%physical_solve_count == 0, 'zero worker no physics')
  write(*,'(A)') 'FMR20_AUTH_ZERO_WORKER_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FMR20_AUTHORITATIVE_ONE_WORKER_IDENTITY_TEST PASS'

contains

  subroutine configure_template(template)
    type(fmr_template_t), intent(out) :: template
    template%template_id = 2020_int64
    template%physics_topology_id = 202001_int64
    template%vertical_layout_id = 202002_int64
    template%state_layout_id = 202003_int64
    template%solver_interface_id = 202004_int64
    template%optional_state_layout_id = 0_int64
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_template

  subroutine configure_parameters(parameters, state, conductivity0)
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: conductivity0
    type(b110_default_mvg_parameters_t), target :: hyd_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: j

    parameters%parameter_set_id = 202001_int64
    parameters%active_nodes = numnod
    allocate(parameters%z(numnod), parameters%dz(numnod), parameters%node_distance(numnod), parameters%cofgen(24,numnod))
    parameters%z = z
    parameters%dz = dz
    parameters%node_distance = disnod(1:numnod)
    parameters%cofgen = 0.0_real64
    do j = 1, numnod
      parameters%cofgen(1,j) = 0.032_real64
      parameters%cofgen(2,j) = 0.423_real64
      parameters%cofgen(3,j) = 4.75_real64
      parameters%cofgen(4,j) = 0.0135_real64
      parameters%cofgen(5,j) = 0.365_real64
      parameters%cofgen(6,j) = 1.455_real64
      parameters%cofgen(7,j) = 1.0_real64 - 1.0_real64/parameters%cofgen(6,j)
      parameters%cofgen(8,j) = parameters%cofgen(4,j)
      parameters%cofgen(10,j) = parameters%cofgen(3,j)
      parameters%cofgen(11,j) = 0.999_real64
      parameters%cofgen(12,j) = 0.99_real64*parameters%cofgen(3,j)
      parameters%cofgen(22,j) = -1.0e6_real64
      parameters%cofgen(23,j) = 1.0e-12_real64
    end do
    parameters%bottom_mode = 7
    parameters%swkimpl = 0
    parameters%swkmean = 1
    parameters%swsophy = 0
    parameters%root_extraction_active = .false.
    parameters%macropore_active = .false.
    parameters%snow_active = .false.
    parameters%hysteresis_active = .false.
    parameters%tabulated_hydraulics_active = .false.
    parameters%elasticity_active = .false.
    parameters%frost_active = .false.

    call initialize_b110_default_mvg_parameters(hyd_parameters, parameters%cofgen)
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
      forcing%subsurface_irrigation_source(j) = forcing%drainage_flux_by_level(1,j) + forcing%drainage_flux_by_level(2,j)
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

  subroutine reset_legacy_globals()
    legacy_qdra = 12345.0_real64
    legacy_qssdi = -54321.0_real64
    legacy_qrot = 0.0_real64
    swmacro = 0
    melt = 0.0_real64
  end subroutine reset_legacy_globals

  logical function schedules_identical(left, right) result(equal)
    type(fmr_parallel_assignment_t), intent(in) :: left(:), right(:)
    integer :: j
    equal = size(left) == size(right)
    if (.not. equal) return
    do j = 1, size(left)
      if (left(j)%canonical_position /= right(j)%canonical_position .or. left(j)%column_id /= right(j)%column_id .or. &
          left(j)%template_id /= right(j)%template_id .or. left(j)%worker_id /= right(j)%worker_id) then
        equal = .false.
        return
      end if
    end do
  end function schedules_identical

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

  logical function result_sets_identical(left, right) result(equal)
    type(fmr_serialized_column_result_t), intent(in) :: left(:), right(:)
    integer :: j
    equal = size(left) == size(right)
    if (.not. equal) return
    do j = 1, size(left)
      if (.not. column_result_identical(left(j), right(j))) then
        equal = .false.
        return
      end if
    end do
  end function result_sets_identical

  logical function column_result_identical(left, right) result(equal)
    type(fmr_serialized_column_result_t), intent(in) :: left, right
    equal = left%column_id == right%column_id .and. left%dispatch_ordinal == right%dispatch_ordinal .and. &
      same_bits(left%requested_t0,right%requested_t0) .and. same_bits(left%requested_t1,right%requested_t1) .and. &
      left%admission_assessed .eqv. right%admission_assessed .and. left%admitted .eqv. right%admitted .and. &
      trim(left%admission_status) == trim(right%admission_status) .and. left%kernel_status == right%kernel_status .and. &
      left%commit_status == right%commit_status .and. left%completed .eqv. right%completed .and. &
      left%committed .eqv. right%committed .and. left%solver_executed .eqv. right%solver_executed .and. &
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
      left%final_committed_time_bound .eqv. right%final_committed_time_bound .and. mass_identical(left%mass,right%mass)
  end function column_result_identical

  logical function mass_identical(left, right) result(equal)
    type(canonical_mass_accounting_t), intent(in) :: left, right
    equal = left%complete .eqv. right%complete .and. left%missing_contribution_mask == right%missing_contribution_mask .and. &
      left%origin_lineage_id == right%origin_lineage_id .and. left%origin_revision == right%origin_revision .and. &
      left%accepted_transaction_count == right%accepted_transaction_count .and. &
      same_bits(left%interval_t0,right%interval_t0) .and. same_bits(left%interval_t1,right%interval_t1) .and. &
      same_bits(left%storage_start,right%storage_start) .and. same_bits(left%storage_end,right%storage_end) .and. &
      same_bits(left%storage_change,right%storage_change) .and. same_bits(left%total_in,right%total_in) .and. &
      same_bits(left%total_out,right%total_out) .and. same_bits(left%residual,right%residual)
  end function mass_identical

  logical function diagnostic_sets_identical(left, right) result(equal)
    type(fmr_column_diagnostics_t), intent(in) :: left(:), right(:)
    integer :: j
    equal = size(left) == size(right)
    if (.not. equal) return
    do j = 1, size(left)
      if (left(j)%column_id /= right(j)%column_id .or. left(j)%template_id /= right(j)%template_id .or. &
          left(j)%backend /= right(j)%backend .or. left(j)%execution_class /= right(j)%execution_class .or. &
          left(j)%committed_revision /= right(j)%committed_revision .or. &
          .not. same_bits(left(j)%committed_time,right(j)%committed_time) .or. &
          (left(j)%committed_time_bound .neqv. right(j)%committed_time_bound) .or. &
          left(j)%checkpoint_captures /= right(j)%checkpoint_captures .or. &
          left(j)%checkpoint_replays /= right(j)%checkpoint_replays .or. &
          left(j)%runtime_attempts /= right(j)%runtime_attempts .or. left(j)%attempts /= right(j)%attempts .or. &
          left(j)%retries /= right(j)%retries .or. left(j)%accepted /= right(j)%accepted .or. &
          left(j)%rejected /= right(j)%rejected .or. left(j)%synthetic_cost /= right(j)%synthetic_cost .or. &
          trim(left(j)%failure_classification) /= trim(right(j)%failure_classification) .or. &
          .not. same_bits(left(j)%unrounded_mass_residual,right(j)%unrounded_mass_residual)) then
        equal = .false.
        return
      end if
      if (allocated(left(j)%worker_assignments) .neqv. allocated(right(j)%worker_assignments)) then
        equal = .false.
        return
      end if
      if (allocated(left(j)%worker_assignments)) then
        if (size(left(j)%worker_assignments) /= size(right(j)%worker_assignments)) then
          equal = .false.
          return
        end if
        if (any(left(j)%worker_assignments /= right(j)%worker_assignments)) then
          equal = .false.
          return
        end if
      end if
    end do
  end function diagnostic_sets_identical

  logical function aggregates_identical(left, right) result(equal)
    type(fmr_aggregate_diagnostics_t), intent(in) :: left, right
    equal = left%columns == right%columns .and. left%templates == right%templates .and. left%batches == right%batches .and. &
      left%workers == right%workers .and. left%attempts == right%attempts .and. left%retries == right%retries .and. &
      left%failures == right%failures .and. left%max_cost == right%max_cost .and. &
      same_bits(left%mean_cost,right%mean_cost) .and. same_bits(left%p95_cost,right%p95_cost) .and. &
      same_bits(left%aggregate_unrounded_mass_residual,right%aggregate_unrounded_mass_residual)
    if (.not. equal) return
    if (allocated(left%work_distribution) .neqv. allocated(right%work_distribution)) then
      equal = .false.
      return
    end if
    if (allocated(left%work_distribution)) then
      if (size(left%work_distribution) /= size(right%work_distribution)) then
        equal = .false.
        return
      end if
      equal = all(left%work_distribution == right%work_distribution)
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

  logical function state_sets_identical(left, right) result(equal)
    type(kernel_committed_state_t), intent(in) :: left(:), right(:)
    integer :: j
    logical :: lb, rb
    real(real64) :: lt, rt
    equal = size(left) == size(right)
    if (.not. equal) return
    do j = 1, size(left)
      if (left(j)%current_lineage_id() /= right(j)%current_lineage_id()) then
        equal = .false.; return
      end if
      if (left(j)%current_revision() /= right(j)%current_revision()) then
        equal = .false.; return
      end if
      if (committed_fingerprint(left(j)) /= committed_fingerprint(right(j))) then
        equal = .false.; return
      end if
      call left(j)%current_time(lt,lb)
      call right(j)%current_time(rt,rb)
      if (lb .neqv. rb) then
        equal = .false.; return
      end if
      if (lb .and. .not. same_bits(lt,rt)) then
        equal = .false.; return
      end if
    end do
  end function state_sets_identical

  subroutine verify_time_unchanged(state, expected, expected_bound)
    type(kernel_committed_state_t), intent(in) :: state
    real(real64), intent(in) :: expected
    logical, intent(in) :: expected_bound
    real(real64) :: actual
    logical :: bound
    call state%current_time(actual,bound)
    call require(bound .eqv. expected_bound, 'time-bound nonmutation')
    if (bound) call require(same_bits(actual,expected), 'committed-time nonmutation')
  end subroutine verify_time_unchanged

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
      error stop 'F-MR20 unexpected committed state type'
    end select
  end function committed_fingerprint

  real(real64) function max_abs_residual(results) result(value)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    integer :: j
    value = 0.0_real64
    do j = 1, size(results)
      if (results(j)%committed) value = max(value, abs(results(j)%mass%residual))
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
      write(*,'(A,1X,A)') 'FMR20_AUTH_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fmr20_authoritative_one_worker_identity
