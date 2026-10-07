#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$ROOT/tests/fwof/.run_swap431_potential_shadow_tx_$$.sh"
OUT="${TMPDIR:-/tmp}/swap431-potential-shadow-tx-$$.out"
trap 'rm -f "$TMP" "$OUT"' EXIT

cp "$ROOT/tests/fwof/run_fwof38_atomic_crop_transaction_gate.sh" "$TMP"

python3 - "$TMP" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text(encoding='utf-8')

# Add observation variables to the generated Fortran declaration payload.
anchor="  integer(kind=8) :: crop_revision_before\n"
insert=anchor+"""  type(wofost_potential_shadow_state_t) :: shadow_snapshot, restored_shadow
  type(fmr_wofost_root_growth_carrier_t) :: root_growth_snapshot, restored_growth
  type(fmr_wofost_crop_transaction_persistence_t) :: potential_persistence
  type(fmr_wofost_crop_transaction_state_t) :: restored_potential_state
  type(wofost_crop_owner_state_t) :: restored_potential_owner
  logical :: shadow_available, growth_available, persistence_ok, reconstructed_ok, restored_available
  integer :: persistence_status
  type(fmr_wofost_accepted_window_t) :: second_window
  type(fmr_wofost_trial_contribution_t) :: second_trial
  type(fmr_wofost_accepted_interval_certificate_t) :: second_certificate
  type(fmr_wofost_crop_event_token_t) :: second_token
  type(fmr_wofost_crop_event_identity_t) :: second_identity
  type(fmr_wofost_crop_event_forcing_t) :: second_event_forcing
  type(kernel_checkpoint_t) :: second_physical_checkpoint, continuous_second_checkpoint, restarted_second_checkpoint
  type(kernel_committed_state_t) :: restarted_crop_committed
  type(kernel_executor_t) :: restarted_crop_kernel
  type(fmr_wofost_crop_transaction_model_t), target :: restarted_crop_model
  type(kernel_candidate_state_t) :: continuous_second_candidate, restarted_second_candidate
  type(kernel_result_t) :: continuous_second_result, restarted_second_result
  type(kernel_diagnostics_t) :: continuous_second_diag, restarted_second_diag
  class(transaction_state_t), allocatable :: continuous_second_snapshot, restarted_second_snapshot
  type(wofost_crop_owner_state_t) :: continuous_second_owner, restarted_second_owner
  type(wofost_potential_shadow_state_t) :: continuous_second_shadow, restarted_second_shadow
  type(fmr_wofost_root_growth_carrier_t) :: continuous_second_growth, restarted_second_growth
  logical :: second_checkpoint_ok, second_event_available, continuous_available, restarted_state_available
  integer(kind=8) :: continuous_revision_before, restarted_revision_before
"""
if s.count(anchor)!=1:
    raise SystemExit(f'decl anchor count={s.count(anchor)}')
s=s.replace(anchor,insert,1)

# Enable the optional potential shadow for the exact same F-WOF38 transaction.
old="""  call construct_fmr_wofost_crop_transaction_parameters(bundle, update_parameters, 0.005_real64, 0.002_real64, &
       crop_parameters, crop_status)
"""
new="""  call construct_fmr_wofost_crop_transaction_parameters(bundle, update_parameters, 0.005_real64, 0.002_real64, &
       crop_parameters, crop_status, enable_potential_shadow=.true., potential_attainable_multiplier=0.5_real64)
"""
if s.count(old)!=1:
    raise SystemExit(f'parameter anchor count={s.count(old)}')
s=s.replace(old,new,1)

old="""  call initialize_fmr_wofost_crop_transaction_state(seed, crop_initial_state, crop_status)
"""
new="""  call initialize_fmr_wofost_crop_transaction_state(seed, crop_initial_state, crop_status, &
       enable_potential_shadow=.true.)
"""
if s.count(old)!=1:
    raise SystemExit(f'init anchor count={s.count(old)}')
s=s.replace(old,new,1)

# Precommit: shadow is present but root-growth carrier is intentionally unavailable.
anchor="""    call require(.not. tx%receipt_ready(), 'F-WOF38 no committed event receipt before publication')
"""
insert=anchor+"""    call require(tx%potential_shadow_enabled(), 'SW431 potential shadow enabled before publication')
    call tx%snapshot_potential_shadow(shadow_snapshot, shadow_available)
    call require(shadow_available .and. shadow_snapshot%active, 'SW431 precommit shadow snapshot available')
    call tx%snapshot_root_growth(root_growth_snapshot, growth_available)
    call require(.not. growth_available, 'SW431 precommit root growth unavailable before accepted event')
"""
if s.count(anchor)!=1:
    raise SystemExit(f'precommit anchor count={s.count(anchor)}')
s=s.replace(anchor,insert,1)

# Candidate from accepted event: receipt + shadow + actual/potential gross root growth are one candidate.
anchor="""    call require(tx%consumed_event(event_identity), 'F-WOF38 first candidate consumes matching event')
"""
insert=anchor+"""    call require(tx%potential_shadow_enabled(), 'SW431 candidate potential shadow enabled')
    call tx%snapshot_potential_shadow(shadow_snapshot, shadow_available)
    call require(shadow_available .and. shadow_snapshot%active, 'SW431 candidate shadow snapshot available')
    call tx%snapshot_root_growth(root_growth_snapshot, growth_available)
    call require(growth_available .and. root_growth_snapshot%ready(), 'SW431 candidate GRRT/GRRTPOT carrier ready')
    call require(root_growth_snapshot%actual_gross_root_growth >= 0.0_real64, 'SW431 candidate GRRT nonnegative')
    call require(root_growth_snapshot%potential_gross_root_growth >= 0.0_real64, 'SW431 candidate GRRTPOT nonnegative')
"""
if s.count(anchor)!=1:
    raise SystemExit(f'candidate anchor count={s.count(anchor)}')
s=s.replace(anchor,insert,1)

# Rollback must leave the committed shadow and carrier at pre-event state.
anchor="""    call require(.not. tx%receipt_ready(), 'F-WOF38 rollback leaves receipt uncommitted')
"""
insert=anchor+"""    call require(tx%potential_shadow_enabled(), 'SW431 rollback preserves enabled shadow')
    call tx%snapshot_potential_shadow(shadow_snapshot, shadow_available)
    call require(shadow_available .and. shadow_snapshot%active, 'SW431 rollback preserves pre-event shadow')
    call tx%snapshot_root_growth(root_growth_snapshot, growth_available)
    call require(.not. growth_available, 'SW431 rollback leaves GRRT/GRRTPOT unpublished')
"""
if s.count(anchor)!=1:
    raise SystemExit(f'rollback anchor count={s.count(anchor)}')
s=s.replace(anchor,insert,1)

# Commit publishes owner, shadow, carrier and receipt in the one existing revision.
anchor="""    call require(tx%consumed_event(event_identity), 'F-WOF38 committed receipt matches event')
"""
insert=anchor+"""    call require(tx%potential_shadow_enabled(), 'SW431 committed shadow enabled')
    call tx%snapshot_potential_shadow(shadow_snapshot, shadow_available)
    call require(shadow_available .and. shadow_snapshot%active, 'SW431 committed shadow available')
    call tx%snapshot_root_growth(root_growth_snapshot, growth_available)
    call require(growth_available .and. root_growth_snapshot%ready(), 'SW431 committed GRRT/GRRTPOT carrier available')
    call export_fmr_wofost_crop_transaction_persistence(tx,potential_persistence,persistence_ok,persistence_status)
    call require(persistence_ok .and. persistence_status==FMR_WOFOST_CROP_PERSISTENCE_OK, &
         'SW431 post-event potential persistence export')
    call reconstruct_fmr_wofost_crop_transaction_from_persistence(potential_persistence,restored_potential_state, &
         reconstructed_ok,persistence_status)
    call require(reconstructed_ok .and. persistence_status==FMR_WOFOST_CROP_PERSISTENCE_OK, &
         'SW431 post-event potential persistence reconstruct')
    call restored_potential_state%snapshot_owner(restored_potential_owner,restored_available)
    call require(restored_available .and. same_owner(restored_potential_owner,crop_snapshot_owner), &
         'SW431 restored actual owner exact')
    call restored_potential_state%snapshot_potential_shadow(restored_shadow,restored_available)
    call require(restored_available .and. restored_shadow%active, 'SW431 restored potential shadow available')
    call restored_potential_state%snapshot_root_growth(restored_growth,restored_available)
    call require(restored_available .and. restored_growth%ready(), 'SW431 restored GRRT/GRRTPOT available')
    call require(bitwise_equal(restored_growth%actual_gross_root_growth,root_growth_snapshot%actual_gross_root_growth), &
         'SW431 restored GRRT exact')
    call require(bitwise_equal(restored_growth%potential_gross_root_growth,root_growth_snapshot%potential_gross_root_growth), &
         'SW431 restored GRRTPOT exact')
    call require(restored_potential_state%receipt_ready() .and. restored_potential_state%consumed_event(event_identity), &
         'SW431 restored receipt exact')

    ! Build a second accepted physical event and advance both the continuous
    ! committed crop state and a fresh committed state reconstructed from the
    ! persistence image. Both must converge to the same second accepted crop state.
    call physical_committed%capture_checkpoint(second_physical_checkpoint, second_checkpoint_ok)
    call require(second_checkpoint_ok, 'SW431 second physical checkpoint')
    call open_wofost_accepted_window(second_physical_checkpoint, 102.0_real64, second_window, crop_status)
    call require(crop_status == FMR_WOFOST_LINEAGE_OK .and. second_window%ready(), &
         'SW431 second accepted window open')
    call begin_wofost_trial_contribution(second_physical_checkpoint, 102.0_real64, second_trial, crop_status)
    call require(crop_status == FMR_WOFOST_LINEAGE_OK, 'SW431 second physical trial begin')
    call accumulate_wofost_trial_process_rate(second_trial, 101.0_real64, 102.0_real64, &
         4.0_real64, 5.0_real64, crop_status)
    call require(crop_status == FMR_WOFOST_LINEAGE_OK .and. second_trial%complete(), &
         'SW431 second physical trial fill')
    call advance_and_commit_physical(physical_kernel, physical_model, physical_parameters, physical_forcing, &
         physical_config, physical_committed, second_physical_checkpoint, 101.0_real64, 102.0_real64)
    call certify_fkt_accepted_interval(second_physical_checkpoint, physical_committed, second_certificate, crop_status)
    call require(crop_status == FMR_WOFOST_LINEAGE_OK .and. second_certificate%ready(), &
         'SW431 second physical certificate')
    call admit_wofost_accepted_trial(second_window, second_certificate, second_trial, crop_status)
    call require(crop_status == FMR_WOFOST_LINEAGE_OK .and. second_window%complete(), &
         'SW431 second accepted trial admission')
    call prepare_wofost_crop_event_delivery(second_window, aggregates, second_token, second_event_available, crop_status)
    call require(crop_status == FMR_WOFOST_LINEAGE_OK .and. second_event_available .and. second_token%ready(), &
         'SW431 second event prepare')
    call identify_wofost_crop_event(second_token, second_identity, crop_status)
    call require(crop_status == FMR_WOFOST_LINEAGE_OK .and. second_identity%ready(), &
         'SW431 second event identity')
    call prepare_fmr_wofost_crop_event_forcing(second_window, forcing, second_event_forcing, crop_status)
    call require(crop_status == FMR_WOF38_OK .and. second_event_forcing%ready(), &
         'SW431 second crop event forcing')

    ! Continuous continuation from the first committed event.
    call crop_committed%capture_checkpoint(continuous_second_checkpoint, second_checkpoint_ok)
    call require(second_checkpoint_ok, 'SW431 continuous second crop checkpoint')
    continuous_revision_before = crop_committed%current_revision()
    call crop_kernel%advance_interval(crop_parameters, crop_committed, second_event_forcing, crop_config, &
         101.0_real64, 102.0_real64, continuous_second_result, continuous_second_candidate, &
         continuous_second_diag, continuous_second_checkpoint)
    call require(continuous_second_result%status == CANONICAL_STATUS_COMPLETED .and. &
         continuous_second_candidate%ready(), 'SW431 continuous second candidate')
    call crop_kernel%commit_candidate(crop_committed, continuous_second_candidate, continuous_second_diag, &
         did_commit, crop_commit_status)
    call require(did_commit .and. crop_commit_status == KERNEL_COMMIT_STATUS_COMMITTED .and. &
         crop_committed%current_revision() == continuous_revision_before + 1, &
         'SW431 continuous second commit')
    call crop_committed%snapshot(continuous_second_snapshot, continuous_available)
    call require(continuous_available, 'SW431 continuous second snapshot')

    ! Restarted continuation from the persisted post-first-event image.
    call setup_crop_kernel_committed(restored_potential_state, restarted_crop_committed, 3810_int64, 101.0_real64)
    call restarted_crop_kernel%bind_model(restarted_crop_model)
    call restarted_crop_committed%capture_checkpoint(restarted_second_checkpoint, second_checkpoint_ok)
    call require(second_checkpoint_ok, 'SW431 restarted second crop checkpoint')
    restarted_revision_before = restarted_crop_committed%current_revision()
    call restarted_crop_kernel%advance_interval(crop_parameters, restarted_crop_committed, second_event_forcing, crop_config, &
         101.0_real64, 102.0_real64, restarted_second_result, restarted_second_candidate, &
         restarted_second_diag, restarted_second_checkpoint)
    call require(restarted_second_result%status == CANONICAL_STATUS_COMPLETED .and. &
         restarted_second_candidate%ready(), 'SW431 restarted second candidate')
    call restarted_crop_kernel%commit_candidate(restarted_crop_committed, restarted_second_candidate, &
         restarted_second_diag, did_commit, crop_commit_status)
    call require(did_commit .and. crop_commit_status == KERNEL_COMMIT_STATUS_COMMITTED .and. &
         restarted_crop_committed%current_revision() == restarted_revision_before + 1, &
         'SW431 restarted second commit')
    call restarted_crop_committed%snapshot(restarted_second_snapshot, restarted_state_available)
    call require(restarted_state_available, 'SW431 restarted second snapshot')

    select type (continuous_tx => continuous_second_snapshot)
    type is (fmr_wofost_crop_transaction_state_t)
      call continuous_tx%snapshot_owner(continuous_second_owner, continuous_available)
      call require(continuous_available .and. continuous_tx%receipt_ready() .and. &
           continuous_tx%consumed_event(second_identity), 'SW431 continuous second receipt')
      call continuous_tx%snapshot_potential_shadow(continuous_second_shadow, continuous_available)
      call require(continuous_available .and. continuous_second_shadow%active, &
           'SW431 continuous second shadow')
      call continuous_tx%snapshot_root_growth(continuous_second_growth, growth_available)
      call require(growth_available .and. continuous_second_growth%ready(), &
           'SW431 continuous second growth carrier')
    class default
      call require(.false., 'SW431 continuous second state type')
    end select

    select type (restarted_tx => restarted_second_snapshot)
    type is (fmr_wofost_crop_transaction_state_t)
      call restarted_tx%snapshot_owner(restarted_second_owner, restarted_state_available)
      call require(restarted_state_available .and. restarted_tx%receipt_ready() .and. &
           restarted_tx%consumed_event(second_identity), 'SW431 restarted second receipt')
      call restarted_tx%snapshot_potential_shadow(restarted_second_shadow, restarted_state_available)
      call require(restarted_state_available .and. restarted_second_shadow%active, &
           'SW431 restarted second shadow')
      call restarted_tx%snapshot_root_growth(restarted_second_growth, restored_available)
      call require(restored_available .and. restarted_second_growth%ready(), &
           'SW431 restarted second growth carrier')
    class default
      call require(.false., 'SW431 restarted second state type')
    end select

    call require(same_owner(continuous_second_owner, restarted_second_owner), &
         'SW431 continuous versus restarted second actual owner exact')
    call require(bitwise_equal(continuous_second_shadow%root_biomass(), restarted_second_shadow%root_biomass()), &
         'SW431 continuous versus restarted second WRTPOT exact')
    call require(bitwise_equal(continuous_second_growth%actual_gross_root_growth, &
         restarted_second_growth%actual_gross_root_growth), &
         'SW431 continuous versus restarted second GRRT exact')
    call require(bitwise_equal(continuous_second_growth%potential_gross_root_growth, &
         restarted_second_growth%potential_gross_root_growth), &
         'SW431 continuous versus restarted second GRRTPOT exact')
"""
if s.count(anchor)!=1:
    raise SystemExit(f'commit anchor count={s.count(anchor)}')
s=s.replace(anchor,insert,1)

# Failed crop evolution must publish neither shadow nor root-growth observation.
anchor="""    call require(.not. tx%receipt_ready(), 'F-WOF38 crop failure receipt unchanged')
"""
insert=anchor+"""    call require(tx%potential_shadow_enabled(), 'SW431 failed trial keeps configured shadow')
    call tx%snapshot_potential_shadow(shadow_snapshot, shadow_available)
    call require(shadow_available .and. shadow_snapshot%active, 'SW431 failed trial keeps pre-event shadow')
    call tx%snapshot_root_growth(root_growth_snapshot, growth_available)
    call require(.not. growth_available, 'SW431 failed trial publishes no GRRT/GRRTPOT')
"""
if s.count(anchor)!=1:
    raise SystemExit(f'failure anchor count={s.count(anchor)}')
s=s.replace(anchor,insert,1)

# Add visible markers.
anchor="""  print '(a)', 'FWOF38_ATOMIC_CROP_TRANSACTION_GATE PASS'
"""
insert="""  print '(a)', 'SW431_POTENTIAL_SHADOW_POST_EVENT_RESTART=PASS'
  print '(a)', 'SW431_POTENTIAL_SHADOW_SECOND_EVENT_CONTINUATION=PASS'
  print '(a)', 'SW431_POTENTIAL_SHADOW_ATOMIC_TRANSACTION=PASS'
  print '(a)', 'FWOF38_ATOMIC_CROP_TRANSACTION_GATE PASS'
"""
if s.count(anchor)!=1:
    raise SystemExit(f'final marker anchor count={s.count(anchor)}')
s=s.replace(anchor,insert,1)

marker_anchor="""    'FWOF38_ATOMIC_CROP_TRANSACTION_GATE PASS' \
"""
if marker_anchor in s:
    s=s.replace(marker_anchor,"""    'SW431_POTENTIAL_SHADOW_ATOMIC_TRANSACTION=PASS' \
    'FWOF38_ATOMIC_CROP_TRANSACTION_GATE PASS' \
""",1)

p.write_text(s,encoding='utf-8')
PY

bash "$TMP" | tee "$OUT"
grep -Fq 'SW431_POTENTIAL_SHADOW_POST_EVENT_RESTART=PASS' "$OUT"
grep -Fq 'SW431_POTENTIAL_SHADOW_SECOND_EVENT_CONTINUATION=PASS' "$OUT"
grep -Fq 'SW431_POTENTIAL_SHADOW_ATOMIC_TRANSACTION=PASS' "$OUT"
grep -Fq 'FWOF38_ATOMIC_CROP_TRANSACTION_O0=PASS' "$OUT"
grep -Fq 'FWOF38_ATOMIC_CROP_TRANSACTION_O2=PASS' "$OUT"
grep -Fq 'FWOF38_ATOMIC_CROP_TRANSACTION_O0_O2_OUTPUT_IDENTITY=PASS' "$OUT"
echo 'SW431_POTENTIAL_SHADOW_TRANSACTION_GATE PASS'
