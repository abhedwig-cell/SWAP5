#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PREREG_COMMIT=a4a1db296582680af7f68f1a096fcdb9c742cac8
TA5_SOURCE_HEAD=a388a4f14002fafd1cd8e3471675222672d01eb7
PREREG=integration/f-rom/F-ROM0R_R3R1_PREREGISTRATION.json
D2_STATUS=integration/f-rom/F-ROM0R_R3D2_STATUS.json
TEST=tests/rom/test_f_rom0r_r3r1_representation_policy.f90
ANALYZER=tests/rom/analyze_f_rom0r_r3r1_representation_policy.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-r3r1-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROM0R_R3R1_EVIDENCE_DIR:-$ROOT/F-ROM0R_R3R1_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROM0R_R3R1_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG_COMMIT" HEAD || fail "R3R1 preregistration not ancestor"
git diff --quiet "$TA5_SOURCE_HEAD"...HEAD -- src reference || fail "R3R1 changed production/reference source"
echo "F_ROM0R_R3R1_SOURCE_FREEZE=PASS"

python3 - "$PREREG" "$D2_STATUS" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); d=json.load(open(sys.argv[2]))
assert p["phase"]=="PREREGISTERED_BEFORE_CANDIDATE_POLICY_EXECUTION"
assert p["candidate_policy"]["total_balance_rate_tolerance_formula"]=="max(1e-12, representation_bound_cm / dt_day)"
assert p["candidate_policy"]["failed_residual_used"] is False
assert p["candidate_policy"]["empirical_safety_factor"]=="none"
assert p["neutrality_gate"]["required_original_accepted_prefixes"]["B01_BOTTOM_HEAD_RISE"]==10
assert p["neutrality_gate"]["required_original_accepted_prefixes"]["B01_BOTTOM_HEAD_FALL"]==9
assert p["candidate_completion_gate"]["all_four_cases_complete_16_perturbation_intervals"] is True
assert p["rom1a_authorized"] is False
assert d["decision"]=="B01_TOTAL_ONLY_WITHIN_PRIOR_REPRESENTATION_BOUND"
assert d["policy_application_authorized"] is False
assert d["next_permitted_action"]=="PREREGISTER_R3_REPRESENTATION_BOUNDED_TOTAL_CANDIDATE_POLICY_QUALIFICATION"
print("F_ROM0R_R3R1_AUTHORITY_LOCK=PASS")
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/stubs_n16.f90"     --target "$TEST" --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$EVIDENCE/o$opt.txt" 2>&1 || {
    cat "$EVIDENCE/o$opt.txt" >&2
    fail "R3R1 executable O$opt structural failure"
  }
  grep -Fq 'F_ROM0R_R3R1_EXECUTION_COMPLETE=PASS' "$EVIDENCE/o$opt.txt" || fail "execution-complete marker O$opt"
done

"$BUILD/o2/rom0_test" > "$EVIDENCE/repeat.txt" 2>&1 || {
  cat "$EVIDENCE/repeat.txt" >&2
  fail "R3R1 repeat structural failure"
}

cat "$EVIDENCE/o2.txt"
python3 "$ANALYZER" --o0 "$EVIDENCE/o0.txt" --o2 "$EVIDENCE/o2.txt" --repeat "$EVIDENCE/repeat.txt"   --output "$EVIDENCE/F-ROM0R_R3R1_RESULT.json" | tee "$EVIDENCE/analyzer.txt"
cat "$EVIDENCE/F-ROM0R_R3R1_RESULT.json"

sha256sum "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" "$EVIDENCE/repeat.txt"   "$EVIDENCE/F-ROM0R_R3R1_RESULT.json" "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"
git diff --check "$PREREG_COMMIT"...HEAD
echo "F_ROM0R_R3R1_EVIDENCE_PRESERVED=PASS"
