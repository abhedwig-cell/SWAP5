program test_fgc19r_prepared_ledger_publication_adversarial
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_interface_lineage_t
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, &
       groundwater_interface_mass_snapshot_t, groundwater_interface_mass_prepared_t, GW_MASS_LEDGER_OK
  implicit none

  type(groundwater_interface_mass_ledger_t) :: ledger_a, ledger_b, ledger_c
  type(groundwater_interface_mass_snapshot_t) :: snap_a, snap_b, snap_c
  type(groundwater_interface_mass_prepared_t) :: prepared_a, prepared_a_copy, stale_a, prepared_b, prepared_c
  type(groundwater_coupling_window_t) :: window
  type(groundwater_interface_lineage_t) :: lineage
  integer :: status

  window%t0 = 5100.125_real64
  window%t1 = 5100.1875_real64
  lineage%coupling_id = 101_int64
  lineage%swap_lineage_id = 201_int64
  lineage%swap_origin_revision = 11_int64
  lineage%groundwater_lineage_id = 301_int64
  lineage%groundwater_origin_revision = 21_int64
  lineage%candidate_revision = 22_int64

  ! Prepare two independent ledgers. Both start with preparation generation 1.
  call ledger_a%stage_exchange(window, lineage, 0.004_real64, status)
  call require(status == GW_MASS_LEDGER_OK, 'stage ledger A')
  call ledger_a%prepare_trial(prepared_a, status)
  call require(status == GW_MASS_LEDGER_OK .and. prepared_a%ready(), 'prepare ledger A')

  lineage%coupling_id = 102_int64
  lineage%candidate_revision = 23_int64
  call ledger_b%stage_exchange(window, lineage, 0.007_real64, status)
  call require(status == GW_MASS_LEDGER_OK, 'stage ledger B')
  call ledger_b%prepare_trial(prepared_b, status)
  call require(status == GW_MASS_LEDGER_OK .and. prepared_b%ready(), 'prepare ledger B')

  call require(ledger_a%prepared_ready_for_commit(prepared_a), 'A accepts own handle')
  call require(ledger_b%prepared_ready_for_commit(prepared_b), 'B accepts own handle')

  ! Blocker probe. A foreign handle must never authorize publication on B.
  ! The current F-GC19R candidate accepts it because provenance is only a
  ! generation number and both ledgers independently use generation 1.
  prepared_a_copy = prepared_a
  stale_a = prepared_a
  call require(ledger_b%prepared_ready_for_commit(prepared_a), &
       'blocker not reproduced: foreign handle unexpectedly rejected')
  call ledger_b%commit_prepared(prepared_a)
  call ledger_b%snapshot(snap_b)
  call require(snap_b%available, 'snapshot B after foreign commit')
  call require(snap_b%committed_exchange_count == 1, 'foreign handle published B')
  call require(snap_b%committed_swap_outward_exchange_m == 0.007_real64, 'B publishes its own prepared payload')
  call require(snap_b%conservation_residual_m == 0.0_real64, 'B sign balance remains exact')

  ! The copied credential can still publish A, so one logical credential value
  ! has authorized two independent ledgers.
  call require(ledger_a%prepared_ready_for_commit(prepared_a_copy), 'copied A handle remains live on A')
  call ledger_a%commit_prepared(prepared_a_copy)
  call ledger_a%snapshot(snap_a)
  call require(snap_a%committed_exchange_count == 1, 'copied handle publishes A')
  call require(snap_a%committed_swap_outward_exchange_m == 0.004_real64, 'A publishes its payload')
  call require(snap_a%conservation_residual_m == 0.0_real64, 'A sign balance remains exact')

  ! Same-ledger stale replay is correctly rejected after publication.
  call require(.not. ledger_a%prepared_ready_for_commit(stale_a), 'same-ledger stale copy rejected')

  ! Abort remains rollback-only for committed mass accounting.
  lineage%coupling_id = 103_int64
  lineage%candidate_revision = 24_int64
  call ledger_c%stage_exchange(window, lineage, -0.002_real64, status)
  call require(status == GW_MASS_LEDGER_OK, 'stage ledger C')
  call ledger_c%prepare_trial(prepared_c, status)
  call require(status == GW_MASS_LEDGER_OK .and. prepared_c%ready(), 'prepare ledger C')
  call ledger_c%abort_prepared(prepared_c)
  call ledger_c%snapshot(snap_c)
  call require(snap_c%committed_exchange_count == 0, 'abort does not publish')
  call require(snap_c%committed_swap_outward_exchange_m == 0.0_real64, 'abort preserves committed mass')
  call require(.not. snap_c%prepared_active, 'abort clears reservation')
  call require(snap_c%discarded_trial_count == 1, 'abort diagnostic counted')
  call require(snap_c%conservation_residual_m == 0.0_real64, 'abort sign balance remains exact')

  write(*,'(a)') 'FGC19R_FOREIGN_PREPARED_HANDLE_ACCEPTANCE=REPRODUCED'
  write(*,'(a)') 'FGC19R_SAME_LEDGER_STALE_REPLAY=REJECTED'
  write(*,'(a)') 'FGC19R_ABORT_COMMITTED_MASS_PRESERVATION=PASS'
  write(*,'(a)') 'FGC19R_EXACT_ACTION_REACTION=PASS'
  write(*,'(a)') 'FGC19R_OWNER_QUALIFICATION=BLOCKED_REMEDIATION_REQUIRED'

contains
  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a,a)') 'FGC19R_ADVERSARIAL_FAIL: ', trim(message)
      error stop 1
    end if
  end subroutine require
end program test_fgc19r_prepared_ledger_publication_adversarial
