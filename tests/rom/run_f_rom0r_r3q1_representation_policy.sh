#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PREREG_COMMIT=53d54afdcf49a2547872bec0d4db6a8853a2afa0
TA5_SOURCE_HEAD=a388a4f14002fafd1cd8e3471675222672d01eb7
PREREG=integration/f-rom/F-ROM0R_R3Q1_PREREGISTRATION.json
D2_STATUS=integration/f-rom/F-ROM0R_R3D2_STATUS.json
TEST=tests/rom/test_f_rom0r_r3q1_representation_policy.f90
ANALYZER=tests/rom/analyze_f_rom0r_r3q1_representation_policy.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-r3q1-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROM0R_R3Q1_EVIDENCE_DIR:-$ROOT/F-ROM0R_R3Q1_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROM0R_R3Q1_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG_COMMIT" HEAD || fail "R3Q1 preregistration not ancestor"
git diff --quiet "$TA5_SOURCE_HEAD"...HEAD -- src reference || fail "R3Q1 changed production/reference source"
echo "F_ROM0R_R3Q1_SOURCE_FREEZE=PASS"

python3 - "$PREREG" "$D2_STATUS" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); d=json.load(open(sys.argv[2]))
assert p["phase"]=="PREREGISTERED_BEFORE_POLICY_EXECUTION"
assert p["predecessor"]["r3_decision"]=="PRESSURE_BOUNDARY_REFERENCE_SAMPLE_NO_GO"
assert p["predecessor"]["r3d1_decision"]=="B01_RETRY_TOTAL_ONLY_CLASSIFIED"
assert p["predecessor"]["r3d2_decision"]=="B01_TOTAL_ONLY_WITHIN_PRIOR_REPRESENTATION_BOUND"
assert p["candidate_policy"]["total_integrated_bound_formula_cm"]=="max(1.6e-15, 0.5 * sum_i((spacing(theta_s_material) + spacing(theta_base_i)) * dz_i))"
assert p["candidate_policy"]["local_compartment_balance_rate_tolerance_cm_per_day"]==1e-12
assert p["hard_validity"]["candidate_integrated_mass_abs_limit_cm"]==1e-12
assert p["rom1a_authorized"] is False
assert d["decision"]=="B01_TOTAL_ONLY_WITHIN_PRIOR_REPRESENTATION_BOUND"
assert d["policy_application_authorized"] is False
print("F_ROM0R_R3Q1_AUTHORITY_LOCK=PASS")
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/stubs_n16.f90"     --target "$TEST" --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$EVIDENCE/o$opt.txt" 2>&1 || {
    cat "$EVIDENCE/o$opt.txt" >&2
    fail "R3Q1 executable O$opt"
  }
  cat "$EVIDENCE/o$opt.txt"
  [[ "$(grep -c 'F_ROM0R_R3Q1_STEP|' "$EVIDENCE/o$opt.txt")" -eq 64 ]] || fail "expected 64 step rows O$opt"
  [[ "$(grep -c 'F_ROM0R_R3Q1_CASE_PASS|' "$EVIDENCE/o$opt.txt")" -eq 4 ]] || fail "expected four cases O$opt"
  grep -Fq 'F_ROM0R_R3Q1_MATRIX_COMPLETE=PASS' "$EVIDENCE/o$opt.txt" || fail "matrix marker O$opt"
done
cmp "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" || fail "R3Q1 O0/O2 drift"

python3 "$ANALYZER" --input "$EVIDENCE/o2.txt" --repeat "$EVIDENCE/o0.txt"   --output "$EVIDENCE/F-ROM0R_R3Q1_RESULT.json" | tee "$EVIDENCE/analyzer.txt"
cat "$EVIDENCE/F-ROM0R_R3Q1_RESULT.json"
sha256sum "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" "$EVIDENCE/F-ROM0R_R3Q1_RESULT.json"   "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"
git diff --check "$PREREG_COMMIT"...HEAD
echo "F_ROM0R_R3Q1_EVIDENCE_PRESERVED=PASS"
