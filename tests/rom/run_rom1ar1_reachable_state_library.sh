#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PREREG_COMMIT=278c8d33b7e4b43d771340ce54baac55903add67
PREREG=integration/f-rom/ROM1AR1_PREREGISTRATION.json
PARENT=integration/f-rom/F-ROM1A_PREREGISTRATION.json
D2_STATUS=integration/f-rom/ROM1AD2_STATUS.json
D4_STATUS=integration/f-rom/F-ROM0R_R3D4_STATUS.json
TEST=tests/rom/test_rom1ar1_reachable_state_library.f90
ANALYZER=tests/rom/analyze_rom1ar1_reachable_state_library.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rom1ar1-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${ROM1AR1_EVIDENCE_DIR:-$ROOT/ROM1AR1_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "ROM1AR1_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG_COMMIT" HEAD || fail "R1 preregistration not ancestor"
git diff --quiet "$PREREG_COMMIT"...HEAD -- src reference || fail "R1 changed src/reference"
echo "ROM1AR1_SOURCE_FREEZE=PASS"

python3 - "$PREREG" "$PARENT" "$D2_STATUS" "$D4_STATUS" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
p=json.load(open(sys.argv[2]))
d2=json.load(open(sys.argv[3]))
d4=json.load(open(sys.argv[4]))
assert r["phase"]=="PREREGISTERED_BEFORE_SUCCESSOR_LIBRARY_EXECUTION"
assert r["history_design"]["must_equal_parent_preregistration"] is True
assert r["history_design"]["steps_per_history"]==p["history_design"]["history_length_steps"]==64
assert r["history_design"]["discovery_histories"]==[x["id"] for x in p["history_design"]["discovery_histories"]]
assert r["history_design"]["held_out_histories"]==[x["id"] for x in p["history_design"]["held_out_histories"]]
assert r["history_design"]["discovery_state_count"]==512
assert r["history_design"]["held_out_state_count"]==256
assert r["history_design"]["total_state_count"]==768
assert r["history_design"]["step_dt_day"]==p["history_design"]["step_day"]==0.0008
assert r["material_firewall"]["generated_material"]=="B01"
assert r["material_firewall"]["B14_generated"] is False
assert d2["decision"]=="ROM1AD2_MODE2_FAIL_CLOSED_FALLBACK_QUALIFIED"
assert d2["mode2_research_fallback_qualified"] is True
assert d4["decision"]=="R3_FAIL_CLOSED_TOTAL_ONLY_FALLBACK_QUALIFIED"
assert d4["research_reference_fallback_qualified"] is True
assert r["fallback_contract"]["failed_residual_used_to_choose_tolerance"] is False
print("ROM1AR1_AUTHORITY_LOCK=PASS")
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10
python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/stubs_n16.f90"   --target "$TEST" --external-source src/legacy/b1_10_port/headcalc.f90   --build "$BUILD/o2" --opt 2

"$BUILD/o2/rom0_test" > "$EVIDENCE/library.txt" 2>&1 || {
  tail -n 250 "$EVIDENCE/library.txt" >&2
  fail "R1 library execution"
}
"$BUILD/o2/rom0_test" > "$EVIDENCE/library-repeat.txt" 2>&1 || {
  tail -n 250 "$EVIDENCE/library-repeat.txt" >&2
  fail "R1 repeat execution"
}
cmp "$EVIDENCE/library.txt" "$EVIDENCE/library-repeat.txt" || fail "R1 full library repeat drift"

python3 "$ANALYZER" --input "$EVIDENCE/library.txt" --repeat "$EVIDENCE/library-repeat.txt"   --output "$EVIDENCE/ROM1AR1_RESULT.json" | tee "$EVIDENCE/analyzer.txt"
cat "$EVIDENCE/ROM1AR1_RESULT.json"
sha256sum "$EVIDENCE/library.txt" "$EVIDENCE/library-repeat.txt" "$EVIDENCE/ROM1AR1_RESULT.json"   "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"
git diff --check "$PREREG_COMMIT"...HEAD
echo "ROM1AR1_EVIDENCE_PRESERVED=PASS"
