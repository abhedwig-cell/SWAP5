#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PREREG_COMMIT=852fcd5440d8d41558eaf005d77bc70e84a17b89
PREREG=integration/f-rom/ROM1AS1_PREREGISTRATION.json
D2_STATUS=integration/f-rom/ROM1AD2_STATUS.json
D4_STATUS=integration/f-rom/F-ROM0R_R3D4_STATUS.json
TEST=tests/rom/test_rom1as1_reachable_state_library.f90
ANALYZER=tests/rom/analyze_rom1as1_reachable_state_library.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rom1as1-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${ROM1AS1_EVIDENCE_DIR:-$ROOT/ROM1AS1_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "ROM1AS1_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG_COMMIT" HEAD || fail "S1 preregistration not ancestor"
git diff --quiet "$PREREG_COMMIT"...HEAD -- src reference || fail "S1 changed src/reference"
echo "ROM1AS1_SOURCE_FREEZE=PASS"

python3 - "$PREREG" "$D2_STATUS" "$D4_STATUS" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); d2=json.load(open(sys.argv[2])); d4=json.load(open(sys.argv[3]))
assert p["phase"]=="PREREGISTERED_BEFORE_SUCCESSOR_LIBRARY_EXECUTION"
assert p["scientific_design_lock"]["history_count"]==12
assert p["scientific_design_lock"]["steps_per_history"]==64
assert p["scientific_design_lock"]["total_state_target"]==768
assert p["scientific_design_lock"]["material"]=="B01"
assert p["scientific_design_lock"]["material_transfer_challenge"]=="B14_REMAINS_UNOPENED"
assert p["reference_policy"]["mode2"]["authority"]=="ROM1A-D2"
assert p["reference_policy"]["mode5"]["authority"]=="ROM-0R-R3D4"
assert p["reference_policy"]["mode5"]["combined_symbol_fallback_authorized"] is False
assert d2["decision"]=="ROM1AD2_MODE2_FAIL_CLOSED_FALLBACK_QUALIFIED"
assert d2["mode2_research_fallback_qualified"] is True
assert d4["decision"]=="R3_FAIL_CLOSED_TOTAL_ONLY_FALLBACK_QUALIFIED"
print("ROM1AS1_AUTHORITY_LOCK=PASS")
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10
python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/stubs_n16.f90"   --target "$TEST" --external-source src/legacy/b1_10_port/headcalc.f90   --build "$BUILD/o2" --opt 2

"$BUILD/o2/rom0_test" > "$EVIDENCE/library.txt" 2>&1 || {
  tail -n 300 "$EVIDENCE/library.txt" >&2
  fail "S1 library execution"
}
"$BUILD/o2/rom0_test" > "$EVIDENCE/library-repeat.txt" 2>&1 || {
  tail -n 300 "$EVIDENCE/library-repeat.txt" >&2
  fail "S1 repeat execution"
}
cmp "$EVIDENCE/library.txt" "$EVIDENCE/library-repeat.txt" || fail "S1 full-library repeat drift"

python3 "$ANALYZER" --input "$EVIDENCE/library.txt" --repeat "$EVIDENCE/library-repeat.txt"   --output "$EVIDENCE/ROM1AS1_RESULT.json" | tee "$EVIDENCE/analyzer.txt"
cat "$EVIDENCE/ROM1AS1_RESULT.json"
sha256sum "$EVIDENCE/library.txt" "$EVIDENCE/library-repeat.txt" "$EVIDENCE/ROM1AS1_RESULT.json"   "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"
git diff --check "$PREREG_COMMIT"...HEAD
echo "ROM1AS1_EVIDENCE_PRESERVED=PASS"
