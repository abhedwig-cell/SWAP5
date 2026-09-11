#!/usr/bin/env bash
set -euo pipefail

CANONICAL_BASE="c7379b6b5b5f529ff96de3087379712bd665276a"
PREREG="integration/f-gc/F-GC12_PRE_REGISTRATION.json"
EVIDENCE="integration/f-gc/F-GC12_RESEARCH_EVIDENCE.json"

fail() {
  echo "FGC12_GATE_FAIL: $*" >&2
  exit 1
}

git cat-file -e "${CANONICAL_BASE}^{commit}" || fail "canonical base unavailable"
git merge-base --is-ancestor "${CANONICAL_BASE}" HEAD || fail "branch is not descended from F-CI45P canonical authority"
echo "FGC12_CANONICAL_BASE=PASS"

src_delta="$(git diff --name-only "${CANONICAL_BASE}"..HEAD -- src || true)"
[[ -z "${src_delta}" ]] || fail "production source changed: ${src_delta}"
echo "FGC12_NO_PRODUCTION_SOURCE_DELTA=PASS"

[[ -f "${PREREG}" ]] || fail "missing preregistration"
[[ -f "${EVIDENCE}" ]] || fail "missing research evidence"
python3 - <<'PY'
import json
for path in (
    'integration/f-gc/F-GC12_PRE_REGISTRATION.json',
    'integration/f-gc/F-GC12_RESEARCH_EVIDENCE.json',
):
    with open(path, encoding='utf-8') as f:
        json.load(f)
print('FGC12_JSON_VALIDATION=PASS')
PY

grep -q 'Western Harbour Tunnel and Warringah Freeway Upgrade' "${PREREG}" || fail "project identity not frozen"
grep -q 'SSI-8863' "${PREREG}" || fail "approval id not frozen"
grep -q 'SSI-8863' "${EVIDENCE}" || fail "evidence project mismatch"
echo "FGC12_PROJECT_IDENTITY=PASS"

grep -q '"quantitative_predictive_uncertainty_required": true' "${EVIDENCE}" || fail "project uncertainty requirement missing"
grep -q '"independent_peer_review_required": true' "${EVIDENCE}" || fail "peer review requirement missing"
echo "FGC12_PROJECT_UNCERTAINTY_GOVERNANCE=PASS"

grep -q '"numeric_H_app_found": false' "${EVIDENCE}" || fail "numeric H_app must remain unavailable"
grep -q '"numeric_A_temporal_found": false' "${EVIDENCE}" || fail "numeric A_temporal must remain unavailable"
grep -q '"direct_numeric_temporal_budget_found": false' "${EVIDENCE}" || fail "direct temporal budget must remain unavailable"
grep -q '"numeric_H_temporal_budget_ready": false' "${EVIDENCE}" || fail "temporal budget must remain unavailable"
echo "FGC12_NUMERIC_H_APP=NOT_QUALIFIED"
echo "FGC12_NUMERIC_A_TEMPORAL=NOT_QUALIFIED"
echo "FGC12_NUMERIC_TEMPORAL_BUDGET=NOT_QUALIFIED"

grep -q '"physical_inflow_limit_is_H_app": false' "${EVIDENCE}" || fail "physical inflow criterion shortcut not rejected"
grep -q '"calibration_statistics_are_H_app": false' "${EVIDENCE}" || fail "calibration shortcut not rejected"
grep -q '"model_prediction_interval_is_H_app_without_external_acceptance_rule": false' "${EVIDENCE}" || fail "uncertainty-band shortcut not rejected"
grep -q '"model_time_step_schedule_is_A_temporal": false' "${EVIDENCE}" || fail "time-step shortcut not rejected"
echo "FGC12_NO_HIDDEN_NUMERIC_POLICY=PASS"

grep -q '"materialize_model_temporal_budget": false' "${EVIDENCE}" || fail "budget materialization must be disabled"
grep -q '"no_positive_budget_materialized": true' "${EVIDENCE}" || fail "positive budget unexpectedly materialized"
echo "FGC12_CONTRACT_INSTANTIATION_FAIL_CLOSED=PASS"

grep -q 'FAIL_CLOSED_WHT_PROJECT_DOES_NOT_SUPPLY_ADMISSIBLE_NUMERIC_H_APP_AND_TEMPORAL_ALLOCATION' "${EVIDENCE}" || fail "fail-closed decision missing"
grep -q '"mass_conservation_policy_unchanged": true' "${EVIDENCE}" || fail "mass-conservation nonrelaxation missing"
echo "FGC12_MASS_CONSERVATION_RELAXED=NO"

echo "FGC12_WHT_PROJECT_SPECIFIC_ACCURACY_GATE PASS"
