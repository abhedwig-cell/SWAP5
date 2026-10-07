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
insert=anchor+"""  type(wofost_potential_shadow_state_t) :: shadow_snapshot
  type(fmr_wofost_root_growth_carrier_t) :: root_growth_snapshot
  logical :: shadow_available, growth_available
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
insert="""  print '(a)', 'SW431_POTENTIAL_SHADOW_ATOMIC_TRANSACTION=PASS'
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
grep -Fq 'SW431_POTENTIAL_SHADOW_ATOMIC_TRANSACTION=PASS' "$OUT"
grep -Fq 'FWOF38_ATOMIC_CROP_TRANSACTION_O0=PASS' "$OUT"
grep -Fq 'FWOF38_ATOMIC_CROP_TRANSACTION_O2=PASS' "$OUT"
grep -Fq 'FWOF38_ATOMIC_CROP_TRANSACTION_O0_O2_OUTPUT_IDENTITY=PASS' "$OUT"
echo 'SW431_POTENTIAL_SHADOW_TRANSACTION_GATE PASS'
