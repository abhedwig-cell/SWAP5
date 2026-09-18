#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PREREG_COMMIT=5256394634abdb9f3b9fe5af28f6acd86e0ed1c0
TA5_SOURCE_HEAD=a388a4f14002fafd1cd8e3471675222672d01eb7
PREREG=integration/f-rom/F-ROM0R_R3D4_PREREGISTRATION.json
D3_STATUS=integration/f-rom/F-ROM0R_R3D3_STATUS.json
TEST=tests/rom/test_f_rom0r_r3d4_fallback_policy.f90
ANALYZER=tests/rom/analyze_f_rom0r_r3d4_fallback_policy.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-r3d4-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROM0R_R3D4_EVIDENCE_DIR:-$ROOT/F-ROM0R_R3D4_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROM0R_R3D4_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG_COMMIT" HEAD || fail "R3D4 preregistration not ancestor"
git diff --quiet "$TA5_SOURCE_HEAD"...HEAD -- src reference || fail "R3D4 changed production/reference source"
echo "F_ROM0R_R3D4_SOURCE_FREEZE=PASS"

python3 - "$PREREG" "$D3_STATUS" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); d=json.load(open(sys.argv[2]))
assert p["phase"]=="PREREGISTERED_BEFORE_FALLBACK_EXECUTION"
assert p["predecessors"]["R3D3"]=="R3_POLICY_OVERLAP_NEUTRALITY_FAILED"
assert p["policy"]["id"]=="ORIGINAL_FIRST_FAIL_CLOSED_TOTAL_ONLY_REATTEMPT"
assert p["policy"]["observed_residual_used_to_choose_tolerance"] is False
assert p["policy"]["dt_subdivision"] is False
assert p["frozen_controls"]["compartment_balance_tolerance_cm_per_day"]==1e-12
assert p["frozen_controls"]["original_total_balance_tolerance_cm_per_day"]==1e-12
assert p["frozen_controls"]["max_iterations"]==16
assert p["frozen_controls"]["max_backtracking"]==8
assert p["frozen_controls"]["hard_transaction_mass_gate_cm"]==1e-12
assert p["production_admission_authorized"] is False
assert p["rom1a_authorized"] is False
assert d["decision"]=="R3_POLICY_OVERLAP_NEUTRALITY_FAILED"
print("F_ROM0R_R3D4_AUTHORITY_LOCK=PASS")
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/stubs_n16.f90"     --target "$TEST" --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$EVIDENCE/o$opt.txt" 2>&1 || {
    cat "$EVIDENCE/o$opt.txt" >&2
    fail "R3D4 executable O$opt"
  }
  cat "$EVIDENCE/o$opt.txt"
  grep -Fq 'F_ROM0R_R3D4_EXECUTION_COMPLETE=PASS' "$EVIDENCE/o$opt.txt" || fail "execution marker O$opt"
  [[ "$(grep -c 'F_ROM0R_R3D4_CONTROL|' "$EVIDENCE/o$opt.txt")" -eq 4 ]] || fail "four controls O$opt"
done
cmp "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" || fail "R3D4 O0/O2 drift"

python3 "$ANALYZER" --input "$EVIDENCE/o2.txt" --repeat "$EVIDENCE/o0.txt"   --output "$EVIDENCE/F-ROM0R_R3D4_RESULT.json" | tee "$EVIDENCE/analyzer.txt"

python3 - "$EVIDENCE/F-ROM0R_R3D4_RESULT.json" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
allowed={
 "R3_FAIL_CLOSED_TOTAL_ONLY_FALLBACK_QUALIFIED",
 "R3_FAIL_CLOSED_TOTAL_ONLY_FALLBACK_NO_GO",
 "R3_FALLBACK_TRIGGER_CLASSIFICATION_FAILED",
 "R3_FALLBACK_OVERLAP_NEUTRALITY_FAILED",
 "R3_FALLBACK_DIRECTIONAL_REACHABILITY_NOT_ESTABLISHED",
}
assert r["decision"] in allowed
assert r["baseline_provenance_reproduced"] is True
assert r["repeat_stdout_bitwise_identity"] is True
print("F_ROM0R_R3D4_SCIENTIFIC_DECISION="+r["decision"])
PY

cat "$EVIDENCE/F-ROM0R_R3D4_RESULT.json"
sha256sum "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" "$EVIDENCE/F-ROM0R_R3D4_RESULT.json"   "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"
git diff --check "$PREREG_COMMIT"...HEAD
echo "F_ROM0R_R3D4_EVIDENCE_PRESERVED=PASS"
