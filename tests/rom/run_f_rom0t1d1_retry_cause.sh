#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PREREG_COMMIT=924bd44d48a54adaaaa8658c676ddbe90c56c1c3
TA5_SOURCE_HEAD=a388a4f14002fafd1cd8e3471675222672d01eb7
PREREG=integration/f-rom/F-ROM0T1D1_PREREGISTRATION.json
T1_STATUS=integration/f-rom/F-ROM0T1_STATUS.json
TEST=tests/rom/test_f_rom0t1d1_retry_cause.f90
ANALYZER=tests/rom/analyze_f_rom0t1d1_retry_cause.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rom0t1d1-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROM0T1D1_EVIDENCE_DIR:-$ROOT/F-ROM0T1D1_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROM0T1D1_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG_COMMIT" HEAD || fail "ROM0T1D1 preregistration not ancestor"
git diff --quiet "$TA5_SOURCE_HEAD"...HEAD -- src reference || fail "ROM0T1D1 changed production/reference source"
echo "F_ROM0T1D1_SOURCE_FREEZE=PASS"

python3 - "$PREREG" "$T1_STATUS" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); t=json.load(open(sys.argv[2]))
assert p["phase"]=="PREREGISTERED_BEFORE_DIAGNOSTIC_EXECUTION"
assert p["predecessor"]["decision"]=="ORIGINAL_TEMPORAL_REFERENCE_FLOOR_NOT_MEASURABLE_UNDER_FROZEN_CONTROL"
assert len(p["predecessor"]["immutable_failures"])==3
assert p["classification_authority"]["work_unit"]=="PUB-P2E11D"
assert p["representation_bound_authority"]["work_unit"]=="PUB-P2E21"
assert p["representation_bound_authority"]["failed_residual_used_in_formula"] is False
assert p["frozen_controls"]["total_balance_rate_tolerance_cm_per_day"]==1e-12
assert p["frozen_controls"]["max_iterations"]==16
assert p["remedy_authorized"] is False
assert t["decision"]=="ORIGINAL_TEMPORAL_REFERENCE_FLOOR_NOT_MEASURABLE_UNDER_FROZEN_CONTROL"
assert t["original_T1_reclassification_authorized"] is False
print("F_ROM0T1D1_AUTHORITY_LOCK=PASS")
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/stubs_n16.f90"     --target "$TEST" --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$EVIDENCE/o$opt.txt" 2>&1 || {
    cat "$EVIDENCE/o$opt.txt" >&2
    fail "T1D1 executable O$opt"
  }
  cat "$EVIDENCE/o$opt.txt"
  [[ "$(grep -c 'F_ROM0T1D1_CLASS|' "$EVIDENCE/o$opt.txt")" -eq 3 ]] || fail "expected three class rows O$opt"
  [[ "$(grep -c 'F_ROM0T1D1_BOUND|' "$EVIDENCE/o$opt.txt")" -eq 3 ]] || fail "expected three bound rows O$opt"
  [[ "$(grep -c 'F_ROM0T1D1_CASE_COMPLETE|' "$EVIDENCE/o$opt.txt")" -eq 3 ]] || fail "expected three completed diagnostics O$opt"
  grep -Fq 'F_ROM0T1D1_DIAGNOSTIC_GATE=PASS' "$EVIDENCE/o$opt.txt" || fail "gate marker O$opt"
done
cmp "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" || fail "T1D1 O0/O2 drift"
"$BUILD/o2/rom0_test" > "$EVIDENCE/o2_repeat.txt" 2>&1 || fail "T1D1 O2 repeat"
cmp "$EVIDENCE/o2.txt" "$EVIDENCE/o2_repeat.txt" || fail "T1D1 repeat drift"
echo "F_ROM0T1D1_O0_O2_IDENTITY=PASS"
echo "F_ROM0T1D1_REPEAT_IDENTITY=PASS"

python3 "$ANALYZER" --input "$EVIDENCE/o2.txt" --repeat "$EVIDENCE/o2_repeat.txt"   --output "$EVIDENCE/F-ROM0T1D1_RESULT.json" | tee "$EVIDENCE/analyzer.txt"
cat "$EVIDENCE/F-ROM0T1D1_RESULT.json"

python3 - "$EVIDENCE/F-ROM0T1D1_RESULT.json" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
allowed={
 "T1_ALL_RETRIES_TOTAL_ONLY_WITHIN_PRIOR_REPRESENTATION_BOUND",
 "T1_RETRY_CAUSE_NONUNIFORM",
 "T1_RETRY_NOT_TOTAL_ONLY",
 "T1_TOTAL_ONLY_EXCEEDS_PRIOR_REPRESENTATION_BOUND",
}
assert r["decision"] in allowed
print("F_ROM0T1D1_SCIENTIFIC_DECISION="+r["decision"])
PY

sha256sum "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" "$EVIDENCE/o2_repeat.txt"   "$EVIDENCE/F-ROM0T1D1_RESULT.json" "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"
git diff --check "$PREREG_COMMIT"...HEAD
echo "F_ROM0T1D1_EVIDENCE_PRESERVED=PASS"
