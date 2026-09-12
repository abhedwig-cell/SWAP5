program test_fvq62_fgc19r_r1_prepared_ledger_provenance
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_interface_lineage_t
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, &
       groundwater_interface_mass_snapshot_t, groundwater_interface_mass_prepared_t, &
       GW_MASS_LEDGER_OK, GW_MASS_LEDGER_IDENTITY_REQUIRED, GW_MASS_LEDGER_INVALID_IDENTITY, &
       GW_MASS_LEDGER_IDENTITY_ALREADY_BOUND
  implicit none

  type(groundwater_interface_mass_ledger_t) :: a, b, legacy, unbound
  type(groundwater_interface_mass_snapshot_t) :: sa, sb, sl, su
  type(groundwater_interface_mass_prepared_t) :: ha, ha_copy, hb, ha2
  type(groundwater_coupling_window_t) :: w
  type(groundwater_interface_lineage_t) :: ln
  integer :: status

  w%t0 = 7300.03125_real64
  w%t1 = 7300.09375_real64
  ln%coupling_id = 901_int64
  ln%swap_lineage_id = 902_int64
  ln%swap_origin_revision = 12_int64
  ln%groundwater_lineage_id = 903_int64
  ln%groundwater_origin_revision = 32_int64
  ln%candidate_revision = 33_int64

  call unbound%bind_identity(-1_int64, status)
  call require(status == GW_MASS_LEDGER_INVALID_IDENTITY, 'negative identity rejected')
  call unbound%stage_exchange(w, ln, 0.00125_real64, status)
  call require(status == GW_MASS_LEDGER_OK, 'unbound trial stages')
  call unbound%prepare_trial(ha, status)
  call require(status == GW_MASS_LEDGER_IDENTITY_REQUIRED, 'unbound external prepare rejected')
  call require(unbound%has_active_trial(), 'unbound rejection preserves trial')
  call unbound%snapshot(su)
  call require(su%committed_exchange_count == 0 .and. su%committed_swap_outward_exchange_m == 0.0_real64, &
       'unbound rejection changes no committed mass')
  call unbound%discard_trial(status)
  call require(status == GW_MASS_LEDGER_OK, 'unbound trial discard')

  call a%bind_identity(71001_int64, status)
  call require(status == GW_MASS_LEDGER_OK, 'bind A')
  call b%bind_identity(72001_int64, status)
  call require(status == GW_MASS_LEDGER_OK, 'bind B')
  call a%bind_identity(71002_int64, status)
  call require(status == GW_MASS_LEDGER_IDENTITY_ALREADY_BOUND, 'A rebind rejected')

  ! Deliberately use identical physical lineage on both ledgers. Identity must
  ! still distinguish the prepared credentials even when local generation and
  ! lineage values coincide.
  call a%stage_exchange(w, ln, 0.005_real64, status)
  call require(status == GW_MASS_LEDGER_OK, 'stage A')
  call a%prepare_trial(ha, status)
  call require(status == GW_MASS_LEDGER_OK .and. ha%ready(), 'prepare A')
  ha_copy = ha

  call b%stage_exchange(w, ln, -0.002_real64, status)
  call require(status == GW_MASS_LEDGER_OK, 'stage B')
  call b%prepare_trial(hb, status)
  call require(status == GW_MASS_LEDGER_OK .and. hb%ready(), 'prepare B')

  call require(a%prepared_ready_for_commit(ha), 'A own credential valid')
  call require(b%prepared_ready_for_commit(hb), 'B own credential valid')
  call require(.not. a%prepared_ready_for_commit(hb), 'A rejects B credential')
  call require(.not. b%prepared_ready_for_commit(ha), 'B rejects A credential')
  call a%snapshot(sa)
  call b%snapshot(sb)
  call require(sa%committed_exchange_count == 0 .and. sb%committed_exchange_count == 0, &
       'foreign probes publish nothing')
  call require(sa%prepared_active .and. sb%prepared_active, 'foreign probes preserve reservations')
  call require(sa%ledger_id == 71001_int64 .and. sb%ledger_id == 72001_int64, 'diagnostic provenance IDs')

  call b%abort_prepared(hb)
  call b%snapshot(sb)
  call require(sb%committed_exchange_count == 0, 'abort B commits nothing')
  call require(sb%committed_swap_outward_exchange_m == 0.0_real64, 'abort B preserves mass')
  call require(sb%conservation_residual_m == 0.0_real64, 'abort B residual exact')

  call a%commit_prepared(ha)
  call a%snapshot(sa)
  call require(sa%committed_exchange_count == 1, 'A commit once')
  call require(sa%committed_swap_outward_exchange_m == 0.005_real64, 'A exact committed total')
  call require(sa%committed_groundwater_outward_exchange_m == -sa%committed_swap_outward_exchange_m, &
       'A exact action reaction')
  call require(sa%conservation_residual_m == 0.0_real64, 'A exact conservation residual')
  call require(.not. a%prepared_ready_for_commit(ha_copy), 'copied credential stale after commit')

  ln%candidate_revision = 34_int64
  call a%stage_exchange(w, ln, -0.001_real64, status)
  call require(status == GW_MASS_LEDGER_OK, 'stage A generation two')
  call a%prepare_trial(ha2, status)
  call require(status == GW_MASS_LEDGER_OK .and. ha2%ready(), 'prepare A generation two')
  call require(.not. a%prepared_ready_for_commit(ha_copy), 'generation one remains stale')
  call require(a%prepared_ready_for_commit(ha2), 'generation two valid')
  call a%commit_prepared(ha2)
  call a%snapshot(sa)
  call require(sa%committed_exchange_count == 2, 'A second commit count')
  call require(abs(sa%committed_swap_outward_exchange_m - 0.004_real64) < 1.0e-16_real64, &
       'A cumulative signed exchange')
  call require(sa%conservation_residual_m == 0.0_real64, 'A cumulative residual exact')

  ! Independent legacy compatibility probe: no externally prepared credential.
  ln%coupling_id = 904_int64
  ln%candidate_revision = 35_int64
  call legacy%stage_exchange(w, ln, 0.006_real64, status)
  call require(status == GW_MASS_LEDGER_OK, 'legacy stage')
  call legacy%commit_trial(status)
  call require(status == GW_MASS_LEDGER_OK, 'legacy atomic commit')
  call legacy%snapshot(sl)
  call require(.not. sl%identity_bound, 'legacy path has no external identity requirement')
  call require(sl%committed_exchange_count == 1, 'legacy count')
  call require(sl%committed_groundwater_outward_exchange_m == -sl%committed_swap_outward_exchange_m, &
       'legacy exact action reaction')
  call require(sl%conservation_residual_m == 0.0_real64, 'legacy residual exact')

  write(*,'(a)') 'FVQ62_UNBOUND_EXTERNAL_PREPARE_FAIL_CLOSED=PASS'
  write(*,'(a)') 'FVQ62_IDENTITY_IMMUTABILITY=PASS'
  write(*,'(a)') 'FVQ62_FOREIGN_HANDLE_SAME_LINEAGE_REJECTION=PASS'
  write(*,'(a)') 'FVQ62_STALE_COPY_REJECTION=PASS'
  write(*,'(a)') 'FVQ62_GENERATION_ADVANCE_REJECTION=PASS'
  write(*,'(a)') 'FVQ62_ABORT_MASS_PRESERVATION=PASS'
  write(*,'(a)') 'FVQ62_LEGACY_ATOMIC_COMPATIBILITY=PASS'
  write(*,'(a)') 'FVQ62_EXACT_ACTION_REACTION=PASS'

contains
  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a,a)') 'FVQ62_TEST_FAIL: ', trim(message)
      error stop 1
    end if
  end subroutine require
end program test_fvq62_fgc19r_r1_prepared_ledger_provenance
