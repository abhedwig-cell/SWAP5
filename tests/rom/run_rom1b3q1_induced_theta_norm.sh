#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PREREG_COMMIT=58ffd0ebfc7ece716ffcff39003224258c3d4514
B1_EXEC_HEAD=01312dd2e72ff61123c0dcdfe99e1fda91e80861
D3_EXEC_HEAD=e582c6ca3471388cd90de746f0ff281721690950
PREREG=integration/f-rom/ROM1B3Q1_PREREGISTRATION.json
B3_STATUS=integration/f-rom/ROM1B3_STATUS.json
TEST=tests/rom/test_rom1ar1d3_discovery_fallback.f90
ANALYZER=tests/rom/analyze_rom1b3q1_induced_theta_norm.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rom1b3q1-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${ROM1B3Q1_EVIDENCE_DIR:-$ROOT/ROM1B3Q1_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "ROM1B3Q1_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG_COMMIT" HEAD || fail "B3Q1 preregistration not ancestor"
git diff --quiet "$PREREG_COMMIT"...HEAD -- src reference || fail "B3Q1 changed src/reference"
git diff --quiet "$B1_EXEC_HEAD"...HEAD -- "$TEST" || fail "B3Q1 discovery generator drifted since B1"
git diff --quiet "$D3_EXEC_HEAD"...HEAD -- "$TEST" || fail "B3Q1 discovery generator drifted since D3"
echo "ROM1B3Q1_SOURCE_AND_GENERATOR_FREEZE=PASS"

python3 - "$PREREG" "$B3_STATUS" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); b=json.load(open(sys.argv[2]))
assert p["phase"]=="PREREGISTERED_BEFORE_INDUCED_NORM_CENSUS"
assert p["unchanged_authority"]["subset_count"]==256
assert p["unchanged_authority"]["theta_floor"]==0.0005420462931603476
assert p["unchanged_authority"]["heldout_used"] is False
assert p["unchanged_authority"]["B14_used"] is False
assert p["unchanged_authority"]["future_probe_outcomes_used_for_subset_selection"] is False
assert b["decision"]=="ROM1B3_NO_REDUCED_STATE_SEPARATING_ENRICHMENT"
assert b["full_invertible_control_collision_count"]==2187
assert b["original_B3_result_reclassified"] is False
print("ROM1B3Q1_AUTHORITY_LOCK=PASS")
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10
python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/stubs_n16.f90"   --target "$TEST" --external-source src/legacy/b1_10_port/headcalc.f90   --build "$BUILD/o2" --opt 2

"$BUILD/o2/rom0_test" > "$EVIDENCE/discovery.txt" 2>&1 || {
  tail -n 300 "$EVIDENCE/discovery.txt" >&2
  fail "B3Q1 discovery regeneration"
}
"$BUILD/o2/rom0_test" > "$EVIDENCE/discovery-repeat.txt" 2>&1 || {
  tail -n 300 "$EVIDENCE/discovery-repeat.txt" >&2
  fail "B3Q1 discovery repeat"
}
cmp "$EVIDENCE/discovery.txt" "$EVIDENCE/discovery-repeat.txt" || fail "B3Q1 discovery repeat drift"

python3 "$ANALYZER" --input "$EVIDENCE/discovery.txt" --repeat "$EVIDENCE/discovery-repeat.txt"   --prereg "$PREREG" --output "$EVIDENCE/ROM1B3Q1_RESULT.json" | tee "$EVIDENCE/analyzer.txt"
cat "$EVIDENCE/ROM1B3Q1_RESULT.json"
sha256sum "$EVIDENCE/discovery.txt" "$EVIDENCE/ROM1B3Q1_RESULT.json" "$EVIDENCE/analyzer.txt"   > "$EVIDENCE/sha256.txt"
git diff --check "$PREREG_COMMIT"...HEAD
echo "ROM1B3Q1_EVIDENCE_PRESERVED=PASS"
