#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$ROOT/tests/fwof/.run_fwof38_gate_e_$$.sh"
OUT="${TMPDIR:-/tmp}/swap5-fwof38-gate-e-$$.out"
trap 'rm -f "$TMP" "$OUT"' EXIT

cp "$ROOT/tests/fwof/run_fwof38_atomic_crop_transaction_gate.sh" "$TMP"

python3 - "$TMP" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
src = path.read_text(encoding='utf-8')

anchor = """  print '(a)', 'FWOF38_FAILED_CROP_EVOLUTION_ZERO_OWNER_RECEIPT_MUTATION=PASS'

  ! A policy that permits dt shrinking is not admitted for this fixed one-day
"""
insert = """  print '(a)', 'FWOF38_FAILED_CROP_EVOLUTION_ZERO_OWNER_RECEIPT_MUTATION=PASS'

  ! Gate E: retry the same accepted physical event from exactly the same
  ! still-committed crop checkpoint after the failed crop trial above. The
  ! failed trial must have consumed neither owner state nor event receipt.
  call bad_crop_kernel%advance_interval(crop_parameters, bad_crop_committed, crop_event_forcing, crop_config, &
       100.0_real64, 101.0_real64, bad_crop_result, bad_crop_candidate, bad_crop_diag, bad_crop_checkpoint)
  call require(bad_crop_result%status == CANONICAL_STATUS_COMPLETED, &
       'F-WOF38 Gate E accepted retry completes')
  call require(bad_crop_candidate%ready(), 'F-WOF38 Gate E accepted retry candidate ready')
  call require(bad_crop_committed%current_revision() == 0, &
       'F-WOF38 Gate E retry remains candidate-only before commit')
  call bad_crop_kernel%commit_candidate(bad_crop_committed, bad_crop_candidate, bad_crop_diag, &
       did_commit, crop_commit_status)
  call require(did_commit, 'F-WOF38 Gate E accepted retry did commit')
  call require(crop_commit_status == KERNEL_COMMIT_STATUS_COMMITTED, &
       'F-WOF38 Gate E accepted retry commit status')
  call require(bad_crop_committed%current_revision() == 1, &
       'F-WOF38 Gate E failed then accepted retry exactly one revision')
  call bad_crop_committed%snapshot(crop_snapshot, snapshot_available)
  call require(snapshot_available, 'F-WOF38 Gate E committed retry snapshot')
  select type (tx => crop_snapshot)
  type is (fmr_wofost_crop_transaction_state_t)
    call tx%snapshot_owner(crop_snapshot_owner, snapshot_available)
    call require(snapshot_available, 'F-WOF38 Gate E retry owner snapshot available')
    call require(same_owner(crop_snapshot_owner, candidate1), &
         'F-WOF38 Gate E retry owner equals direct qualified candidate')
    call require(tx%receipt_ready(), 'F-WOF38 Gate E retry receipt committed')
    call require(tx%consumed_event(event_identity), &
         'F-WOF38 Gate E retry receipt matches accepted source event')
  class default
    call require(.false., 'F-WOF38 Gate E retry committed state type')
  end select
  print '(a)', 'FWOF38_GATE_E_FAILED_THEN_ACCEPTED_RETRY_SAME_CHECKPOINT_EXACTLY_ONCE=PASS'

  ! A policy that permits dt shrinking is not admitted for this fixed one-day
"""
if src.count(anchor) != 1:
    raise SystemExit(f'FWOF38 Gate E insertion anchor count={src.count(anchor)}')
src = src.replace(anchor, insert, 1)

marker_anchor = """    'FWOF38_FAILED_CROP_EVOLUTION_ZERO_OWNER_RECEIPT_MUTATION=PASS' \\
    'FWOF38_FIXED_ONE_DAY_EVENT_FORBIDS_RETRY_DT_SHRINKING=PASS' \\
"""
marker_insert = """    'FWOF38_FAILED_CROP_EVOLUTION_ZERO_OWNER_RECEIPT_MUTATION=PASS' \\
    'FWOF38_GATE_E_FAILED_THEN_ACCEPTED_RETRY_SAME_CHECKPOINT_EXACTLY_ONCE=PASS' \\
    'FWOF38_FIXED_ONE_DAY_EVENT_FORBIDS_RETRY_DT_SHRINKING=PASS' \\
"""
if src.count(marker_anchor) != 1:
    raise SystemExit(f'FWOF38 Gate E marker anchor count={src.count(marker_anchor)}')
src = src.replace(marker_anchor, marker_insert, 1)
path.write_text(src, encoding='utf-8')
PY

bash "$TMP" | tee "$OUT"
grep -Fq 'FWOF38_GATE_E_FAILED_THEN_ACCEPTED_RETRY_SAME_CHECKPOINT_EXACTLY_ONCE=PASS' "$OUT"
grep -Fq 'FWOF38_ATOMIC_CROP_TRANSACTION_O0=PASS' "$OUT"
grep -Fq 'FWOF38_ATOMIC_CROP_TRANSACTION_O2=PASS' "$OUT"
grep -Fq 'FWOF38_ATOMIC_CROP_TRANSACTION_O0_O2_OUTPUT_IDENTITY=PASS' "$OUT"
grep -Fq 'FWOF38_ATOMIC_CROP_TRANSACTION_GATE PASS' "$OUT"
echo 'FWOF38_GATE_E_FAILED_THEN_ACCEPTED_RETRY_GATE PASS'
