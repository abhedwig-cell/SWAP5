program test_fmr05_serialized_multiswap
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot
  use mod_transaction_reference, only: transaction_state_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK, FMR_SERIAL_DISPATCH_REGISTRY_REJECTED
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: t0 = 1000.125_real64
  real(real64), parameter :: t1 = 1000.625_real64
  real(real64), parameter :: head0 = -75.0_real64
  integer, parameter :: nfull = 32
  integer, parameter :: nbatch = 6
  integer, parameter :: batch_sizes(nbatch) = [1, 2, 8, 17, 31, 32]

  type(fmr_serialized_column_result_t), allocatable :: baseline_results(:), trial_results(:), single_results(:)
  type(fmr_serialized_column_result_t), allocatable :: failure_results(:), duplicate_results(:)
  type(fmr_column_diagnostics_t), allocatable :: baseline_diag(:), trial_diag(:), single_diag(:)
  type(fmr_column_diagnostics_t), allocatable :: failure_diag(:), duplicate_diag(:)
  type(kernel_committed_state_t), allocatable :: baseline_states(:), trial_states(:), single_states(:)
  type(kernel_committed_state_t), allocatable :: failure_states(:), duplicate_states(:)
  type(fmr_aggregate_diagnostics_t) :: baseline_aggregate, trial_aggregate, single_aggregate
  type(fmr_aggregate_diagnostics_t) :: failure_aggregate, duplicate_aggregate
  integer :: dispatch_status, i

  call execute_case(nfull, 8, .false., 0, .false., baseline_results, baseline_diag, baseline_aggregate, &
       baseline_states, dispatch_status)
  call require(dispatch_status == FMR_SERIAL_DISPATCH_OK, 'baseline dispatch status')
  call validate_success_case(nfull, 8, baseline_results, baseline_diag, baseline_aggregate, baseline_states)

  do i = 1, nbatch
    call execute_case(nfull, batch_sizes(i), .false., 0, .false., trial_results, trial_diag, trial_aggregate, &
         trial_states, dispatch_status)
    call require(dispatch_status == FMR_SERIAL_DISPATCH_OK, 'batch dispatch status')
    call validate_success_case(nfull, batch_sizes(i), trial_results, trial_diag, trial_aggregate, trial_states)
    call require(result_sets_identical(baseline_results, trial_results), 'batch result identity')
    call require(state_sets_identical(baseline_states, trial_states), 'batch committed-state identity')
    write(*,'(A,I0,A)') 'FMR05_BATCH_SIZE_', batch_sizes(i), '=PASS'
  end do

  call execute_case(nfull, 8, .true., 0, .false., trial_results, trial_diag, trial_aggregate, trial_states, dispatch_status)
  call require(dispatch_status == FMR_SERIAL_DISPATCH_OK, 'reversed dispatch status')
  call validate_success_case(nfull, 8, trial_results, trial_diag, trial_aggregate, trial_states)
  call require(result_sets_identical(baseline_results, trial_results), 'input-order result identity')
  call require(state_sets_identical(baseline_states, trial_states), 'input-order state identity')
  write(*,'(A)') 'FMR05_INPUT_ORDER_INDEPENDENCE=PASS'

  call execute_case(1, 1, .false., 0, .false., single_results, single_diag, single_aggregate, single_states, dispatch_status)
  call require(dispatch_status == FMR_SERIAL_DISPATCH_OK, 'single dispatch status')
  call validate_success_case(1, 1, single_results, single_diag, single_aggregate, single_states)
  call require(column_results_identical(result_for_id(baseline_results, 505001_int64), single_results(1)), &
       'single versus multi result identity')
  call require(committed_fingerprint(baseline_states(1)) == committed_fingerprint(single_states(1)), &
       'single versus multi state identity')
  write(*,'(A)') 'FMR05_SINGLE_VS_MULTI_IDENTITY=PASS'

  call execute_case(8, 3, .false., 4, .false., failure_results, failure_diag, failure_aggregate, &
       failure_states, dispatch_status)
  call require(dispatch_status == FMR_SERIAL_DISPATCH_OK, 'failure-isolation dispatch status')
  call validate_failure_isolation(failure_results, failure_diag, failure_aggregate, failure_states)
  write(*,'(A)') 'FMR05_FAILURE_ISOLATION=PASS'

  call execute_case(2, 2, .false., 0, .true., duplicate_results, duplicate_diag, duplicate_aggregate, &
       duplicate_states, dispatch_status)
  call require(dispatch_status == FMR_SERIAL_DISPATCH_REGISTRY_REJECTED, 'duplicate-state registry rejection')
  call validate_registry_rejection(duplicate_results, duplicate_diag, duplicate_aggregate, duplicate_states)
  write(*,'(A)') 'FMR05_DUPLICATE_STATE_HANDLE_FAIL_CLOSED=PASS'

  call require(baseline_aggregate%workers == 1, 'serialized physical worker count')
  call require(baseline_aggregate%aggregate_unrounded_mass_residual == 0.0_real64, 'aggregate exact mass identity')
  write(*,'(A)') 'FMR05_PHYSICAL_WORKER_COUNT=1'
  write(*,'(A)') 'FMR05_PARALLEL_REFERENCE_BACKEND=NOT_ADMITTED'
  write(*,'(A)') 'FMR05_AUTHORITATIVE_MASS_COMPLETE_ALL_ACCEPTED=PASS'
  write(*,'(A)') 'FMR05_AGGREGATE_UNROUNDED_MASS_RESIDUAL=0x0.0p+0'
  write(*,'(A)') 'FMR05_REAL_HEADCALC_MULTICOLUMN=PASS'
  write(*,'(A)') 'FMR05_SERIALIZED_MULTISWAP_TEST PASS'

contains

  subroutine execute_case(n, batch_size, reverse_order, bad_index, duplicate_state, results, diagnostics, aggregate, &
                          states, dispatch_status)
    integer, intent(in) :: n, batch_size, bad_index
    logical, intent(in) :: reverse_order, duplicate_state
    type(fmr_serialized_column_result_t), allocatable, intent(out) :: results(:)
    type(fmr_column_diagnostics_t), allocatable, intent(out) :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t), intent(out) :: aggregate
    type(kernel_committed_state_t), allocatable, intent(out) :: states(:)
    integer, intent(out) :: dispatch_status

    type(fmr_logical_column_t), allocatable :: columns(:)
    type(fmr_template_t) :: templates(2)
    type(fmr_b110_physical_parameters_t) :: parameters(2)
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:)
    type(fmr_b110_physical_state_t) :: initial_state
    type(fmr04_fixed_flux_top_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    type(fmr_logical_column_t) :: tmp_column
    real(real64) :: conductivity0
    logical :: ok
    integer :: i, left, right

    call configure_templates(templates)
    call configure_parameters(parameters(1), initial_state, conductivity0)
    parameters(2) = parameters(1)
    parameters(2)%parameter_set_id = 50502_int64
    parameters(2)%root_extraction_active = .true.
    call configure_transaction(config)

    allocate(columns(n), forcings(n), states(n))
    do i = 1, n
      columns(i)%column_id = 505000_int64 + int(i, int64)
      if (mod(i,2) == 1) then
        columns(i)%template_id = templates(1)%template_id
      else
        columns(i)%template_id = templates(2)%template_id
      end if
      columns(i)%parameter_ref = 1_int64
      columns(i)%state_handle = int(i, int64)
      columns(i)%forcing_handle = int(i, int64)
      columns(i)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
      call configure_forcing(forcings(i), conductivity0, 1.0_real64 + 0.01_real64*real(i,real64))
      call fmr_new_b110_committed_state(states(i), columns(i)%column_id, initial_state, t0, ok)
      call require(ok, 'case committed-state initialization')
    end do

    if (bad_index >= 1 .and. bad_index <= n) columns(bad_index)%parameter_ref = 2_int64
    if (duplicate_state .and. n >= 2) columns(2)%state_handle = columns(1)%state_handle

    if (reverse_order) then
      do left = 1, n/2
        right = n + 1 - left
        tmp_column = columns(left)
        columns(left) = columns(right)
        columns(right) = tmp_column
      end do
    end if

    legacy_qdra = 12345.0_real64
    legacy_qssdi = -54321.0_real64
    legacy_qrot = 0.0_real64
    swmacro = 0
    melt = 0.0_real64

    call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, states, config, top_provider, &
         t0, t1, batch_size, results, diagnostics, aggregate, dispatch_status)
  end subroutine execute_case

  subroutine configure_templates(templates)
    type(fmr_template_t), intent(out) :: templates(2)

    templates(1)%template_id = 505_int64
    templates(1)%physics_topology_id = 50501_int64
    templates(1)%vertical_layout_id = 50502_int64
    templates(1)%state_layout_id = 50503_int64
    templates(1)%solver_interface_id = 50504_int64
    templates(1)%optional_state_layout_id = 0_int64
    templates(1)%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    templates(2) = templates(1)
    templates(2)%template_id = 506_int64
  end subroutine configure_templates

  subroutine configure_parameters(parameters, state, conductivity0)
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: conductivity0
    type(b110_default_mvg_parameters_t), target :: hyd_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: i

    parameters%parameter_set_id = 50501_int64
    parameters%active_nodes = numnod
    allocate(parameters%z(numnod), parameters%dz(numnod), parameters%node_distance(numnod))
    parameters%z = z
    parameters%dz = dz
    parameters%node_distance = disnod(1:numnod)
    allocate(parameters%cofgen(24,numnod))
    parameters%cofgen = 0.0_real64
    do i = 1, numnod
      parameters%cofgen(1,i) = 0.032_real64
      parameters%cofgen(2,i) = 0.423_real64
      parameters%cofgen(3,i) = 4.75_real64
      parameters%cofgen(4,i) = 0.0135_real64
      parameters%cofgen(5,i) = 0.365_real64
      parameters%cofgen(6,i) = 1.455_real64
      parameters%cofgen(7,i) = 1.0_real64 - 1.0_real64/parameters%cofgen(6,i)
      parameters%cofgen(8,i) = parameters%cofgen(4,i)
      parameters%cofgen(9,i) = 0.0_real64
      parameters%cofgen(10,i) = parameters%cofgen(3,i)
      parameters%cofgen(11,i) = 0.999_real64
      parameters%cofgen(12,i) = 0.99_real64*parameters%cofgen(3,i)
      parameters%cofgen(22,i) = -1.0e6_real64
      parameters%cofgen(23,i) = 1.0e-12_real64
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
    integer :: i

    forcing%top_flux = -conductivity0
    forcing%top_head = head0
    forcing%bottom_flux = -conductivity0
    forcing%bottom_head = -100.0_real64
    allocate(forcing%drainage_flux_by_level(2,numnod), forcing%subsurface_irrigation_source(numnod), &
             forcing%root_extraction_sink(numnod))
    do i = 1, numnod
      forcing%drainage_flux_by_level(1,i) = scale*1.0e-5_real64*real(i,real64)
      forcing%drainage_flux_by_level(2,i) = -scale*2.0e-6_real64*real(i+1,real64)
      forcing%subsurface_irrigation_source(i) = forcing%drainage_flux_by_level(1,i) + &
                                                forcing%drainage_flux_by_level(2,i)
      forcing%root_extraction_sink(i) = 0.0_real64
    end do
  end subroutine configure_forcing

  subroutine configure_transaction(config)
    type(canonical_numerical_config_t), intent(out) :: config
    config%transaction%temporal_tolerance = 0.0_real64
    config%transaction%mass_tolerance = 1.0e-12_real64
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 2
    config%max_committed_substeps = 8
    config%progress_tolerance = 0.0_real64
  end subroutine configure_transaction

  subroutine validate_success_case(n, batch_size, results, diagnostics, aggregate, states)
    integer, intent(in) :: n, batch_size
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    type(fmr_column_diagnostics_t), intent(in) :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t), intent(in) :: aggregate
    type(kernel_committed_state_t), intent(in) :: states(:)
    integer :: i, handle, expected_batches, expected_templates
    logical :: available
    real(real64) :: committed_time

    call require(size(results) == n .and. size(diagnostics) == n .and. size(states) == n, 'success shapes')
    expected_batches = (n + batch_size - 1) / batch_size
    expected_templates = min(n,2)
    call require(aggregate%columns == n, 'aggregate columns')
    call require(aggregate%templates == expected_templates, 'aggregate templates')
    call require(aggregate%batches == expected_batches, 'aggregate batches')
    call require(aggregate%workers == 1, 'aggregate serialized worker')
    call require(aggregate%failures == 0, 'aggregate no failures')
    call require(aggregate%aggregate_unrounded_mass_residual == 0.0_real64, 'aggregate exact residual')

    do i = 1, n
      call require(results(i)%completed .and. results(i)%committed, 'accepted result committed')
      call require(results(i)%mass%complete, 'accepted mass complete')
      call require(results(i)%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, 'accepted missing mask zero')
      call require(results(i)%mass%residual == 0.0_real64, 'accepted exact mass residual')
      call require(results(i)%mass%total_in == results(i)%mass%total_out, 'accepted total in/out identity')
      call require(results(i)%mass%accepted_transaction_count == 1, 'accepted transaction count')
      call require(results(i)%mass%origin_revision == 0_int64, 'accepted origin revision')
      call require(results(i)%mass%origin_lineage_id == results(i)%column_id, 'accepted origin lineage')
      call require(same_real(results(i)%mass%interval_t0,t0) .and. same_real(results(i)%mass%interval_t1,t1), &
           'accepted generic interval provenance')
      call require(results(i)%solver_executed, 'real solver executed')
      call require(trim(results(i)%solver_route) == 'legacy-reference-bound', 'real HeadCalc route')
      call require(results(i)%solver_iterations >= 1, 'solver iterations')
      call require(results(i)%initial_revision == 0_int64 .and. results(i)%final_revision == 1_int64, &
           'transaction revision transition')
      call require(results(i)%final_committed_time_bound .and. same_real(results(i)%final_committed_time,t1), &
           'committed time transition')
      call require(diagnostics(i)%accepted == 1 .and. diagnostics(i)%rejected == 0, 'diagnostic acceptance')
      call require(diagnostics(i)%checkpoint_captures == 1 .and. diagnostics(i)%checkpoint_replays == 1, &
           'checkpoint orchestration')
      call require(trim(diagnostics(i)%failure_classification) == 'NONE', 'no failure classification')
      call require(diagnostics(i)%unrounded_mass_residual == 0.0_real64, 'diagnostic exact residual')
      call require(allocated(diagnostics(i)%worker_assignments), 'worker assignment allocated')
      call require(diagnostics(i)%worker_assignments(1) == 1, 'serialized worker assignment')
      handle = int(results(i)%column_id - 505000_int64)
      call require(handle >= 1 .and. handle <= n, 'column/state handle identity')
      call require(states(handle)%current_revision() == 1_int64, 'state committed exactly once')
      call states(handle)%current_time(committed_time, available)
      call require(available .and. same_real(committed_time,t1), 'state committed time')
    end do
  end subroutine validate_success_case

  subroutine validate_failure_isolation(results, diagnostics, aggregate, states)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    type(fmr_column_diagnostics_t), intent(in) :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t), intent(in) :: aggregate
    type(kernel_committed_state_t), intent(in) :: states(:)
    integer :: i, handle
    integer(int64), parameter :: bad_id = 505004_int64
    logical :: available
    real(real64) :: committed_time

    call require(size(results) == 8, 'failure fixture size')
    call require(aggregate%failures == 1, 'one isolated failure')
    call require(aggregate%aggregate_unrounded_mass_residual == 0.0_real64, 'failure case aggregate residual')
    do i = 1, size(results)
      handle = int(results(i)%column_id - 505000_int64)
      if (results(i)%column_id == bad_id) then
        call require(.not. results(i)%committed .and. .not. results(i)%completed, 'bad column not committed')
        call require(.not. results(i)%solver_executed, 'bad column no physical solve')
        call require(diagnostics(i)%rejected == 1 .and. diagnostics(i)%accepted == 0, 'bad diagnostic rejection')
        call require(trim(diagnostics(i)%failure_classification) == 'KERNEL_REJECTED', 'bad failure classification')
        call require(states(handle)%current_revision() == 0_int64, 'bad state revision unchanged')
        call states(handle)%current_time(committed_time, available)
        call require(available .and. same_real(committed_time,t0), 'bad state time unchanged')
      else
        call require(results(i)%committed .and. results(i)%mass%complete, 'neighbor committed with complete mass')
        call require(results(i)%mass%residual == 0.0_real64, 'neighbor exact residual')
        call require(states(handle)%current_revision() == 1_int64, 'neighbor state survives failure')
      end if
    end do
  end subroutine validate_failure_isolation

  subroutine validate_registry_rejection(results, diagnostics, aggregate, states)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    type(fmr_column_diagnostics_t), intent(in) :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t), intent(in) :: aggregate
    type(kernel_committed_state_t), intent(in) :: states(:)
    integer :: i

    call require(aggregate%batches == 0, 'registry rejection no batches')
    call require(aggregate%failures == size(results), 'registry rejection all failed')
    do i = 1, size(results)
      call require(.not. results(i)%committed, 'registry rejection no commit')
      call require(diagnostics(i)%rejected == 1, 'registry rejection diagnosed')
      call require(trim(diagnostics(i)%failure_classification) == 'REGISTRY_STRUCTURE_REJECTED', &
           'registry failure classification')
      call require(states(i)%current_revision() == 0_int64, 'registry rejection state unchanged')
    end do
  end subroutine validate_registry_rejection

  logical function result_sets_identical(left, right) result(equal)
    type(fmr_serialized_column_result_t), intent(in) :: left(:), right(:)
    integer :: i, j

    equal = size(left) == size(right)
    if (.not. equal) return
    do i = 1, size(left)
      j = result_index(right, left(i)%column_id)
      if (j == 0) then
        equal = .false.
        return
      end if
      if (.not. column_results_identical(left(i), right(j))) then
        equal = .false.
        return
      end if
    end do
  end function result_sets_identical

  logical function column_results_identical(left, right) result(equal)
    type(fmr_serialized_column_result_t), intent(in) :: left, right

    equal = left%column_id == right%column_id .and. left%kernel_status == right%kernel_status .and. &
         left%commit_status == right%commit_status .and. left%completed .eqv. right%completed .and. &
         left%committed .eqv. right%committed .and. left%solver_executed .eqv. right%solver_executed .and. &
         trim(left%solver_route) == trim(right%solver_route) .and. left%solver_iterations == right%solver_iterations .and. &
         left%initial_revision == right%initial_revision .and. left%final_revision == right%final_revision .and. &
         left%final_committed_time_bound .eqv. right%final_committed_time_bound .and. &
         same_bits(left%final_committed_time,right%final_committed_time) .and. &
         left%mass%complete .eqv. right%mass%complete .and. &
         left%mass%missing_contribution_mask == right%mass%missing_contribution_mask .and. &
         left%mass%origin_lineage_id == right%mass%origin_lineage_id .and. &
         left%mass%origin_revision == right%mass%origin_revision .and. &
         left%mass%accepted_transaction_count == right%mass%accepted_transaction_count .and. &
         same_bits(left%mass%interval_t0,right%mass%interval_t0) .and. &
         same_bits(left%mass%interval_t1,right%mass%interval_t1) .and. &
         same_bits(left%mass%storage_start,right%mass%storage_start) .and. &
         same_bits(left%mass%storage_end,right%mass%storage_end) .and. &
         same_bits(left%mass%storage_change,right%mass%storage_change) .and. &
         same_bits(left%mass%total_in,right%mass%total_in) .and. &
         same_bits(left%mass%total_out,right%mass%total_out) .and. &
         same_bits(left%mass%residual,right%mass%residual)
  end function column_results_identical

  function result_for_id(results, column_id) result(value)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    integer(int64), intent(in) :: column_id
    type(fmr_serialized_column_result_t) :: value
    integer :: index

    index = result_index(results, column_id)
    call require(index > 0, 'result id lookup')
    value = results(index)
  end function result_for_id

  integer function result_index(results, column_id) result(index)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    integer(int64), intent(in) :: column_id
    integer :: i

    index = 0
    do i = 1, size(results)
      if (results(i)%column_id == column_id) then
        index = i
        return
      end if
    end do
  end function result_index

  logical function state_sets_identical(left, right) result(equal)
    type(kernel_committed_state_t), intent(in) :: left(:), right(:)
    integer :: i

    equal = size(left) == size(right)
    if (.not. equal) return
    do i = 1, size(left)
      if (left(i)%current_lineage_id() /= right(i)%current_lineage_id() .or. &
          left(i)%current_revision() /= right(i)%current_revision() .or. &
          committed_fingerprint(left(i)) /= committed_fingerprint(right(i))) then
        equal = .false.
        return
      end if
    end do
  end function state_sets_identical

  integer(int64) function committed_fingerprint(state) result(fp)
    type(kernel_committed_state_t), intent(in) :: state
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    integer :: i

    call state%snapshot(snapshot, got)
    call require(got, 'committed snapshot')
    fp = 1469598103934665603_int64
    select type (physical => snapshot)
    type is (fmr_b110_physical_state_t)
      fp = ieor(fp, int(physical%active_nodes,int64))
      do i = 1, physical%active_nodes
        fp = ieor(fp, transfer(physical%pressure_head(i),fp))
        fp = ieor(fp, transfer(physical%water_content(i),fp))
      end do
      fp = ieor(fp, transfer(physical%ponding_depth,fp))
      fp = ieor(fp, transfer(physical%groundwater_level,fp))
    class default
      error stop 'F-MR05 unexpected physical state type'
    end select
  end function committed_fingerprint

  logical function same_bits(a,b)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia, ib
    ia = transfer(a,ia)
    ib = transfer(b,ib)
    same_bits = ia == ib
  end function same_bits

  logical function same_real(a,b)
    real(real64), intent(in) :: a,b
    real(real64) :: scale
    scale = max(1.0_real64,abs(a),abs(b))
    same_real = abs(a-b) <= 16.0_real64*epsilon(1.0_real64)*scale
  end function same_real

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FMR05_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fmr05_serialized_multiswap
