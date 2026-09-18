#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PREREG_COMMIT=6a2468bc3125cc0004c90755a226d9889075c159
PREREG=integration/f-rom/F-ROM1A_PREREGISTRATION.json
ROM0_STATUS=integration/f-rom/F-ROM0_STATUS.json
TEST=tests/rom/test_f_rom1a_reachable_state_library.f90
ANALYZER=tests/rom/analyze_f_rom1a_reachable_state_library.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rom1a-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROM1A_EVIDENCE_DIR:-$ROOT/F-ROM1A_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROM1A_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG_COMMIT" HEAD || fail "ROM1A preregistration not ancestor"
git diff --quiet "$PREREG_COMMIT"...HEAD -- src reference || fail "ROM1A mutated src/reference after preregistration"
echo "F_ROM1A_SOURCE_FREEZE=PASS"

python3 - "$PREREG" "$ROM0_STATUS" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); s=json.load(open(sys.argv[2]))
assert p["phase"]=="PREREGISTERED_BEFORE_REACHABLE_STATE_GENERATION"
assert p["materials"]["discovery_and_within_material_holdout"]=="B01"
assert p["materials"]["material_transfer_challenge"]=="B14"
assert len(p["history_design"]["discovery_histories"])==8
assert len(p["history_design"]["held_out_histories"])==4
assert p["history_design"]["history_length_steps"]==64
assert p["reference_authority"]["observation_step_day"]==0.0008
assert p["qualification"][1]=="768_ACCEPTED_B01_LIBRARY_STATES"
assert p["scientific_firewalls"][0]=="NO_REDUCED_COORDINATE_SELECTION_IN_ROM1A"
assert s["decision"]=="PROCEED_TO_ROM1A"
assert s["rom1a_authorized"] is True
print("F_ROM1A_AUTHORITY_LOCK=PASS")
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10
python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/stubs_n16.f90"   --target "$TEST" --external-source src/legacy/b1_10_port/headcalc.f90   --build "$BUILD/o2" --opt 2

"$BUILD/o2/rom0_test" > "$EVIDENCE/library.txt" 2>&1 || {
  tail -n 200 "$EVIDENCE/library.txt" >&2
  fail "ROM1A library execution"
}
"$BUILD/o2/rom0_test" > "$EVIDENCE/library-repeat.txt" 2>&1 || {
  tail -n 200 "$EVIDENCE/library-repeat.txt" >&2
  fail "ROM1A repeat execution"
}
cmp "$EVIDENCE/library.txt" "$EVIDENCE/library-repeat.txt" || fail "ROM1A full library repeat drift"

python3 "$ANALYZER" --input "$EVIDENCE/library.txt" --repeat "$EVIDENCE/library-repeat.txt"   --output "$EVIDENCE/F-ROM1A_RESULT.json" | tee "$EVIDENCE/analyzer.txt"
cat "$EVIDENCE/F-ROM1A_RESULT.json"
sha256sum "$EVIDENCE/library.txt" "$EVIDENCE/library-repeat.txt" "$EVIDENCE/F-ROM1A_RESULT.json"   "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"
git diff --check "$PREREG_COMMIT"...HEAD
echo "F_ROM1A_EVIDENCE_PRESERVED=PASS"
