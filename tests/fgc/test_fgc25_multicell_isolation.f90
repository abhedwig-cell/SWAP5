program test_fgc25_multicell_isolation
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
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
  use mod_fgc21_restricted_predictor_corrector_owner_test, only: dummy_state_t, dummy_model_t, dummy_parameters_t, &
       dummy_materializer_t, dummy_groundwater_service_t, check, check_close
  use mod_fgc25_multiswap_fixture, only: setup_fgc25_two_tiles
  implicit none

  type(kernel_executor_t) :: executor_a, executor_b
  type(kernel_committed_state_t) :: committed_a(2), committed_b(2)
  type(dummy_model_t), target :: model_a, model_b
  type(dummy_parameters_t) :: parameters_a(2), parameters_b(2)
  type(dummy_materializer_t) :: materializer
  type(dummy_groundwater_service_t) :: groundwater_a, groundwater_b
  type(groundwater_interface_mass_ledger_t) :: ledgers_a(2), ledgers_b(2)
  type(groundwater_head_datum_t) :: datum_a, datum_b
  type(groundwater_head_convergence_policy_t) :: policy_a, policy_b
  type(groundwater_coupling_window_t) :: window_a, window_b
  type(groundwater_coupling_origin_t) :: origins_a(2), origins_b(2)
  type(groundwater_direct_tile_binding_t) :: bindings_a(2), bindings_b(2)
  type(groundwater_multiswap_result_t) :: result_a, result_b
  type(canonical_numerical_config_t) :: numerical_a, numerical_b
  type(groundwater_interface_mass_snapshot_t) :: snap
  class(transaction_state_t), allocatable :: physical
  real(real64) :: cell_a_storage_after_commit(2), expected_storage
  integer :: failures, status_a, status_b, ledger_status, i
  logical :: initialized, snapshot_available

  failures = 0
  call setup_fgc25_two_tiles(executor_a, model_a, parameters_a, groundwater_a, ledgers_a, datum_a, policy_a, &
       window_a, origins_a, numerical_a, committed_a, bindings_a, status_a)
  call setup_fgc25_two_tiles(executor_b, model_b, parameters_b, groundwater_b, ledgers_b, datum_b, policy_b, &
       window_b, origins_b, numerical_b, committed_b, bindings_b, status_b)
  call check(status_a == GW_MASS_LEDGER_OK .and. status_b == GW_MASS_LEDGER_OK, 'multicell: setup', failures)

  ! Re-identify the second fixture as a genuinely independent groundwater cell.
  ! The actual execution below deliberately reuses executor_a/model_a for both
  ! cells; executor_b/model_b only supplied convenient independent fixture state.
  groundwater_b%service_id_value = 1701_int64
  groundwater_b%lineage_id_value = 1801_int64
  do i = 1, 2
    committed_b(i) = kernel_committed_state_t()
    allocate(dummy_state_t :: physical)
    select type (typed_physical => physical)
    type is (dummy_state_t)
      typed_physical%storage = 20.0_real64 + real(i, real64)
    end select
    call committed_b(i)%initialize(1900_int64 + int(i, int64), physical, initialized, initial_time=window_b%t0)
    call check(initialized, 'multicell: second-cell committed state initialized', failures)
    deallocate(physical)

    ledgers_b(i) = groundwater_interface_mass_ledger_t()
    call ledgers_b(i)%bind_identity(2000_int64 + int(i, int64), ledger_status)
    call check(ledger_status == GW_MASS_LEDGER_OK, 'multicell: second-cell ledger identity', failures)

    bindings_b(i)%groundwater_cell_id = 7002_int64
    bindings_b(i)%tile_id = 300_int64 + int(i, int64)
    origins_b(i)%coupling_id = 11001_int64
    origins_b(i)%swap_lineage_id = 1900_int64 + int(i, int64)
    origins_b(i)%swap_revision = 0_int64
    origins_b(i)%groundwater_service_id = groundwater_b%service_id_value
    origins_b(i)%groundwater_lineage_id = groundwater_b%lineage_id_value
    origins_b(i)%groundwater_revision = 0_int64
  end do

  call run_restricted_groundwater_multiswap_cell_window(executor_a, parameters_a, committed_a, bindings_a, &
       materializer, numerical_a, groundwater_a, ledgers_a, datum_a, policy_a, window_a, origins_a, result_a)
  call check(result_a%status == GW_MULTI_OK .and. result_a%committed, 'multicell: first cell committed', failures)
  call check(model_a%advance_count == 4, 'multicell: first cell used exactly four SWAP trajectories', failures)
  call check(groundwater_a%trial_count == 2 .and. groundwater_a%commit_count == 1, &
       'multicell: first cell bounded groundwater work', failures)

  do i = 1, 2
    call committed_a(i)%snapshot(physical, snapshot_available)
    call check(snapshot_available, 'multicell: first-cell snapshot available', failures)
    if (snapshot_available) then
      select type (typed_physical => physical)
      type is (dummy_state_t)
        cell_a_storage_after_commit(i) = typed_physical%storage
      class default
        cell_a_storage_after_commit(i) = huge(0.0_real64)
        call check(.false., 'multicell: first-cell snapshot type', failures)
      end select
    end if
    if (allocated(physical)) deallocate(physical)
  end do

  ! Fail the second cell only on its corrector groundwater trial. Both of its
  ! predictor and corrector SWAP tile trajectories therefore execute, but no
  ! second-cell participant may publish.
  groundwater_b%fail_trial_number = 2
  call run_restricted_groundwater_multiswap_cell_window(executor_a, parameters_b, committed_b, bindings_b, &
       materializer, numerical_b, groundwater_b, ledgers_b, datum_b, policy_b, window_b, origins_b, result_b)

  call check(result_b%status == GW_MULTI_CORRECTOR_GROUNDWATER_FAILED .and. .not. result_b%committed, &
       'multicell: second cell failed closed at corrector groundwater', failures)
  call check(model_a%advance_count == 8, &
       'multicell: shared worker bounded to two trajectories per tile per cell', failures)
  call check(groundwater_b%revision == 0_int64 .and. groundwater_b%commit_count == 0, &
       'multicell: failed groundwater cell unpublished', failures)

  do i = 1, 2
    call check(committed_a(i)%current_revision() == 1_int64, &
         'multicell: accepted first-cell SWAP revision preserved', failures)
    call committed_a(i)%snapshot(physical, snapshot_available)
    call check(snapshot_available, 'multicell: first-cell post-failure snapshot available', failures)
    if (snapshot_available) then
      select type (typed_physical => physical)
      type is (dummy_state_t)
        call check_close(typed_physical%storage, cell_a_storage_after_commit(i), 0.0_real64, &
             'multicell: failed second cell cannot bleed into accepted first cell', failures)
      class default
        call check(.false., 'multicell: first-cell post-failure snapshot type', failures)
      end select
    end if
    if (allocated(physical)) deallocate(physical)

    call ledgers_a(i)%snapshot(snap)
    call check(snap%committed_exchange_count == 1 .and. .not. snap%trial_active .and. .not. snap%prepared_active, &
         'multicell: accepted first-cell ledger preserved', failures)

    call check(committed_b(i)%current_revision() == 0_int64, &
         'multicell: failed second-cell SWAP revision unchanged', failures)
    call committed_b(i)%snapshot(physical, snapshot_available)
    expected_storage = 20.0_real64 + real(i, real64)
    call check(snapshot_available, 'multicell: second-cell snapshot available', failures)
    if (snapshot_available) then
      select type (typed_physical => physical)
      type is (dummy_state_t)
        call check_close(typed_physical%storage, expected_storage, 0.0_real64, &
             'multicell: failed second-cell physical state unchanged', failures)
      class default
        call check(.false., 'multicell: second-cell snapshot type', failures)
      end select
    end if
    if (allocated(physical)) deallocate(physical)

    call ledgers_b(i)%snapshot(snap)
    call check(snap%committed_exchange_count == 0 .and. .not. snap%trial_active .and. .not. snap%prepared_active, &
         'multicell: failed second-cell ledger unpublished', failures)
    call check(snap%conservation_residual_m == 0.0_real64, &
         'multicell: failed second-cell ledger remains conservative', failures)
  end do

  call check(groundwater_a%revision == 1_int64 .and. groundwater_a%commit_count == 1, &
       'multicell: accepted first groundwater cell preserved after later failure', failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'F-GC25 MULTICELL ISOLATION FAILURES=', failures
    error stop 1
  end if
  write(*,'(A)') 'F-GC25 MULTICELL ISOLATION PASS'

end program test_fgc25_multicell_isolation
