#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-p2e09-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "PUB_P2E09_GATE_FAIL $*" >&2; exit 1; }

PREREG=docs/publication/P2E09_REFERENCE_ONLY_THRESHOLD_FREEZE_PREREGISTRATION.json
VALIDATOR=tests/publication/validate_pub_p2e09_reference_thresholds.py
P2E08_RUNNER=tests/publication/run_pub_p2e08_reference_valid_calibration_domain.sh
PREREGISTERED_BASE=b7e48275ebfba5ba888685f7515005c7195d5d73\nRECONCILED_BASE=6a77678b535ed468bdeeb9b67f149be706f0205f
P2E08_RESULT_BLOB=fbfa1309a6297568a6811583db809363da5a7e6f
DESIGN_BLOB=3a906232441e09f09442731e212ca705ad547354
PAPER2_BLOB=b94fb98e7e52c5c08ddad92addaa393bdcedb681

[[ -f "$PREREG" ]] || fail 'missing P2E09 preregistration'
[[ -f "$VALIDATOR" ]] || fail 'missing P2E09 validator'
[[ -f "$P2E08_RUNNER" ]] || fail 'missing admitted P2E08 runner'

grep -Fq '"phase": "PREREGISTERED_THRESHOLD_FREEZE_BEFORE_BROAD_ROSSFAST_EVALUATION"' "$PREREG" || fail 'threshold-freeze phase missing'
grep -Fq '"new_rossfast_solver_execution_allowed": false' "$PREREG" || fail 'RossFast execution firewall missing'
grep -Fq '"historical_stage0_b01_rossfast_metrics_allowed_in_rule_choice": false' "$PREREG" || fail 'Stage0 quarantine missing'
grep -Fq '"reference_factor": 1.0' "$PREREG" || fail 'factor-one rule missing'
grep -Fq '"stratify_by": "effective_saturation"' "$PREREG" || fail 'Se stratification missing'

git merge-base --is-ancestor "$PREREGISTERED_BASE" HEAD || fail 'P2E09 preregistered base is not an ancestor'
git merge-base --is-ancestor "$RECONCILED_BASE" HEAD || fail 'P2E09 reconciled base is not an ancestor'
git diff --quiet "$RECONCILED_BASE" HEAD -- src reference || fail 'P2E09 mutated src or reference relative to reconciled canonical'
test "$(git rev-parse HEAD:docs/publication/P2E08_REFERENCE_VALID_CALIBRATION_DOMAIN_RESULT.json)" = "$P2E08_RESULT_BLOB" || fail 'P2E08 result authority drift'
test "$(git rev-parse HEAD:docs/publication/P2_ADMISSIBILITY_ENVELOPE_DESIGN.md)" = "$DESIGN_BLOB" || fail 'admissibility design drift'
test "$(git rev-parse HEAD:docs/publication/PAPER2_SOLVER_ADMISSIBILITY_RESEARCH_DESIGN.md)" = "$PAPER2_BLOB" || fail 'Paper2 research design drift'

# Replay the admitted Reference-only P2E08 extraction. Its runner itself locks
# the Reference/material dependencies, excludes the RossFast numerical kernel,
# checks O0/O2 byte identity and requires all 270 preregistered trial pairs.
bash "$P2E08_RUNNER" > "$BUILD/p2e08.txt" 2>&1 || {
  cat "$BUILD/p2e08.txt" >&2
  fail 'admitted P2E08 Reference replay'
}
cat "$BUILD/p2e08.txt"

grep -Fq 'PUB_P2E08_ROSSFAST_SOLVER_EXECUTED=FALSE' "$BUILD/p2e08.txt" || fail 'P2E08 RossFast firewall marker missing'
grep -Fq 'PUB_P2E08_SELECTED_COARSE_DT_DAY=0.64000000000000003E-2' "$BUILD/p2e08.txt" || fail 'P2E08 selected coarse dt drift'
grep -Fq 'PUB_P2E08_SELECTED_VALID_CASE_COUNT=54' "$BUILD/p2e08.txt" || fail 'P2E08 complete-domain count drift'
grep -Fq 'PUB_P2E08_COMMON_DOMAIN_STATUS=QUALIFIED_COMPLETE_REFERENCE_DOMAIN' "$BUILD/p2e08.txt" || fail 'P2E08 complete-domain authority drift'

python3 "$VALIDATOR" "$BUILD/p2e08.txt" "$PREREG" | tee "$BUILD/p2e09.txt"

for marker in   'PUB_P2E09_REFERENCE_CASE_COUNT=54'   'PUB_P2E09_CASES_PER_SE=18'   'PUB_P2E09_STRATIFICATION=EFFECTIVE_SATURATION_ONLY'   'PUB_P2E09_REFERENCE_FACTOR=1'   'PUB_P2E09_APPLICATION_RESOLUTION_FLOOR=ZERO'   'PUB_P2E09_ROSSFAST_BROAD_RESULTS_USED=FALSE'   'PUB_P2E09_THRESHOLD_VALIDATION=PASS'; do
  grep -Fq "$marker" "$BUILD/p2e09.txt" || fail "missing marker $marker"
done

count="$(grep -Fc 'PUB_P2E09_THRESHOLD|' "$BUILD/p2e09.txt")"
[[ "$count" = "15" ]] || fail "expected 15 frozen metric thresholds, got $count"

echo "PUB_P2E09_THRESHOLD_OUTPUT_SHA256=$(sha256sum "$BUILD/p2e09.txt" | awk '{print $1}')"
echo 'PUB_P2E09_REFERENCE_ONLY_THRESHOLD_FREEZE_GATE=PASS'
