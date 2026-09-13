#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

CANONICAL=df51575e18777856a47a5d0d1e2e1c7456be4601
fail(){ echo "EB_I12_GATE_FAIL $*" >&2; exit 120; }

git fetch --no-tags origin integration/f-ci-canonical >/dev/null 2>&1 || fail 'cannot fetch current canonical'
CURRENT="$(git rev-parse origin/integration/f-ci-canonical)"
[[ "$CURRENT" == "$CANONICAL" ]] || fail "canonical race: expected $CANONICAL got $CURRENT"
echo 'EB_I12_CURRENT_CANONICAL_RACE_GUARD=PASS'

# Contract-freeze means no production source changes at all.
git diff --quiet "$CANONICAL"..HEAD -- src || fail 'production source changed in contract-freeze workunit'
echo 'EB_I12_ZERO_PRODUCTION_DELTA=PASS'

# Exact evidence delta after persistence.
mapfile -t changed < <(git diff --name-only "$CANONICAL"..HEAD | sort)
printf '%s\n' "${changed[@]}" > /tmp/eb_i12_changed.txt
cat > /tmp/eb_i12_allowed.txt <<'EOF'
.github/workflows/eb-i12-contract-gate.yml
tests/eb/EB-I12_ARCHITECTURE_AUDIT.json
tests/eb/EB-I12_CONTRACT.md
tests/eb/run_eb_i12_contract_gate.sh
EOF
sort -o /tmp/eb_i12_allowed.txt /tmp/eb_i12_allowed.txt
diff -u /tmp/eb_i12_allowed.txt /tmp/eb_i12_changed.txt || fail 'unexpected workunit delta'
echo 'EB_I12_EXACT_CONTRACT_FREEZE_DELTA=PASS'

TX=src/transaction/mod_transaction_reference.f90
RT=src/runtime/mod_canonical_interval_runtime.f90
BE=src/runtime/mod_fmr_serialized_reference_backend.f90

# The design depends on existing generic attempt-context rollback/select semantics.
grep -Fq 'type, public :: transaction_attempt_context_t' "$TX" || fail 'attempt context type missing'
grep -Fq 'call model%capture_attempt_context(checkpoint_context)' "$TX" || fail 'checkpoint attempt capture missing'
grep -Fq 'call model%restore_attempt_context(checkpoint_context)' "$TX" || fail 'checkpoint attempt restore missing'
grep -Fq 'call model%capture_attempt_context(half_context)' "$TX" || fail 'half-route context capture missing'
grep -Fq 'call model%restore_attempt_context(half_context)' "$TX" || fail 'selected half-route context restore missing'
grep -Fq 'result%accepted_route = TX_ROUTE_TWO_HALF' "$TX" || fail 'two-half accepted route missing'
echo 'EB_I12_ATTEMPT_CONTEXT_ROUTE_SELECTION_AUTHORITY=PASS'

# Prove the history-loss fact: two half bottom transfers are aggregated in the transaction result.
grep -Fq 'result%accepted_bottom_outward_exchange_native = half1_outcome%bottom_outward_exchange_native +' "$TX" || \
  fail 'two-half bottom aggregation source fact missing'
grep -Fq 'half2_outcome%bottom_outward_exchange_native' "$TX" || fail 'second-half bottom aggregation source fact missing'
grep -Fq 'call move_alloc(half_state, committed)' "$TX" || fail 'selected terminal half state source fact missing'
echo 'EB_I12_TWO_HALF_THERMAL_HISTORY_LOSS_SOURCE_FACT=PASS'

# Current canonical outer runtime aggregates accepted transaction water only after selection.
grep -Fq 'call accumulate_accepted_bottom_interface' "$RT" || fail 'accepted bottom accumulation missing'
grep -Fq 'if (tx%status /= TX_STATUS_ACCEPTED) return' "$RT" || fail 'accepted-only guard missing'
echo 'EB_I12_ACCEPTED_BOTTOM_WATER_AUTHORITY=PASS'

# Restricted thermal solve is still produced inside the physical model trial.
grep -Fq 'call trial_restricted_soil_temperature' "$BE" || fail 'restricted thermal trial call missing'
grep -Fq 'physical%soil_temperature' "$BE" || fail 'thermal trial start state source missing'
grep -Fq 'soil_temperature_trial' "$BE" || fail 'thermal trial end state source missing'
echo 'EB_I12_SAME_MODEL_ADVANCE_THERMAL_ENDPOINTS_AVAILABLE=PASS'

python3 - <<'PY'
import json
from pathlib import Path
p=Path('tests/eb/EB-I12_ARCHITECTURE_AUDIT.json')
a=json.loads(p.read_text())
assert a['restart_authority']=='integration/f-ci-canonical@df51575e18777856a47a5d0d1e2e1c7456be4601'
assert a['decision']=='DESIGN_FROZEN_NO_PRODUCTION_IMPLEMENTATION'
assert a['production_delta']==[]
inv=a['invariants']
assert len(inv)==30
assert [row['id'] for row in inv]==list(range(1,31))
assert all(row['status'] in {'pass','preserved','bounded_nonclaim'} for row in inv)
assert len(a['semantic_attacks']) >= 10
print('EB_I12_ALL_30_ARCHITECTURE_INVARIANTS_RECONCILED=PASS')
print('EB_I12_SEMANTIC_ATTACK_MATRIX_PRESENT=PASS')
PY

grep -Fq 'worker-local transaction attempt context' tests/eb/EB-I12_CONTRACT.md || fail 'worker scratch decision missing'
grep -Fq 'does **not** collapse these two endpoint values' tests/eb/EB-I12_CONTRACT.md || fail 'quadrature nonclaim missing'
grep -Fq 'must not substitute local bottom-soil temperature' tests/eb/EB-I12_CONTRACT.md || fail 'external donor fail-closed rule missing'
grep -Fq 'no extra Richards or restricted thermal solve' tests/eb/EB-I12_CONTRACT.md || fail 'no-extra-solve rule missing'
git diff --check "$CANONICAL" -- .github/workflows/eb-i12-contract-gate.yml tests/eb || fail 'diff check failed'
echo 'EB_I12_CONTRACT_CONTENT_AND_DIFF_CHECK=PASS'
echo 'EB_I12_CONTRACT_GATE PASS'
