#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PREREG_COMMIT=5b31e96814a8a5940182ef4fddd664383d493957
TA5_SOURCE_HEAD=a388a4f14002fafd1cd8e3471675222672d01eb7
PREREG=integration/f-rom/F-ROM0R_R3D3_PREREGISTRATION.json
D2_STATUS=integration/f-rom/F-ROM0R_R3D2_STATUS.json
TEST=tests/rom/test_f_rom0r_r3d3_candidate_policy.f90
ANALYZER=tests/rom/analyze_f_rom0r_r3d3_candidate_policy.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-r3d3-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROM0R_R3D3_EVIDENCE_DIR:-$ROOT/F-ROM0R_R3D3_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROM0R_R3D3_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG_COMMIT" HEAD || fail "R3D3 preregistration not ancestor"
git diff --quiet "$TA5_SOURCE_HEAD"...HEAD -- src reference || fail "R3D3 changed production/reference source"
echo "F_ROM0R_R3D3_SOURCE_FREEZE=PASS"

python3 - "$PREREG" "$D2_STATUS" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); d=json.load(open(sys.argv[2]))
assert p["phase"]=="PREREGISTERED_BEFORE_CANDIDATE_POLICY_EXECUTION"
assert p["predecessors"]["R3D2"]=="B01_TOTAL_ONLY_WITHIN_PRIOR_REPRESENTATION_BOUND"
cp=p["candidate_policy"]
assert cp["total_balance_rate_tolerance_formula"]=="max(1.0e-12, representation_bound_cm / dt_day)"
assert cp["compartment_balance_tolerance_cm_per_day"]==1e-12
assert cp["head_abs_tolerance"]==1e-12
assert cp["head_rel_tolerance"]==1e-12
assert cp["max_iterations"]==16 and cp["max_backtracking"]==8
assert cp["hard_transaction_mass_gate_cm"]==1e-12
assert cp["failed_or_current_residual_used"] is False
assert p["production_admission_authorized"] is False
assert p["rom1a_authorized"] is False
assert d["decision"]=="B01_TOTAL_ONLY_WITHIN_PRIOR_REPRESENTATION_BOUND"
assert d["policy_application_authorized"] is False
print("F_ROM0R_R3D3_AUTHORITY_LOCK=PASS")
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/stubs_n16.f90"     --target "$TEST" --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$EVIDENCE/o$opt.txt" 2>&1 || {
    cat "$EVIDENCE/o$opt.txt" >&2
    fail "R3D3 executable O$opt"
  }
  cat "$EVIDENCE/o$opt.txt"
  grep -Fq 'F_ROM0R_R3D3_EXECUTION_COMPLETE=PASS' "$EVIDENCE/o$opt.txt" || fail "execution marker O$opt"
  [[ "$(grep -c 'F_ROM0R_R3D3_CONTROL|' "$EVIDENCE/o$opt.txt")" -eq 4 ]] || fail "four controls O$opt"
done
cmp "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" || fail "R3D3 O0/O2 drift"

python3 "$ANALYZER" --input "$EVIDENCE/o2.txt" --repeat "$EVIDENCE/o0.txt"   --output "$EVIDENCE/F-ROM0R_R3D3_RESULT.json" | tee "$EVIDENCE/analyzer.txt"

python3 - "$EVIDENCE/F-ROM0R_R3D3_RESULT.json" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
allowed={
 "R3_REPRESENTATION_BOUNDED_TOTAL_POLICY_QUALIFIED",
 "R3_REPRESENTATION_BOUNDED_TOTAL_POLICY_NO_GO",
 "R3_POLICY_OVERLAP_NEUTRALITY_FAILED",
 "R3_POLICY_DIRECTIONAL_REACHABILITY_NOT_ESTABLISHED",
}
assert r["decision"] in allowed
assert r["baseline_provenance_reproduced"] is True
assert r["repeat_stdout_bitwise_identity"] is True
print("F_ROM0R_R3D3_SCIENTIFIC_DECISION="+r["decision"])
PY

cat "$EVIDENCE/F-ROM0R_R3D3_RESULT.json"
sha256sum "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" "$EVIDENCE/F-ROM0R_R3D3_RESULT.json"   "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"
git diff --check "$PREREG_COMMIT"...HEAD
echo "F_ROM0R_R3D3_EVIDENCE_PRESERVED=PASS"
