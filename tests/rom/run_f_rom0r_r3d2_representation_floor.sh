#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PREREG_COMMIT=df73e83939fae20ad6221ada42dadf5ba18b070f
TA5_SOURCE_HEAD=a388a4f14002fafd1cd8e3471675222672d01eb7
PREREG=integration/f-rom/F-ROM0R_R3D2_PREREGISTRATION.json
D1_STATUS=integration/f-rom/F-ROM0R_R3D1_STATUS.json
TEST=tests/rom/test_f_rom0r_r3d2_representation_floor.f90
ANALYZER=tests/rom/analyze_f_rom0r_r3d2_representation_floor.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-r3d2-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROM0R_R3D2_EVIDENCE_DIR:-$ROOT/F-ROM0R_R3D2_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROM0R_R3D2_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG_COMMIT" HEAD || fail "R3D2 preregistration not ancestor"
git diff --quiet "$TA5_SOURCE_HEAD"...HEAD -- src reference || fail "R3D2 changed production/reference source"
echo "F_ROM0R_R3D2_SOURCE_FREEZE=PASS"

python3 - "$PREREG" "$D1_STATUS" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); d=json.load(open(sys.argv[2]))
assert p["phase"]=="PREREGISTERED_BEFORE_DIAGNOSTIC_EXECUTION"
assert p["predecessor"]["decision"]=="B01_RETRY_TOTAL_ONLY_CLASSIFIED"
assert p["independent_method_authority"]["formula"]=="0.5 * sum_i((spacing(theta_s_material) + spacing(theta_base_i)) * dz_i)"
assert p["independent_method_authority"]["failed_residual_used_in_formula"] is False
assert p["diagnostic"]["solver_tolerance_changed"] is False
assert p["remedy_authorized"] is False
assert d["decision"]=="B01_RETRY_TOTAL_ONLY_CLASSIFIED"
assert d["tolerance_change_authorized"] is False
print("F_ROM0R_R3D2_AUTHORITY_LOCK=PASS")
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/stubs_n16.f90"     --target "$TEST" --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$EVIDENCE/o$opt.txt" 2>&1 || {
    cat "$EVIDENCE/o$opt.txt" >&2
    fail "R3D2 executable O$opt"
  }
  cat "$EVIDENCE/o$opt.txt"
  [[ "$(grep -c 'F_ROM0R_R3D2_BOUND|' "$EVIDENCE/o$opt.txt")" -eq 2 ]] || fail "expected two bound rows O$opt"
  grep -Fq 'F_ROM0R_R3D2_DIAGNOSTIC_GATE=PASS' "$EVIDENCE/o$opt.txt" || fail "gate marker O$opt"
done
cmp "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" || fail "R3D2 O0/O2 drift"

python3 "$ANALYZER" --input "$EVIDENCE/o2.txt" --repeat "$EVIDENCE/o0.txt"   --output "$EVIDENCE/F-ROM0R_R3D2_RESULT.json" | tee "$EVIDENCE/analyzer.txt"
cat "$EVIDENCE/F-ROM0R_R3D2_RESULT.json"
sha256sum "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" "$EVIDENCE/F-ROM0R_R3D2_RESULT.json"   "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"
git diff --check "$PREREG_COMMIT"...HEAD
echo "F_ROM0R_R3D2_EVIDENCE_PRESERVED=PASS"
