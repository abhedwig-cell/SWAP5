program test_fvq87_fgc25_multiswap_independent
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_head_datum_t
  use mod_groundwater_coupling_policy, only: groundwater_head_convergence_policy_t
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, &
       groundwater_interface_mass_snapshot_t, GW_MASS_LEDGER_OK
  use mod_groundwater_predictor_corrector_window, only: groundwater_coupling_origin_t
  use mod_groundwater_multiswap_types, only: groundwater_direct_tile_binding_t, groundwater_multiswap_result_t, &
       GW_MULTI_OK, GW_MULTI_INVALID_REQUEST, GW_MULTI_INVALID_ORIGIN, GW_MULTI_NOT_CONVERGED, &
       GW_MULTI_GROUNDWATER_PREPARE_FAILED
  use mod_groundwater_multiswap_coupler, only: run_restricted_groundwater_multiswap_cell_window
  use mod_fgc21_restricted_predictor_corrector_owner_test, only: dummy_model_t, dummy_parameters_t, &
       dummy_materializer_t, dummy_groundwater_service_t
  use mod_fgc25_multiswap_fixture, only: setup_fgc25_two_tiles
  implicit none

  integer :: failures

  failures = 0
  call test_prepare_rejection_is_prepublication_atomic(failures)
  call test_duplicate_tile_rejected_before_trials(failures)
  call test_stale_tile_origin_rejected_before_trials(failures)
  call test_nonconvergence_rolls_back_entire_cell(failures)
  call test_weighted_mass_and_action_reaction(failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'FVQ87_FAILURES=', failures
    error stop 1
  end if

  write(*,'(A)') 'FVQ87_PREPARE_REJECTION_ATOMICITY=PASS'
  write(*,'(A)') 'FVQ87_DUPLICATE_TILE_PRETRIAL_REJECTION=PASS'
  write(*,'(A)') 'FVQ87_STALE_ORIGIN_PRETRIAL_REJECTION=PASS'
  write(*,'(A)') 'FVQ87_NONCONVERGED_CELL_ROLLBACK=PASS'
  write(*,'(A)') 'FVQ87_WEIGHTED_MASS_ACTION_REACTION=PASS'
  write(*,'(A)') 'FVQ87_INDEPENDENT_ORACLE=PASS'

contains

  subroutine require(condition, label, failures)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures

    if (.not. condition) then
      failures = failures + 1
      write(*,'(A,A)') 'FVQ87_ASSERT_FAIL=', trim(label)
    end if
  end subroutine require

  subroutine require_close(actual, expected, tolerance, label, failures)
    real(real64), intent(in) :: actual, expected, tolerance
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures

    call require(abs(actual - expected) <= tolerance, label, failures)
  end subroutine require_close

  logical function origin_unchanged(actual, expected) result(same)
    type(groundwater_coupling_origin_t), intent(in) :: actual, expected

    same = actual%initialized .eqv. expected%initialized
    same = same .and. actual%coupling_id == expected%coupling_id
    same = same .and. transfer(actual%accepted_h_groundwater_m, 0_int64) == &
         transfer(expected%accepted_h_groundwater_m, 0_int64)
    same = same .and. transfer(actual%accepted_time, 0_int64) == transfer(expected%accepted_time, 0_int64)
    same = same .and. actual%swap_lineage_id == expected%swap_lineage_id
    same = same .and. actual%swap_revision == expected%swap_revision
    same = same .and. actual%groundwater_service_id == expected%groundwater_service_id
    same = same .and. actual%groundwater_lineage_id == expected%groundwater_lineage_id
    same = same .and. actual%groundwater_revision == expected%groundwater_revision
  end function origin_unchanged

  subroutine require_cell_unpublished(committed, ledgers, origins, original_origins, groundwater, label, failures)
    type(kernel_committed_state_t), intent(in) :: committed(2)
    type(groundwater_interface_mass_ledger_t), intent(in) :: ledgers(2)
    type(groundwater_coupling_origin_t), intent(in) :: origins(2), original_origins(2)
    type(dummy_groundwater_service_t), intent(in) :: groundwater
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    type(groundwater_interface_mass_snapshot_t) :: snapshot
    integer :: i

    call require(groundwater%revision == 0_int64, trim(label)//': groundwater revision unchanged', failures)
    call require(groundwater%commit_count == 0, trim(label)//': no groundwater commit', failures)
    call require(groundwater%restart_quiescent(), trim(label)//': no groundwater reservation leaked', failures)

    do i = 1, 2
      call require(committed(i)%current_revision() == 0_int64, &
           trim(label)//': SWAP revision unchanged', failures)
      call require(origin_unchanged(origins(i), original_origins(i)), &
           trim(label)//': coupling origin unchanged', failures)
      call ledgers(i)%snapshot(snapshot)
      call require(snapshot%available, trim(label)//': ledger snapshot available', failures)
      call require(snapshot%committed_exchange_count == 0, trim(label)//': no ledger commit', failures)
      call require(.not. snapshot%trial_active, trim(label)//': no active ledger trial', failures)
      call require(.not. snapshot%prepared_active, trim(label)//': no prepared ledger state', failures)
      call require(transfer(snapshot%conservation_residual_m, 0_int64) == transfer(0.0_real64, 0_int64), &
           trim(label)//': ledger conservation remains exact', failures)
    end do
  end subroutine require_cell_unpublished

  subroutine test_prepare_rejection_is_prepublication_atomic(failures)
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
    type(groundwater_coupling_origin_t) :: origins(2), original_origins(2)
    type(groundwater_direct_tile_binding_t) :: bindings(2)
    type(groundwater_multiswap_result_t) :: result
    type(canonical_numerical_config_t) :: numerical
    integer :: status

    call setup_fgc25_two_tiles(executor, model, parameters, groundwater, ledgers, datum, policy, window, origins, &
         numerical, committed, bindings, status)
    call require(status == GW_MASS_LEDGER_OK, 'prepare-reject: setup', failures)
    original_origins = origins
    groundwater%fail_prepare = .true.

    call run_restricted_groundwater_multiswap_cell_window(executor, parameters, committed, bindings, materializer, &
         numerical, groundwater, ledgers, datum, policy, window, origins, result)

    call require(result%status == GW_MULTI_GROUNDWATER_PREPARE_FAILED, &
         'prepare-reject: explicit status', failures)
    call require(result%request_smaller_window, 'prepare-reject: shrink requested', failures)
    call require(.not. result%committed .and. .not. result%completed, &
         'prepare-reject: no coupled commit', failures)
    call require(model%advance_count == 4, 'prepare-reject: failure occurs after both phases', failures)
    call require(groundwater%trial_count == 2, 'prepare-reject: both groundwater trials completed', failures)
    call require(groundwater%prepare_count == 0, 'prepare-reject: backend prepare rejected', failures)
    call require(.not. result%diagnostics%publication_preflight_passed, &
         'prepare-reject: publication preflight never passed', failures)
    call require_cell_unpublished(committed, ledgers, origins, original_origins, groundwater, &
         'prepare-reject', failures)
  end subroutine test_prepare_rejection_is_prepublication_atomic

  subroutine test_duplicate_tile_rejected_before_trials(failures)
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
    type(groundwater_coupling_origin_t) :: origins(2), original_origins(2)
    type(groundwater_direct_tile_binding_t) :: bindings(2)
    type(groundwater_multiswap_result_t) :: result
    type(canonical_numerical_config_t) :: numerical
    integer :: status

    call setup_fgc25_two_tiles(executor, model, parameters, groundwater, ledgers, datum, policy, window, origins, &
         numerical, committed, bindings, status)
    call require(status == GW_MASS_LEDGER_OK, 'duplicate-tile: setup', failures)
    original_origins = origins
    bindings(2)%tile_id = bindings(1)%tile_id

    call run_restricted_groundwater_multiswap_cell_window(executor, parameters, committed, bindings, materializer, &
         numerical, groundwater, ledgers, datum, policy, window, origins, result)

    call require(result%status == GW_MULTI_INVALID_REQUEST, 'duplicate-tile: invalid request', failures)
    call require(.not. result%request_smaller_window, 'duplicate-tile: structural rejection is not retry', failures)
    call require(model%advance_count == 0, 'duplicate-tile: no SWAP trial', failures)
    call require(groundwater%capture_count == 0 .and. groundwater%trial_count == 0, &
         'duplicate-tile: no groundwater work', failures)
    call require_cell_unpublished(committed, ledgers, origins, original_origins, groundwater, &
         'duplicate-tile', failures)
  end subroutine test_duplicate_tile_rejected_before_trials

  subroutine test_stale_tile_origin_rejected_before_trials(failures)
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
    type(groundwater_coupling_origin_t) :: origins(2), expected_origins(2)
    type(groundwater_direct_tile_binding_t) :: bindings(2)
    type(groundwater_multiswap_result_t) :: result
    type(canonical_numerical_config_t) :: numerical
    integer :: status

    call setup_fgc25_two_tiles(executor, model, parameters, groundwater, ledgers, datum, policy, window, origins, &
         numerical, committed, bindings, status)
    call require(status == GW_MASS_LEDGER_OK, 'stale-origin: setup', failures)
    origins(2)%swap_revision = origins(2)%swap_revision + 1_int64
    expected_origins = origins

    call run_restricted_groundwater_multiswap_cell_window(executor, parameters, committed, bindings, materializer, &
         numerical, groundwater, ledgers, datum, policy, window, origins, result)

    call require(result%status == GW_MULTI_INVALID_ORIGIN, 'stale-origin: invalid origin', failures)
    call require(.not. result%request_smaller_window, 'stale-origin: provenance rejection is not retry', failures)
    call require(model%advance_count == 0, 'stale-origin: no SWAP trial', failures)
    call require(groundwater%capture_count == 0 .and. groundwater%trial_count == 0, &
         'stale-origin: no groundwater work', failures)
    call require_cell_unpublished(committed, ledgers, origins, expected_origins, groundwater, &
         'stale-origin', failures)
  end subroutine test_stale_tile_origin_rejected_before_trials

  subroutine test_nonconvergence_rolls_back_entire_cell(failures)
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
    type(groundwater_coupling_origin_t) :: origins(2), original_origins(2)
    type(groundwater_direct_tile_binding_t) :: bindings(2)
    type(groundwater_multiswap_result_t) :: result
    type(canonical_numerical_config_t) :: numerical
    integer :: status

    call setup_fgc25_two_tiles(executor, model, parameters, groundwater, ledgers, datum, policy, window, origins, &
         numerical, committed, bindings, status)
    call require(status == GW_MASS_LEDGER_OK, 'nonconverged: setup', failures)
    original_origins = origins
    groundwater%response_mode = 1

    call run_restricted_groundwater_multiswap_cell_window(executor, parameters, committed, bindings, materializer, &
         numerical, groundwater, ledgers, datum, policy, window, origins, result)

    call require(result%status == GW_MULTI_NOT_CONVERGED, 'nonconverged: explicit status', failures)
    call require(result%request_smaller_window, 'nonconverged: shrink requested', failures)
    call require(.not. result%committed .and. .not. result%completed, &
         'nonconverged: no coupled commit', failures)
    call require(model%advance_count == 4, 'nonconverged: bounded predictor plus corrector work', failures)
    call require(groundwater%trial_count == 2 .and. groundwater%discard_count == 2, &
         'nonconverged: both groundwater candidates discarded', failures)
    call require(groundwater%prepare_count == 0, 'nonconverged: no prepare publication', failures)
    call require_cell_unpublished(committed, ledgers, origins, original_origins, groundwater, &
         'nonconverged', failures)
  end subroutine test_nonconvergence_rolls_back_entire_cell

  subroutine test_weighted_mass_and_action_reaction(failures)
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
    type(groundwater_interface_mass_snapshot_t) :: snapshot
    real(real64) :: ledger_total
    integer :: status, i

    call setup_fgc25_two_tiles(executor, model, parameters, groundwater, ledgers, datum, policy, window, origins, &
         numerical, committed, bindings, status)
    call require(status == GW_MASS_LEDGER_OK, 'weighted-mass: setup', failures)
    bindings(1)%area_fraction = 0.4_real64
    bindings(2)%area_fraction = 0.6_real64

    call run_restricted_groundwater_multiswap_cell_window(executor, parameters, committed, bindings, materializer, &
         numerical, groundwater, ledgers, datum, policy, window, origins, result)

    call require(result%status == GW_MULTI_OK .and. result%committed, &
         'weighted-mass: transaction committed', failures)
    call require(model%advance_count == 4, 'weighted-mass: bounded SWAP work', failures)
    call require(groundwater%trial_count == 2 .and. groundwater%commit_count == 1, &
         'weighted-mass: one groundwater publication', failures)
    call require_close(result%tile_weighted_exchange_m(1), &
         0.4_real64 * result%accepted_cell_exchange_m, 1.0e-16_real64, &
         'weighted-mass: tile one area weighting', failures)
    call require_close(result%tile_weighted_exchange_m(2), &
         0.6_real64 * result%accepted_cell_exchange_m, 1.0e-16_real64, &
         'weighted-mass: tile two area weighting', failures)
    call require(transfer(result%residual%flux_residual_m_per_s, 0_int64) == transfer(0.0_real64, 0_int64), &
         'weighted-mass: exact action reaction', failures)

    ledger_total = 0.0_real64
    do i = 1, 2
      call ledgers(i)%snapshot(snapshot)
      call require(snapshot%committed_exchange_count == 1, 'weighted-mass: one tile ledger commit', failures)
      call require_close(snapshot%committed_swap_outward_exchange_m, result%tile_weighted_exchange_m(i), &
           1.0e-16_real64, 'weighted-mass: ledger equals weighted tile transfer', failures)
      call require(transfer(snapshot%conservation_residual_m, 0_int64) == transfer(0.0_real64, 0_int64), &
           'weighted-mass: exact per-tile conservation', failures)
      ledger_total = ledger_total + snapshot%committed_swap_outward_exchange_m
    end do
    call require_close(ledger_total, result%accepted_cell_exchange_m, 1.0e-16_real64, &
         'weighted-mass: cell ledger sum equals accepted exchange', failures)
    call require_close(result%committed_ledger_increment_m, result%accepted_cell_exchange_m, 1.0e-16_real64, &
         'weighted-mass: committed increment equals accepted exchange', failures)
  end subroutine test_weighted_mass_and_action_reaction

end program test_fvq87_fgc25_multiswap_independent
