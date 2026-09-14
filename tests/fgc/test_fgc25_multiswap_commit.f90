program test_fgc25_multiswap_commit
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_head_datum_t
  use mod_groundwater_coupling_policy, only: groundwater_head_convergence_policy_t
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, &
       groundwater_interface_mass_snapshot_t, GW_MASS_LEDGER_OK
  use mod_groundwater_predictor_corrector_window, only: groundwater_coupling_origin_t
  use mod_groundwater_multiswap_types, only: groundwater_direct_tile_binding_t, groundwater_multiswap_result_t, &
       GW_MULTI_OK, GW_MULTI_PREDICTOR_GROUNDWATER_FAILED
  use mod_groundwater_multiswap_coupler, only: run_restricted_groundwater_multiswap_cell_window
  use mod_fgc21_restricted_predictor_corrector_owner_test, only: dummy_model_t, dummy_parameters_t, &
       dummy_materializer_t, dummy_groundwater_service_t, check, check_close
  use mod_fgc25_multiswap_fixture, only: setup_fgc25_two_tiles
  implicit none

  integer :: failures

  failures = 0
  call test_two_tile_commit(failures)
  call test_predictor_groundwater_failure(failures)
  if (failures /= 0) then
    write(*,'(A,I0)') 'F-GC25 MULTISWAP COMMIT FAILURES=', failures
    error stop 1
  end if
  write(*,'(A)') 'F-GC25 MULTISWAP COMMIT PASS'

contains

  subroutine test_two_tile_commit(failures)
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
    real(real64) :: exchange_cm, expected_cell_m
    integer :: status, i

    call setup_fgc25_two_tiles(executor, model, parameters, groundwater, ledgers, datum, policy, window, origins, &
         numerical, committed, bindings, status)
    call check(status == GW_MASS_LEDGER_OK, 'two-tile: setup', failures)

    call run_restricted_groundwater_multiswap_cell_window(executor, parameters, committed, bindings, materializer, &
         numerical, groundwater, ledgers, datum, policy, window, origins, result)

    exchange_cm = (0.2_real64 + 0.01_real64 * 0.5_real64) * (window%t1 - window%t0)
    expected_cell_m = exchange_cm * 0.01_real64
    call check(result%status == GW_MULTI_OK, 'two-tile: status OK', failures)
    call check(result%completed .and. result%committed, 'two-tile: committed', failures)
    call check(model%advance_count == 4, 'two-tile: four SWAP trajectories', failures)
    call check(groundwater%trial_count == 2, 'two-tile: two groundwater trials', failures)
    call check(groundwater%commit_count == 1, 'two-tile: one groundwater commit', failures)
    call check_close(result%accepted_cell_exchange_m, expected_cell_m, 1.0e-15_real64, &
         'two-tile: area-weighted cell exchange', failures)
    call check_close(result%committed_ledger_increment_m, expected_cell_m, 1.0e-15_real64, &
         'two-tile: ledger increment equals cell exchange', failures)
    call check_close(result%tile_weighted_exchange_m(1), 0.25_real64 * expected_cell_m, 1.0e-16_real64, &
         'two-tile: first ledger fraction', failures)
    call check_close(result%tile_weighted_exchange_m(2), 0.75_real64 * expected_cell_m, 1.0e-16_real64, &
         'two-tile: second ledger fraction', failures)
    call check(result%residual%flux_residual_m_per_s == 0.0_real64, &
         'two-tile: exact action reaction', failures)

    do i = 1, 2
      call check(committed(i)%current_revision() == 1_int64, 'two-tile: SWAP revision advanced', failures)
      call check(origins(i)%swap_revision == 1_int64 .and. origins(i)%groundwater_revision == 1_int64, &
           'two-tile: coupling origin advanced', failures)
      call ledgers(i)%snapshot(snap)
      call check(snap%committed_exchange_count == 1, 'two-tile: tile ledger committed', failures)
      call check(snap%conservation_residual_m == 0.0_real64, 'two-tile: exact tile mass closure', failures)
    end do
  end subroutine test_two_tile_commit

  subroutine test_predictor_groundwater_failure(failures)
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
    groundwater%fail_trial_number = 1
    call run_restricted_groundwater_multiswap_cell_window(executor, parameters, committed, bindings, materializer, &
         numerical, groundwater, ledgers, datum, policy, window, origins, result)

    call check(result%status == GW_MULTI_PREDICTOR_GROUNDWATER_FAILED, &
         'predictor-fail: explicit status', failures)
    call check(result%request_smaller_window .and. .not. result%committed, &
         'predictor-fail: fail closed', failures)
    call check(model%advance_count == 2, 'predictor-fail: both predictor tiles trialled', failures)
    call check(groundwater%revision == 0_int64 .and. groundwater%commit_count == 0, &
         'predictor-fail: groundwater unchanged', failures)
    do i = 1, 2
      call check(committed(i)%current_revision() == 0_int64, 'predictor-fail: SWAP unchanged', failures)
      call ledgers(i)%snapshot(snap)
      call check(snap%committed_exchange_count == 0 .and. .not. snap%trial_active .and. .not. snap%prepared_active, &
           'predictor-fail: ledger untouched', failures)
    end do
  end subroutine test_predictor_groundwater_failure

end program test_fgc25_multiswap_commit
