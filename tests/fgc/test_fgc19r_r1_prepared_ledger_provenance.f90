program test_fgc19r_r1_prepared_ledger_provenance
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_interface_lineage_t
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, &
       groundwater_interface_mass_snapshot_t, groundwater_interface_mass_prepared_t, &
       GW_MASS_LEDGER_OK, GW_MASS_LEDGER_IDENTITY_REQUIRED, GW_MASS_LEDGER_INVALID_IDENTITY, &
       GW_MASS_LEDGER_IDENTITY_ALREADY_BOUND, GW_MASS_LEDGER_TRIAL_ALREADY_ACTIVE
  implicit none

  type(groundwater_interface_mass_ledger_t) :: ledger_a, ledger_b, ledger_c, ledger_unbound
  type(groundwater_interface_mass_snapshot_t) :: snap_a, snap_b, snap_c, snap_unbound
  type(groundwater_interface_mass_prepared_t) :: prepared_a, prepared_a_copy, prepared_b, prepared_a2, stale_a
  type(groundwater_coupling_window_t) :: window
  type(groundwater_interface_lineage_t) :: lineage
  integer :: status

  window%t0 = 6200.125_real64
  window%t1 = 6200.1875_real64
  lineage%coupling_id = 401_int64
  lineage%swap_lineage_id = 501_int64
  lineage%swap_origin_revision = 31_int64
  lineage%groundwater_lineage_id = 601_int64
  lineage%groundwater_origin_revision = 41_int64
  lineage%candidate_revision = 42_int64

  call ledger_unbound%bind_identity(0_int64, status)
  call require(status == GW_MASS_LEDGER_INVALID_IDENTITY, 'zero ledger identity rejected')
  call ledger_unbound%stage_exchange(window, lineage, 0.001_real64, status)
  call require(status == GW_MASS_LEDGER_OK, 'unbound staging remains legacy-compatible')
  call ledger_unbound%prepare_trial(prepared_a, status)
  call require(status == GW_MASS_LEDGER_IDENTITY_REQUIRED, 'external prepare requires identity')
  call require(ledger_unbound%has_active_trial(), 'identity failure preserves trial')
  call ledger_unbound%bind_identity(900_int64, status)
  call require(status == GW_MASS_LEDGER_TRIAL_ALREADY_ACTIVE, 'identity cannot be rebound during trial')
  call ledger_unbound%discard_trial(status)
  call require(status == GW_MASS_LEDGER_OK, 'discard unbound trial')

  call ledger_a%bind_identity(1001_int64, status)
  call require(status == GW_MASS_LEDGER_OK .and. ledger_a%has_identity(), 'bind ledger A')
  call ledger_a%bind_identity(1001_int64, status)
  call require(status == GW_MASS_LEDGER_OK, 'same identity bind idempotent')
  call ledger_a%bind_identity(1002_int64, status)
  call require(status == GW_MASS_LEDGER_IDENTITY_ALREADY_BOUND, 'ledger identity immutable')

  call ledger_b%bind_identity(2001_int64, status)
  call require(status == GW_MASS_LEDGER_OK .and. ledger_b%has_identity(), 'bind ledger B')

  call ledger_a%stage_exchange(window, lineage, 0.004_real64, status)
  call require(status == GW_MASS_LEDGER_OK, 'stage A')
  call ledger_a%prepare_trial(prepared_a, status)
  call require(status == GW_MASS_LEDGER_OK .and. prepared_a%ready(), 'prepare A')
  prepared_a_copy = prepared_a
  stale_a = prepared_a

  ! B deliberately reaches the same local preparation generation as A.
  lineage%coupling_id = 402_int64
  lineage%candidate_revision = 43_int64
  call ledger_b%stage_exchange(window, lineage, 0.007_real64, status)
  call require(status == GW_MASS_LEDGER_OK, 'stage B')
  call ledger_b%prepare_trial(prepared_b, status)
  call require(status == GW_MASS_LEDGER_OK .and. prepared_b%ready(), 'prepare B')

  call require(ledger_a%prepared_ready_for_commit(prepared_a), 'A accepts own handle')
  call require(ledger_b%prepared_ready_for_commit(prepared_b), 'B accepts own handle')
  call require(.not. ledger_b%prepared_ready_for_commit(prepared_a), 'B rejects foreign A handle')
  call require(.not. ledger_a%prepared_ready_for_commit(prepared_b), 'A rejects foreign B handle')
  call ledger_a%snapshot(snap_a)
  call ledger_b%snapshot(snap_b)
  call require(snap_a%committed_exchange_count == 0 .and. snap_b%committed_exchange_count == 0, &
       'foreign credential checks publish nothing')
  call require(snap_a%prepared_active .and. snap_b%prepared_active, 'foreign checks preserve reservations')
  call require(snap_a%identity_bound .and. snap_a%ledger_id == 1001_int64, 'A diagnostic identity')
  call require(snap_b%identity_bound .and. snap_b%ledger_id == 2001_int64, 'B diagnostic identity')

  call ledger_a%commit_prepared(prepared_a)
  call ledger_a%snapshot(snap_a)
  call require(snap_a%committed_exchange_count == 1, 'A publishes once')
  call require(snap_a%committed_swap_outward_exchange_m == 0.004_real64, 'A committed amount')
  call require(snap_a%committed_groundwater_outward_exchange_m == -snap_a%committed_swap_outward_exchange_m, &
       'A exact action reaction')
  call require(snap_a%conservation_residual_m == 0.0_real64, 'A exact residual')
  call require(.not. ledger_a%prepared_ready_for_commit(prepared_a_copy), 'same-ledger copied replay rejected')
  call require(.not. ledger_a%prepared_ready_for_commit(stale_a), 'stale A handle rejected after consume')

  call ledger_b%abort_prepared(prepared_b)
  call ledger_b%snapshot(snap_b)
  call require(snap_b%committed_exchange_count == 0, 'B abort publishes nothing')
  call require(snap_b%committed_swap_outward_exchange_m == 0.0_real64, 'B abort preserves mass')
  call require(.not. snap_b%prepared_active .and. snap_b%discarded_trial_count == 1, 'B abort clears and diagnoses')
  call require(snap_b%conservation_residual_m == 0.0_real64, 'B abort exact residual')

  ! Reprepare A. Local generation advances, so the consumed generation remains stale.
  lineage%coupling_id = 403_int64
  lineage%candidate_revision = 44_int64
  call ledger_a%stage_exchange(window, lineage, -0.0015_real64, status)
  call require(status == GW_MASS_LEDGER_OK, 'restage A')
  call ledger_a%prepare_trial(prepared_a2, status)
  call require(status == GW_MASS_LEDGER_OK .and. prepared_a2%ready(), 'reprepare A')
  call require(.not. ledger_a%prepared_ready_for_commit(stale_a), 'prior generation stays stale')
  call require(ledger_a%prepared_ready_for_commit(prepared_a2), 'new generation accepted')
  call ledger_a%commit_prepared(prepared_a2)
  call ledger_a%snapshot(snap_a)
  call require(snap_a%committed_exchange_count == 2, 'A second publish')
  call require(abs(snap_a%committed_swap_outward_exchange_m - 0.0025_real64) < 1.0e-16_real64, &
       'A signed accumulation')
  call require(snap_a%conservation_residual_m == 0.0_real64, 'A cumulative exact residual')

  ! F-GC19 legacy atomically committed path remains valid without external identity.
  lineage%coupling_id = 404_int64
  lineage%candidate_revision = 45_int64
  call ledger_c%stage_exchange(window, lineage, 0.003_real64, status)
  call require(status == GW_MASS_LEDGER_OK, 'legacy stage C')
  call ledger_c%commit_trial(status)
  call require(status == GW_MASS_LEDGER_OK, 'legacy commit_trial C')
  call ledger_c%snapshot(snap_c)
  call require(.not. snap_c%identity_bound, 'legacy atomic path need not expose identity')
  call require(snap_c%committed_exchange_count == 1, 'legacy commit count')
  call require(snap_c%committed_swap_outward_exchange_m == 0.003_real64, 'legacy committed amount')
  call require(snap_c%conservation_residual_m == 0.0_real64, 'legacy exact residual')

  call ledger_unbound%snapshot(snap_unbound)
  call require(snap_unbound%committed_exchange_count == 0, 'unbound rejected prepare never commits')

  write(*,'(a)') 'FGC19R_R1_EXPLICIT_LEDGER_IDENTITY=PASS'
  write(*,'(a)') 'FGC19R_R1_FOREIGN_HANDLE_REJECTION=PASS'
  write(*,'(a)') 'FGC19R_R1_SAME_LEDGER_REPLAY_REJECTION=PASS'
  write(*,'(a)') 'FGC19R_R1_ABORT_MASS_PRESERVATION=PASS'
  write(*,'(a)') 'FGC19R_R1_LEGACY_COMMIT_TRIAL=PASS'
  write(*,'(a)') 'FGC19R_R1_EXACT_ACTION_REACTION=PASS'
  write(*,'(a)') 'FGC19R_R1_PROVENANCE_DIAGNOSTICS=PASS'

contains
  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a,a)') 'FGC19R_R1_TEST_FAIL: ', trim(message)
      error stop 1
    end if
  end subroutine require
end program test_fgc19r_r1_prepared_ledger_provenance
