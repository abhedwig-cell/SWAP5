#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PREREG_COMMIT=0791330b1c6ce53a738547ecb254f13f1f0e4616
TA5_SOURCE_HEAD=a388a4f14002fafd1cd8e3471675222672d01eb7
PREREG=integration/f-rom/F-ROM0R_R3Q2_PREREGISTRATION.json
Q1_STATUS=integration/f-rom/F-ROM0R_R3Q1_STATUS.json
TEST=tests/rom/test_f_rom0r_r3q2_fkt_policy_trajectory.f90
ANALYZER=tests/rom/analyze_f_rom0r_r3q2_fkt_policy_trajectory.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-r3q2-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROM0R_R3Q2_EVIDENCE_DIR:-$ROOT/F-ROM0R_R3Q2_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROM0R_R3Q2_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG_COMMIT" HEAD || fail "R3Q2 preregistration not ancestor"
git diff --quiet "$TA5_SOURCE_HEAD"...HEAD -- src reference || fail "R3Q2 changed production/reference source"
echo "F_ROM0R_R3Q2_SOURCE_FREEZE=PASS"

python3 - "$PREREG" "$Q1_STATUS" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); q=json.load(open(sys.argv[2]))
assert p["phase"]=="PREREGISTERED_BEFORE_FKT_TRAJECTORY_EXECUTION"
assert p["authority"]["policy_decision"]=="PRESCRIBED_HEAD_REPRESENTATION_POLICY_QUALIFIED"
assert p["policy_materialization"]["only_parameter_changed_per_step"]=="total_balance_tolerance"
assert p["policy_materialization"]["local_compartment_balance_rate_tolerance_cm_per_day"]==1e-12
assert p["paired_solver_equivalence"]["direct_reference_candidate_from_same_committed_base"] is True
assert p["rom1a_authorized"] is False
assert q["decision"]=="PRESCRIBED_HEAD_REPRESENTATION_POLICY_QUALIFIED"
assert q["research_reference_policy_qualified"] is True
print("F_ROM0R_R3Q2_AUTHORITY_LOCK=PASS")
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/stubs_n16.f90"     --target "$TEST" --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$EVIDENCE/o$opt.txt" 2>&1 || {
    cat "$EVIDENCE/o$opt.txt" >&2
    fail "R3Q2 executable O$opt"
  }
  cat "$EVIDENCE/o$opt.txt"
  [[ "$(grep -c 'F_ROM0R_R3Q2_STEP|' "$EVIDENCE/o$opt.txt")" -eq 64 ]] || fail "expected 64 step rows O$opt"
  [[ "$(grep -c 'F_ROM0R_R3Q2_CASE_PASS|' "$EVIDENCE/o$opt.txt")" -eq 4 ]] || fail "expected four cases O$opt"
  grep -Fq 'F_ROM0R_R3Q2_MATRIX_COMPLETE=PASS' "$EVIDENCE/o$opt.txt" || fail "matrix marker O$opt"
done
cmp "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" || fail "R3Q2 O0/O2 drift"

python3 "$ANALYZER" --input "$EVIDENCE/o2.txt" --repeat "$EVIDENCE/o0.txt"   --output "$EVIDENCE/F-ROM0R_R3Q2_RESULT.json" | tee "$EVIDENCE/analyzer.txt"
cat "$EVIDENCE/F-ROM0R_R3Q2_RESULT.json"
sha256sum "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" "$EVIDENCE/F-ROM0R_R3Q2_RESULT.json"   "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"
git diff --check "$PREREG_COMMIT"...HEAD
echo "F_ROM0R_R3Q2_EVIDENCE_PRESERVED=PASS"
