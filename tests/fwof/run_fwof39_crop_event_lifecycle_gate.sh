#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof39-lifecycle-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

DONOR=tests/fwof/run_fwof38_atomic_crop_transaction_gate.sh
EXPECTED_DONOR_BLOB=435ae756e326fc059a771f202eb3d9a144460257
ACTUAL_DONOR_BLOB="$(git hash-object "$DONOR")"
if [[ "$ACTUAL_DONOR_BLOB" != "$EXPECTED_DONOR_BLOB" ]]; then
  echo "F-WOF39 donor drift: expected $EXPECTED_DONOR_BLOB got $ACTUAL_DONOR_BLOB" >&2
  exit 1
fi

python3 - "$DONOR" "$BUILD/run_fwof39_derived.sh" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1]).read_text(encoding='utf-8')

old_root = 'ROOT="$(cd "$(dirname "$0")/../.." && pwd)"\n'
new_root = 'ROOT="${FWOF39_ROOT:?FWOF39_ROOT not set}"\n'
if src.count(old_root) != 1:
    raise SystemExit(f'F-WOF39 donor root anchor count={src.count(old_root)}')
src = src.replace(old_root, new_root, 1)

old = "  use mod_fmr_wofost_crop_transaction\n  use mod_fwof34_test_model\n"
new = "  use mod_fmr_wofost_crop_transaction\n  use mod_fmr_wofost_crop_event_lifecycle\n  use mod_fwof34_test_model\n"
if src.count(old) != 1:
    raise SystemExit(f'F-WOF39 use anchor count={src.count(old)}')
src = src.replace(old, new, 1)

old = "  integer(kind=8) :: crop_revision_before\n"
new = old + "  logical :: lifecycle_retired\n  integer :: lifecycle_status\n"
if src.count(old) != 1:
    raise SystemExit(f'F-WOF39 declaration anchor count={src.count(old)}')
src = src.replace(old, new, 1)

anchor = "  print '(a)', 'FWOF38_ROLLBACK_LEAVES_OWNER_AND_RECEIPT_AT_CHECKPOINT=PASS'\n\n  crop_revision_before = crop_committed%current_revision()\n"
insert = """  print '(a)', 'FWOF38_ROLLBACK_LEAVES_OWNER_AND_RECEIPT_AT_CHECKPOINT=PASS'

  ! Before atomic crop publication there is no matching committed receipt.
  ! Lifecycle reconciliation must therefore be a strict no-op on both the
  ! accepted-window cache and the authoritative committed crop state.
  crop_revision_before = crop_committed%current_revision()
  call reconcile_committed_crop_event_receipt(accepted_window, crop_committed, lifecycle_retired, lifecycle_status)
  call require(lifecycle_status == FMR_WOF39_NO_MATCHING_COMMITTED_RECEIPT, &
       'F-WOF39 precommit no matching receipt status')
  call require(.not. lifecycle_retired, 'F-WOF39 precommit no retirement')
  call require(accepted_window%event_due(), 'F-WOF39 precommit event remains due')
  call require(.not. accepted_window%delivery_committed(), 'F-WOF39 precommit cache unchanged')
  call require(crop_committed%current_revision() == crop_revision_before, 'F-WOF39 precommit revision unchanged')
  call crop_committed%snapshot(crop_snapshot, snapshot_available)
  call require(snapshot_available, 'F-WOF39 precommit crop snapshot')
  select type (tx => crop_snapshot)
  type is (fmr_wofost_crop_transaction_state_t)
    call tx%snapshot_owner(crop_snapshot_owner, snapshot_available)
    call require(snapshot_available .and. same_owner(crop_snapshot_owner, seed), &
         'F-WOF39 precommit owner unchanged')
    call require(.not. tx%receipt_ready(), 'F-WOF39 precommit receipt unchanged')
  class default
    call require(.false., 'F-WOF39 precommit committed state type')
  end select
  print '(a)', 'FWOF39_PRECOMMIT_NO_MATCH_ZERO_MUTATION=PASS'

  crop_revision_before = crop_committed%current_revision()
"""
if src.count(anchor) != 1:
    raise SystemExit(f'F-WOF39 precommit anchor count={src.count(anchor)}')
src = src.replace(anchor, insert, 1)

# Run the lifecycle retirement only after all original F-WOF38 fixtures have
# consumed the still-due source accepted window. This preserves the qualified
# F-WOF38 test semantics while proving that the final stale cache can then be
# retired from the already-committed receipt.
anchor = "final_extra = '''  print '(a)', 'FWOF38_ATOMIC_CROP_TRANSACTION_GATE PASS'\n\ncontains\n'''"
insert = """final_extra = '''  ! F-WOF39 derived lifecycle retirement. The crop publication already
  ! happened above; only the source accepted-window delivery/cache bit may move.
  crop_revision_before = crop_committed%current_revision()
  call reconcile_committed_crop_event_receipt(accepted_window, crop_committed, lifecycle_retired, lifecycle_status)
  call require(lifecycle_status == FMR_WOF39_OK .and. lifecycle_retired, &
       'F-WOF39 matching committed receipt retires window')
  call require(.not. accepted_window%event_due(), 'F-WOF39 retired window event not due')
  call require(accepted_window%delivery_committed(), 'F-WOF39 legacy delivered cache retired')
  call require(crop_committed%current_revision() == crop_revision_before, 'F-WOF39 retirement revision unchanged')
  call crop_committed%snapshot(crop_snapshot, snapshot_available)
  call require(snapshot_available, 'F-WOF39 postretirement committed snapshot')
  select type (tx => crop_snapshot)
  type is (fmr_wofost_crop_transaction_state_t)
    call tx%snapshot_owner(crop_snapshot_owner, snapshot_available)
    call require(snapshot_available .and. same_owner(crop_snapshot_owner, candidate1), &
         'F-WOF39 postretirement owner unchanged')
    call require(tx%receipt_ready(), 'F-WOF39 postretirement receipt still ready')
    call require(tx%consumed_event(event_identity), 'F-WOF39 postretirement receipt unchanged')
  class default
    call require(.false., 'F-WOF39 postretirement committed state type')
  end select
  print '(a)', 'FWOF39_MATCHING_RECEIPT_RETIREMENT_ONLY=PASS'
  print '(a)', 'FWOF39_OWNER_RECEIPT_REVISION_UNCHANGED=PASS'

  ! Reconciliation is idempotent after the legacy cache has been retired.
  crop_revision_before = crop_committed%current_revision()
  call reconcile_committed_crop_event_receipt(accepted_window, crop_committed, lifecycle_retired, lifecycle_status)
  call require(lifecycle_status == FMR_WOF39_ALREADY_RETIRED, 'F-WOF39 replay already retired status')
  call require(.not. lifecycle_retired, 'F-WOF39 replay reports zero new retirement')
  call require(.not. accepted_window%event_due(), 'F-WOF39 replay event remains not due')
  call require(crop_committed%current_revision() == crop_revision_before, 'F-WOF39 replay revision unchanged')
  call crop_committed%snapshot(crop_snapshot, snapshot_available)
  call require(snapshot_available, 'F-WOF39 replay committed snapshot')
  select type (tx => crop_snapshot)
  type is (fmr_wofost_crop_transaction_state_t)
    call tx%snapshot_owner(crop_snapshot_owner, snapshot_available)
    call require(snapshot_available .and. same_owner(crop_snapshot_owner, candidate1), &
         'F-WOF39 replay owner unchanged')
    call require(tx%receipt_ready() .and. tx%consumed_event(event_identity), &
         'F-WOF39 replay receipt unchanged')
  class default
    call require(.false., 'F-WOF39 replay committed state type')
  end select
  print '(a)', 'FWOF39_REPLAY_IDEMPOTENT_ZERO_MUTATION=PASS'
  print '(a)', 'FWOF38_ATOMIC_CROP_TRANSACTION_GATE PASS'

contains
'''"""
if src.count(anchor) != 1:
    raise SystemExit(f'F-WOF39 final lifecycle anchor count={src.count(anchor)}')
src = src.replace(anchor, insert, 1)

old = "  src/runtime/mod_fmr_wofost_crop_transaction.f90\n)"
new = "  src/runtime/mod_fmr_wofost_crop_transaction.f90\n  src/runtime/mod_fmr_wofost_crop_event_lifecycle.f90\n)"
if src.count(old) != 1:
    raise SystemExit(f'F-WOF39 source-list anchor count={src.count(old)}')
src = src.replace(old, new, 1)

# Make redirected runtime assertion failures visible in CI without relaxing any
# existing marker or O0/O2 identity requirement.
old = "  ./test > output.txt 2>&1\n"
new = "  ./test > output.txt 2>&1 || { cat output.txt >&2; exit 1; }\n"
if src.count(old) != 1:
    raise SystemExit(f'F-WOF39 runtime diagnostic anchor count={src.count(old)}')
src = src.replace(old, new, 1)

Path(sys.argv[2]).write_text(src, encoding='utf-8')
PY
chmod +x "$BUILD/run_fwof39_derived.sh"

FWOF39_ROOT="$ROOT" bash "$BUILD/run_fwof39_derived.sh" | tee "$BUILD/output.txt"
for marker in \
  'FWOF39_PRECOMMIT_NO_MATCH_ZERO_MUTATION=PASS' \
  'FWOF39_MATCHING_RECEIPT_RETIREMENT_ONLY=PASS' \
  'FWOF39_OWNER_RECEIPT_REVISION_UNCHANGED=PASS' \
  'FWOF39_REPLAY_IDEMPOTENT_ZERO_MUTATION=PASS' \
  'FWOF38_ATOMIC_CROP_TRANSACTION_O0_O2_OUTPUT_IDENTITY=PASS' \
  'FWOF38_ATOMIC_CROP_TRANSACTION_GATE PASS'; do
  grep -Fq "$marker" "$BUILD/output.txt" || { cat "$BUILD/output.txt" >&2; exit 1; }
done

echo 'FWOF39_LIFECYCLE_RETIREMENT_GATE PASS'
