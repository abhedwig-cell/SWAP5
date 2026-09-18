#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PREREG_COMMIT=e28f79141669e3b97343c5f59432c16220e57f9e
R2_EXEC_HEAD=67a6af4922143a618ffd250c3cc4e38e7090850c
PREREG=integration/f-rom/ROM1B4_PREREGISTRATION.json
Q1_STATUS=integration/f-rom/ROM1B3Q1_STATUS.json
TEST=tests/rom/test_rom1ar2_reachable_state_library.f90
ANALYZER=tests/rom/analyze_rom1b4_heldout_state_separation.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rom1b4-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${ROM1B4_EVIDENCE_DIR:-$ROOT/ROM1B4_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "ROM1B4_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG_COMMIT" HEAD || fail "B4 preregistration not ancestor"
git diff --quiet "$PREREG_COMMIT"...HEAD -- src reference || fail "B4 changed src/reference"
git diff --quiet "$R2_EXEC_HEAD"...HEAD -- "$TEST" || fail "B4 R2 library generator drifted"
echo "ROM1B4_SOURCE_AND_GENERATOR_FREEZE=PASS"

python3 - "$PREREG" "$Q1_STATUS" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); q=json.load(open(sys.argv[2]))
assert p["phase"]=="PREREGISTERED_BEFORE_HELDOUT_COORDINATE_EVALUATION"
assert p["frozen_coordinate"]["theta_floor"]==0.0005420462931603476
assert p["frozen_coordinate"]["dimension"]==9
assert p["library_authority"]["expected_states"]==768
assert p["library_authority"]["B14_generated"] is False
assert q["decision"]=="ROM1B3Q1_DISCOVERY_ENRICHED_COORDINATE_FROZEN"
assert q["frozen_candidate"]=="Z8_PLUS_G8"
assert q["frozen_dimension"]==9
assert q["heldout_exposed"] is False
print("ROM1B4_AUTHORITY_LOCK=PASS")
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/stubs_n16.f90"     --target "$TEST" --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$EVIDENCE/o$opt.txt" 2>&1 || {
    tail -n 350 "$EVIDENCE/o$opt.txt" >&2
    fail "B4 R2 library execution O$opt"
  }
  grep -Fq 'ROM1AR2_EXECUTION_COMPLETE=PASS' "$EVIDENCE/o$opt.txt" || fail "B4 R2 completion O$opt"
  [[ "$(grep -c 'ROM1AR2_STATE|' "$EVIDENCE/o$opt.txt")" -eq 768 ]] || fail "B4 expected 768 states O$opt"
done
cmp "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" || fail "B4 O0/O2 library drift"

python3 "$ANALYZER" --input "$EVIDENCE/o2.txt" --repeat "$EVIDENCE/o0.txt"   --prereg "$PREREG" --output "$EVIDENCE/ROM1B4_RESULT.json" | tee "$EVIDENCE/analyzer.txt"
cat "$EVIDENCE/ROM1B4_RESULT.json"
cat "$EVIDENCE/ROM1B4_COLLISION_MANIFEST.json"
sha256sum "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" "$EVIDENCE/ROM1B4_RESULT.json"   "$EVIDENCE/ROM1B4_COLLISION_MANIFEST.json" "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"
git diff --check "$PREREG_COMMIT"...HEAD
echo "ROM1B4_EVIDENCE_PRESERVED=PASS"
