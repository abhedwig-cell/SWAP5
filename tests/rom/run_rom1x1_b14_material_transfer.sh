#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PREREG_COMMIT=79db158e77c972804089939776de8e45eb12a804
R2_EXEC_HEAD=67a6af4922143a618ffd250c3cc4e38e7090850c
PREREG=integration/f-rom/ROM1X1_PREREGISTRATION.json
B4_STATUS=integration/f-rom/ROM1B4_STATUS.json
SOURCE_TEST=tests/rom/test_rom1ar2_reachable_state_library.f90
TEST=tests/rom/test_rom1x1_b14_material_transfer.f90
ANALYZER=tests/rom/analyze_rom1x1_b14_material_transfer.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rom1x1-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${ROM1X1_EVIDENCE_DIR:-$ROOT/ROM1X1_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "ROM1X1_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG_COMMIT" HEAD || fail "X1 preregistration not ancestor"
git diff --quiet "$PREREG_COMMIT"...HEAD -- src reference || fail "X1 changed src/reference"
git diff --quiet "$R2_EXEC_HEAD"...HEAD -- "$SOURCE_TEST" || fail "X1 source history generator drifted"
echo "ROM1X1_SOURCE_FREEZE=PASS"

python3 - "$PREREG" "$B4_STATUS" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); b=json.load(open(sys.argv[2]))
assert p["phase"]=="PREREGISTERED_BEFORE_B14_OUTCOME_EXPOSURE"
assert p["frozen_coordinate"]["id"]=="Z8_PLUS_G8"
assert p["frozen_coordinate"]["dimension"]==9
assert p["frozen_coordinate"]["material_specific_adaptation_allowed"] is False
assert p["B14_numerical_authority"]["theta_floor"]==1.6414144244913942e-6
assert p["history_transfer"]["history_count"]==12
assert p["history_transfer"]["steps_per_history"]==64
assert p["history_transfer"]["history_or_amplitude_retuning"] is False
assert b["decision"]=="ROM1B4_HELDOUT_STATE_SEPARATION_QUALIFIED"
assert b["heldout_collision_count"]==0
print("ROM1X1_AUTHORITY_LOCK=PASS")
PY

python3 - "$SOURCE_TEST" "$TEST" <<'PY'
import pathlib,sys
a=pathlib.Path(sys.argv[1]).read_text()
b=pathlib.Path(sys.argv[2]).read_text()
# Structural transfer guard: normalize only the preregistered material/evidence substitutions.
b=b.replace("test_rom1x1_b14_material_transfer","test_rom1ar2_reachable_state_library")
b=b.replace("ROM1X1","ROM1AR2")
b=b.replace("ROM1AR2_B14_MATERIAL_TRANSFER_GENERATED=TRUE","ROM1AR2_B14_MATERIAL_TRANSFER_GENERATED=FALSE")
b=b.replace("981001_int64","971001_int64")
b=b.replace("    tr=0.01_real64;ts=0.416774_real64;alpha=0.00541_real64\n    nn=1.301528_real64;ks=0.895023_real64;lam=-0.334926_real64",
            "    tr=0.02_real64;ts=0.427494_real64;alpha=0.021659_real64\n    nn=1.734737_real64;ks=31.225016_real64;lam=0.98087_real64")
assert a==b, "B14 transfer harness contains non-authorized drift from R2 generator"
print("ROM1X1_HISTORY_AND_POLICY_SOURCE_IDENTITY=PASS")
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/stubs_n16.f90"     --target "$TEST" --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$EVIDENCE/o$opt.txt" 2>&1 || {
    tail -n 500 "$EVIDENCE/o$opt.txt" >&2
    fail "X1 B14 library execution O$opt"
  }
  grep -Fq 'ROM1X1_EXECUTION_COMPLETE=PASS' "$EVIDENCE/o$opt.txt" || fail "X1 completion O$opt"
  [[ "$(grep -c 'ROM1X1_STATE|' "$EVIDENCE/o$opt.txt")" -eq 768 ]] || fail "X1 expected 768 states O$opt"
  grep -Fq 'ROM1X1_B14_MATERIAL_TRANSFER_GENERATED=TRUE' "$EVIDENCE/o$opt.txt" || fail "X1 B14 marker O$opt"
done
cmp "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" || fail "X1 O0/O2 drift"

python3 "$ANALYZER" --input "$EVIDENCE/o2.txt" --repeat "$EVIDENCE/o0.txt"   --prereg "$PREREG" --output "$EVIDENCE/ROM1X1_RESULT.json" | tee "$EVIDENCE/analyzer.txt"
cat "$EVIDENCE/ROM1X1_RESULT.json"
sha256sum "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" "$EVIDENCE/ROM1X1_RESULT.json"   "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"
git diff --check "$PREREG_COMMIT"...HEAD
echo "ROM1X1_EVIDENCE_PRESERVED=PASS"
