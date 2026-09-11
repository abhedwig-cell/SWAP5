#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

UPSTREAM=277dda9b7d808ca4e3233488e087e4e2179ddc2a
fail(){ echo "FGC08_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$UPSTREAM" HEAD || fail 'branch is not descended from qualified F-GC07 closeout'
if ! git diff --quiet "$UPSTREAM" HEAD -- src; then
  fail 'F-GC08 changed production source'
fi
echo 'FGC08_PRODUCTION_SOURCE_UNCHANGED=PASS'

python3 - <<'PY'
import json
from pathlib import Path

root = Path('.')
pre = json.loads((root/'integration/f-gc/F-GC08_PRE_REGISTRATION.json').read_text())
ev = json.loads((root/'integration/f-gc/F-GC08_RESEARCH_EVIDENCE.json').read_text())

assert pre['work_unit'] == 'F-GC08'
assert pre['upstream']['F_GC07_closeout_head'] == '277dda9b7d808ca4e3233488e087e4e2179ddc2a'
assert pre['frozen_application_class']['id'] == 'AC02_GW_MANAGEMENT_HEAD_THRESHOLD'
assert pre['acceptance_rule']['threshold_alone_is_H_app'] is False
assert pre['acceptance_rule']['calibration_residual_is_H_app'] is False
assert pre['acceptance_rule']['solver_closure_criterion_is_H_app'] is False
assert pre['mass_contract']['mass_conservation_is_absolute'] is True

q = ev['qualification_result']
assert q['external_threshold_found'] is True
assert q['external_policy_recognizes_model_accuracy_near_threshold'] is True
assert q['transferable_numeric_prediction_error_found'] is False
assert q['numeric_H_app_defensible'] is False
assert q['numeric_A_temporal_defensible'] is False
assert q['numeric_H_budget_defensible'] is False
assert q['decision'] == 'FAIL_CLOSED_EXTERNAL_THRESHOLD_NOT_EQUIVALENT_TO_APPLICATION_PREDICTION_ACCURACY_REQUIREMENT'
assert ev['F_GC02_inspected'] is False
assert ev['F_GC02_executed'] is False
assert ev['production_source_changed'] is False
assert ev['architecture_consequence']['mass_contract'] == 'q_SWAP = -q_GW remains absolute and is not part of the accuracy trade-off'

close = root/'integration/f-gc/F-GC08_CLOSEOUT.json'
if close.exists():
    c = json.loads(close.read_text())
    assert c['decision'] == q['decision']
    assert c['qualified_numeric_H_app'] is False
    assert c['production_admission'] is False
    assert c['production_source_changed'] is False
    assert c['F_GC07_reopened'] is False
    assert c['F_GC06_reopened'] is False
    assert c['mass_conservation_relaxed'] is False

print('FGC08_PRE_REGISTRATION_LOCK=PASS')
print('FGC08_EXTERNAL_POLICY_STRUCTURE=PASS')
print('FGC08_NO_NUMERIC_HAPP_INFERENCE=PASS')
print('FGC08_NO_TARGET_LEAKAGE=PASS')
print('FGC08_MASS_CONTRACT=PASS')
print('FGC08_RESEARCH_GATE PASS')
PY
