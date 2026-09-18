#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PREREG_COMMIT=1efa4c768433595e9170d2a3d7b9d0ef0973b73d
PREREG=integration/f-rom/ROM1AR1D1_PREREGISTRATION.json
PARENT=integration/f-rom/ROM1AR1D1_PARENT_FAILURE.json
D2_STATUS=integration/f-rom/ROM1AD2_STATUS.json
D4_STATUS=integration/f-rom/F-ROM0R_R3D4_STATUS.json
TEST=tests/rom/test_rom1ar1d1_d08_failure_diagnostic.f90
ANALYZER=tests/rom/analyze_rom1ar1d1_d08_failure_diagnostic.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rom1ar1d1-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${ROM1AR1D1_EVIDENCE_DIR:-$ROOT/ROM1AR1D1_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "ROM1AR1D1_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG_COMMIT" HEAD || fail "D1 preregistration not ancestor"
git diff --quiet "$PREREG_COMMIT"...HEAD -- src reference || fail "D1 changed src/reference"
echo "ROM1AR1D1_SOURCE_FREEZE=PASS"

python3 - "$PREREG" "$PARENT" "$D2_STATUS" "$D4_STATUS" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); f=json.load(open(sys.argv[2]))
d2=json.load(open(sys.argv[3])); d4=json.load(open(sys.argv[4]))
assert p["phase"]=="PREREGISTERED_BEFORE_DIAGNOSTIC_EXECUTION"
assert p["case"]["history"]=="D08"
assert p["case"]["accepted_predecessor_steps"]==33
assert p["case"]["failed_step"]==34
assert p["case"]["bottom_mode"]==5
assert p["case"]["step_dt_day"]==0.0008
assert p["representation_diagnostic"]["policy_applied_to_failed_step"] is False
assert f["observed_failure"]["history"]=="D08"
assert f["observed_failure"]["accepted_steps_before_failure"]==33
assert f["observed_failure"]["failed_step"]==34
assert d2["decision"]=="ROM1AD2_MODE2_FAIL_CLOSED_FALLBACK_QUALIFIED"
assert d4["decision"]=="R3_FAIL_CLOSED_TOTAL_ONLY_FALLBACK_QUALIFIED"
print("ROM1AR1D1_AUTHORITY_LOCK=PASS")
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/stubs_n16.f90"     --target "$TEST" --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$EVIDENCE/o$opt.txt" 2>&1 || {
    cat "$EVIDENCE/o$opt.txt" >&2
    fail "D08 diagnostic O$opt"
  }
  cat "$EVIDENCE/o$opt.txt"
  grep -Fq 'ROM1AR1D1_DIAGNOSTIC_COMPLETE=PASS' "$EVIDENCE/o$opt.txt" || fail "missing diagnostic marker O$opt"
done
cmp "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" || fail "D08 diagnostic O0/O2 drift"

python3 "$ANALYZER" --input "$EVIDENCE/o2.txt" --repeat "$EVIDENCE/o0.txt"   --output "$EVIDENCE/ROM1AR1D1_RESULT.json" | tee "$EVIDENCE/analyzer.txt"
cat "$EVIDENCE/ROM1AR1D1_RESULT.json"
sha256sum "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" "$EVIDENCE/ROM1AR1D1_RESULT.json"   "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"
git diff --check "$PREREG_COMMIT"...HEAD
echo "ROM1AR1D1_EVIDENCE_PRESERVED=PASS"
