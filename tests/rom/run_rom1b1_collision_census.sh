#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
PREREG_COMMIT=cdaf8b7181c07bf6eaa97504401c34949a7c3c0d
D3_EXEC_HEAD=e582c6ca3471388cd90de746f0ff281721690950
PREREG=integration/f-rom/ROM1B1_PREREGISTRATION.json
ROM1A_CLOSE=integration/f-rom/F-ROM1A_SUCCESSOR_CLOSEOUT.json
D3_STATUS=integration/f-rom/ROM1AR1D3_STATUS.json
TEST=tests/rom/test_rom1ar1d3_discovery_fallback.f90
ANALYZER=tests/rom/analyze_rom1b1_collision_census.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rom1b1-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${ROM1B1_EVIDENCE_DIR:-$ROOT/ROM1B1_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "ROM1B1_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG_COMMIT" HEAD || fail "B1 preregistration not ancestor"
git diff --quiet "$PREREG_COMMIT"...HEAD -- src reference || fail "B1 changed src/reference"
git diff --quiet "$D3_EXEC_HEAD"...HEAD -- "$TEST" || fail "B1 discovery generator drifted since D3 qualification"
echo "ROM1B1_SOURCE_AND_GENERATOR_FREEZE=PASS"

python3 - "$PREREG" "$ROM1A_CLOSE" "$D3_STATUS" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); c=json.load(open(sys.argv[2])); d=json.load(open(sys.argv[3]))
assert p["phase"]=="PREREGISTERED_BEFORE_COLLISION_CENSUS"
assert p["collision_authority"]["theta_floor"]==0.0005420462931603476
assert p["data_firewall"]["held_out_histories_used"] is False
assert p["data_firewall"]["B14_used"] is False
assert p["data_firewall"]["future_probe_outcomes_generated_in_B1"] is False
assert c["decision"]=="PROCEED_TO_ROM1B"
assert d["decision"]=="ROM1AR1D3_DISCOVERY_LOCAL_PLUS_TOTAL_FALLBACK_QUALIFIED"
print("ROM1B1_AUTHORITY_LOCK=PASS")
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10
python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/stubs_n16.f90"   --target "$TEST" --external-source src/legacy/b1_10_port/headcalc.f90   --build "$BUILD/o2" --opt 2
"$BUILD/o2/rom0_test" > "$EVIDENCE/discovery.txt" 2>&1 || {
  tail -n 300 "$EVIDENCE/discovery.txt" >&2; fail "B1 discovery regeneration"
}
"$BUILD/o2/rom0_test" > "$EVIDENCE/discovery-repeat.txt" 2>&1 || {
  tail -n 300 "$EVIDENCE/discovery-repeat.txt" >&2; fail "B1 discovery repeat"
}
cmp "$EVIDENCE/discovery.txt" "$EVIDENCE/discovery-repeat.txt" || fail "B1 discovery repeat drift"

python3 "$ANALYZER" --input "$EVIDENCE/discovery.txt" --repeat "$EVIDENCE/discovery-repeat.txt"   --output "$EVIDENCE/ROM1B1_RESULT.json" | tee "$EVIDENCE/analyzer.txt"
cat "$EVIDENCE/ROM1B1_RESULT.json"
cat "$EVIDENCE/ROM1B1_PAIR_MANIFEST.json"
sha256sum "$EVIDENCE/discovery.txt" "$EVIDENCE/ROM1B1_RESULT.json"   "$EVIDENCE/ROM1B1_PAIR_MANIFEST.json" > "$EVIDENCE/sha256.txt"
git diff --check "$PREREG_COMMIT"...HEAD
echo "ROM1B1_EVIDENCE_PRESERVED=PASS"
