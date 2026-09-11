#!/usr/bin/env bash
set -euo pipefail

CANONICAL_BASE="e342f4f9c9d45e2ec2d23a6be6032cc0498d98e2"
PREREG="integration/f-gc/F-GC11_PRE_REGISTRATION.json"
EVIDENCE="integration/f-gc/F-GC11_RESEARCH_EVIDENCE.json"

fail() {
  echo "FGC11_GATE_FAIL: $*" >&2
  exit 1
}

git cat-file -e "${CANONICAL_BASE}^{commit}" || fail "canonical base is unavailable"
git merge-base --is-ancestor "${CANONICAL_BASE}" HEAD || fail "branch is not descended from frozen F-CI44P canonical authority"

echo "FGC11_CANONICAL_BASE=PASS"

src_delta="$(git diff --name-only "${CANONICAL_BASE}"..HEAD -- src || true)"
[[ -z "${src_delta}" ]] || fail "production source changed: ${src_delta}"
echo "FGC11_NO_PRODUCTION_SOURCE_DELTA=PASS"

[[ -f "${PREREG}" ]] || fail "missing preregistration"
[[ -f "${EVIDENCE}" ]] || fail "missing research evidence"
python3 - <<'PY'
import json
for path in (
    'integration/f-gc/F-GC11_PRE_REGISTRATION.json',
    'integration/f-gc/F-GC11_RESEARCH_EVIDENCE.json',
):
    with open(path, encoding='utf-8') as f:
        json.load(f)
print('FGC11_JSON_VALIDATION=PASS')
PY

grep -q 'AC03_NSW_SSD_SSI_AQUIFER_INTERFERENCE_DRAWDOWN_DECISION' "${PREREG}" || fail "application class not frozen"
grep -q 'AC03_NSW_SSD_SSI_AQUIFER_INTERFERENCE_DRAWDOWN_DECISION' "${EVIDENCE}" || fail "application class mismatch"
grep -q 'FAIL_CLOSED_AC03_NO_INDEPENDENT_NUMERIC_H_APP_OR_TEMPORAL_ALLOCATION' "${EVIDENCE}" || fail "fail-closed decision missing"
echo "FGC11_APPLICATION_CLASS_BINDING=PASS"

grep -q '"external_decision_margin_structure_exists": true' "${EVIDENCE}" || fail "external decision-margin structure not evidenced"
grep -q '"numeric_H_app_found": false' "${EVIDENCE}" || fail "numeric H_app must remain unqualified"
grep -q '"numeric_A_temporal_found": false' "${EVIDENCE}" || fail "numeric A_temporal must remain unqualified"
grep -q '"numeric_H_temporal_budget_ready": false' "${EVIDENCE}" || fail "numeric temporal budget must remain unavailable"
echo "FGC11_EXTERNAL_DECISION_MARGIN_STRUCTURE=PASS"
echo "FGC11_NUMERIC_H_APP=NOT_QUALIFIED"
echo "FGC11_NUMERIC_A_TEMPORAL=NOT_QUALIFIED"
echo "FGC11_NUMERIC_TEMPORAL_BUDGET=NOT_QUALIFIED"

grep -q 'NSW Aquifer Interference Policy' "${EVIDENCE}" || fail "NSW AIP provenance missing"
grep -q 'Minimum Groundwater Modelling Requirements for SSD/SSI Projects' "${EVIDENCE}" || fail "NSW modelling guideline provenance missing"
grep -q 'Information Guidelines Explanatory Note: Uncertainty analysis for groundwater modelling' "${EVIDENCE}" || fail "IESC provenance missing"
echo "FGC11_EXTERNAL_PROVENANCE_SET=PASS"

grep -q 'physical_threshold_reuse_rejected": true' "${EVIDENCE}" || fail "physical threshold shortcut not explicitly rejected"
grep -q 'calibration_metric_reuse_rejected": true' "${EVIDENCE}" || fail "calibration shortcut not explicitly rejected"
grep -q 'F_GC07_back_calculation_rejected": true' "${EVIDENCE}" || fail "GC07 back-calculation shortcut not explicitly rejected"
echo "FGC11_NO_HIDDEN_NUMERIC_POLICY=PASS"

grep -q 'No mass-conservation tolerance is introduced' "${EVIDENCE}" || fail "mass nonclaim missing"
echo "FGC11_MASS_CONSERVATION_RELAXED=NO"

echo "FGC11_NSW_APPLICATION_CLASS_ACCURACY_GATE PASS"
