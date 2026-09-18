#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PREREG_COMMIT=b3a4706a2f22ded8757ca8fa58432676239e6dee
TA5_SOURCE_HEAD=a388a4f14002fafd1cd8e3471675222672d01eb7
PREREG=integration/f-rom/F-ROM0R_R3D1_PREREGISTRATION.json
R3_STATUS=integration/f-rom/F-ROM0R_R3_STATUS.json
TEST=tests/rom/test_f_rom0r_r3d1_retry_cause.f90
ANALYZER=tests/rom/analyze_f_rom0r_r3d1_retry_cause.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-r3d1-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROM0R_R3D1_EVIDENCE_DIR:-$ROOT/F-ROM0R_R3D1_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROM0R_R3D1_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG_COMMIT" HEAD || fail "R3D1 preregistration not ancestor"
git diff --quiet "$TA5_SOURCE_HEAD"...HEAD -- src reference || fail "R3D1 changed production/reference source"
echo "F_ROM0R_R3D1_SOURCE_FREEZE=PASS"

python3 - "$PREREG" "$R3_STATUS" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); r=json.load(open(sys.argv[2]))
assert p["phase"]=="PREREGISTERED_BEFORE_DIAGNOSTIC_EXECUTION"
assert p["predecessor_decision"]=="PRESSURE_BOUNDARY_REFERENCE_SAMPLE_NO_GO"
assert len(p["cases"])==2
assert p["cases"][0]["diagnostic_failed_step"]==11
assert p["cases"][1]["diagnostic_failed_step"]==10
assert p["frozen_controls"]["max_iterations"]==16
assert p["frozen_controls"]["max_backtracking"]==8
assert p["frozen_controls"]["compartment_balance_tolerance"]==1e-12
assert p["frozen_controls"]["total_balance_tolerance"]==1e-12
assert p["rom1a_authorized"] is False
assert r["decision"]=="PRESSURE_BOUNDARY_REFERENCE_SAMPLE_NO_GO"
print("F_ROM0R_R3D1_AUTHORITY_LOCK=PASS")
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/stubs_n16.f90"     --target "$TEST" --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$EVIDENCE/o$opt.txt" 2>&1 || {
    cat "$EVIDENCE/o$opt.txt" >&2
    fail "R3D1 executable O$opt"
  }
  cat "$EVIDENCE/o$opt.txt"
  grep -Fq 'F_ROM0R_R3D1_CASE_COMPLETE|CASE=BOTTOM_HEAD_RISE' "$EVIDENCE/o$opt.txt" || fail "rise complete O$opt"
  grep -Fq 'F_ROM0R_R3D1_CASE_COMPLETE|CASE=BOTTOM_HEAD_FALL' "$EVIDENCE/o$opt.txt" || fail "fall complete O$opt"
  grep -Fq 'F_ROM0R_R3D1_DIAGNOSTIC_GATE=PASS' "$EVIDENCE/o$opt.txt" || fail "gate marker O$opt"
  [[ "$(grep -c 'F_ROM0R_R3D1_CLASS|' "$EVIDENCE/o$opt.txt")" -eq 2 ]] || fail "expected two classifications O$opt"
done
cmp "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" || fail "R3D1 O0/O2 drift"

python3 "$ANALYZER" --input "$EVIDENCE/o2.txt" --repeat "$EVIDENCE/o0.txt"   --output "$EVIDENCE/F-ROM0R_R3D1_RESULT.json" | tee "$EVIDENCE/analyzer.txt"
cat "$EVIDENCE/F-ROM0R_R3D1_RESULT.json"
sha256sum "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" "$EVIDENCE/F-ROM0R_R3D1_RESULT.json"   "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"
git diff --check "$PREREG_COMMIT"...HEAD
echo "F_ROM0R_R3D1_EVIDENCE_PRESERVED=PASS"
