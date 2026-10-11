program test_fgc25_multiswap_qualification
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_head_datum_t
  use mod_groundwater_coupling_policy, only: groundwater_head_convergence_policy_t
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, &
       groundwater_interface_mass_snapshot_t, GW_MASS_LEDGER_OK
  use mod_groundwater_predictor_corrector_window, only: groundwater_coupling_origin_t
  use mod_groundwater_multiswap_types, only: groundwater_direct_tile_binding_t, groundwater_multiswap_result_t, &
       GW_MULTI_OK, GW_MULTI_CORRECTOR_GROUNDWATER_FAILED
  use mod_groundwater_multiswap_coupler, only: run_restricted_groundwater_multiswap_cell_window
  use mod_fgc21_restricted_predictor_corrector_owner_test, only: dummy_model_t, dummy_parameters_t, &
       dummy_materializer_t, dummy_groundwater_service_t, check, check_close
  use mod_fgc25_multiswap_fixture, only: setup_fgc25_two_tiles
  implicit none

  integer :: failures

  failures = 0
  call test_corrector_groundwater_failure_is_cell_atomic(failures)
  call test_tile_input_permutation_is_deterministic(failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'F-GC25 MULTISWAP QUALIFICATION FAILURES=', failures
    error stop 1
  end if
  write(*,'(A)') 'F-GC25 MULTISWAP QUALIFICATION PASS'

contains

  subroutine test_corrector_groundwater_failure_is_cell_atomic(failures)
    integer, intent(inout) :: failures
    type(kernel_executor_t) :: executor
    type(kernel_committed_state_t) :: committed(2)
    type(dummy_model_t), target :: model
    type(dummy_parameters_t) :: parameters(2)
    type(dummy_materializer_t) :: materializer
    type(dummy_groundwater_service_t) :: groundwater
    type(groundwater_interface_mass_ledger_t) :: ledgers(2)
    type(groundwater_head_datum_t) :: datum
    type(groundwater_head_convergence_policy_t) :: policy
    type(groundwater_coupling_window_t) :: window
    type(groundwater_coupling_origin_t) :: origins(2)
    type(groundwater_direct_tile_binding_t) :: bindings(2)
    type(groundwater_multiswap_result_t) :: result
    type(canonical_numerical_config_t) :: numerical
    type(groundwater_interface_mass_snapshot_t) :: snap
    integer :: status, i

    call setup_fgc25_two_tiles(executor, model, parameters, groundwater, ledgers, datum, policy, window, origins, &
         numerical, committed, bindings, status)
    call check(status == GW_MASS_LEDGER_OK, 'corrector-fail: setup', failures)

    ! Trial 1 is the predictor groundwater response. Reject trial 2 only after
    ! both predictor and both corrector SWAP trajectories have materialized.
    groundwater%fail_trial_number = 2
    call run_restricted_groundwater_multiswap_cell_window(executor, parameters, committed, bindings, materializer, &
         numerical, groundwater, ledgers, datum, policy, window, origins, result)

    call check(result%status == GW_MULTI_CORRECTOR_GROUNDWATER_FAILED, &
         'corrector-fail: explicit status', failures)
    call check(result%request_smaller_window .and. .not. result%committed, &
         'corrector-fail: cell transaction rejected', failures)
    call check(model%advance_count == 4, &
         'corrector-fail: both predictor and corrector tile trajectories ran', failures)
    call check(groundwater%trial_count == 1, &
         'corrector-fail: rejected second groundwater trial was not accepted', failures)
    call check(groundwater%revision == 0_int64 .and. groundwater%commit_count == 0, &
         'corrector-fail: groundwater committed state unchanged', failures)

    do i = 1, 2
      call check(committed(i)%current_revision() == 0_int64, &
           'corrector-fail: no SWAP tile published', failures)
      call check(origins(i)%swap_revision == 0_int64 .and. origins(i)%groundwater_revision == 0_int64, &
           'corrector-fail: coupling origin unchanged', failures)
      call ledgers(i)%snapshot(snap)
      call check(snap%committed_exchange_count == 0, &
           'corrector-fail: no tile ledger publication', failures)
      call check(.not. snap%trial_active .and. .not. snap%prepared_active, &
           'corrector-fail: no transient ledger state leaked', failures)
      call check(snap%conservation_residual_m == 0.0_real64, &
           'corrector-fail: ledger remains exactly conservative', failures)
    end do
  end subroutine test_corrector_groundwater_failure_is_cell_atomic

  subroutine test_tile_input_permutation_is_deterministic(failures)
    integer, intent(inout) :: failures
    type(kernel_executor_t) :: executor_a, executor_b
    type(kernel_committed_state_t) :: committed_a(2), committed_b(2), tmp_committed
    type(dummy_model_t), target :: model_a, model_b
    type(dummy_parameters_t) :: parameters_a(2), parameters_b(2), tmp_parameters
    type(dummy_materializer_t) :: materializer
    type(dummy_groundwater_service_t) :: groundwater_a, groundwater_b
    type(groundwater_interface_mass_ledger_t) :: ledgers_a(2), ledgers_b(2), tmp_ledger
    type(groundwater_head_datum_t) :: datum_a, datum_b
    type(groundwater_head_convergence_policy_t) :: policy_a, policy_b
    type(groundwater_coupling_window_t) :: window_a, window_b
    type(groundwater_coupling_origin_t) :: origins_a(2), origins_b(2), tmp_origin
    type(groundwater_direct_tile_binding_t) :: bindings_a(2), bindings_b(2), tmp_binding
    type(groundwater_multiswap_result_t) :: result_a, result_b
    type(canonical_numerical_config_t) :: numerical_a, numerical_b
    type(groundwater_interface_mass_snapshot_t) :: snap_a, snap_b
    integer :: status_a, status_b, i, j

    call setup_fgc25_two_tiles(executor_a, model_a, parameters_a, groundwater_a, ledgers_a, datum_a, policy_a, &
         window_a, origins_a, numerical_a, committed_a, bindings_a, status_a)
    call setup_fgc25_two_tiles(executor_b, model_b, parameters_b, groundwater_b, ledgers_b, datum_b, policy_b, &
         window_b, origins_b, numerical_b, committed_b, bindings_b, status_b)
    call check(status_a == GW_MASS_LEDGER_OK .and. status_b == GW_MASS_LEDGER_OK, &
         'permutation: setup', failures)

    ! Reverse the complete tile association, not just the mapping metadata. The
    ! physical problem is identical; only caller input order changes.
    tmp_committed = committed_b(1)
    committed_b(1) = committed_b(2)
    committed_b(2) = tmp_committed
    tmp_parameters = parameters_b(1)
    parameters_b(1) = parameters_b(2)
    parameters_b(2) = tmp_parameters
    tmp_ledger = ledgers_b(1)
    ledgers_b(1) = ledgers_b(2)
    ledgers_b(2) = tmp_ledger
    tmp_origin = origins_b(1)
    origins_b(1) = origins_b(2)
    origins_b(2) = tmp_origin
    tmp_binding = bindings_b(1)
    bindings_b(1) = bindings_b(2)
    bindings_b(2) = tmp_binding

    call run_restricted_groundwater_multiswap_cell_window(executor_a, parameters_a, committed_a, bindings_a, &
         materializer, numerical_a, groundwater_a, ledgers_a, datum_a, policy_a, window_a, origins_a, result_a)
    call run_restricted_groundwater_multiswap_cell_window(executor_b, parameters_b, committed_b, bindings_b, &
         materializer, numerical_b, groundwater_b, ledgers_b, datum_b, policy_b, window_b, origins_b, result_b)

    call check(result_a%status == GW_MULTI_OK .and. result_b%status == GW_MULTI_OK, &
         'permutation: both routes accepted', failures)
    call check(result_a%committed .and. result_b%committed, &
         'permutation: both routes committed', failures)
    call check(transfer(result_a%accepted_cell_exchange_m, 0_int64) == &
         transfer(result_b%accepted_cell_exchange_m, 0_int64), &
         'permutation: accepted cell exchange bit-identical', failures)
    call check(transfer(groundwater_a%last_q_groundwater_m_per_s, 0_int64) == &
         transfer(groundwater_b%last_q_groundwater_m_per_s, 0_int64), &
         'permutation: groundwater forcing bit-identical', failures)
    call check_close(result_a%committed_ledger_increment_m, result_b%committed_ledger_increment_m, &
         0.0_real64, 'permutation: cell ledger increment identical', failures)
    call check(groundwater_a%revision == groundwater_b%revision .and. groundwater_a%revision == 1_int64, &
         'permutation: groundwater revision identical', failures)

    do i = 1, 2
      j = 3 - i
      call check(bindings_a(i)%tile_id == bindings_b(j)%tile_id, &
           'permutation: tile identity remapped correctly', failures)
      call check(committed_a(i)%current_lineage_id() == committed_b(j)%current_lineage_id(), &
           'permutation: SWAP lineage preserved by tile identity', failures)
      call check(committed_a(i)%current_revision() == committed_b(j)%current_revision(), &
           'permutation: SWAP revision invariant', failures)
      call check(origins_a(i)%swap_lineage_id == origins_b(j)%swap_lineage_id .and. &
           origins_a(i)%swap_revision == origins_b(j)%swap_revision, &
           'permutation: coupling provenance invariant', failures)
      call check_close(result_a%tile_weighted_exchange_m(i), result_b%tile_weighted_exchange_m(j), &
           0.0_real64, 'permutation: per-tile weighted exchange invariant', failures)
      call ledgers_a(i)%snapshot(snap_a)
      call ledgers_b(j)%snapshot(snap_b)
      call check_close(snap_a%committed_swap_outward_exchange_m, snap_b%committed_swap_outward_exchange_m, &
           0.0_real64, 'permutation: per-tile ledger invariant', failures)
      call check(snap_a%conservation_residual_m == 0.0_real64 .and. snap_b%conservation_residual_m == 0.0_real64, &
           'permutation: exact per-tile conservation', failures)
    end do
  end subroutine test_tile_input_permutation_is_deterministic

end program test_fgc25_multiswap_qualification
