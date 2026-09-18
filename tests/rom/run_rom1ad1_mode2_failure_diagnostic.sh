#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PREREG_COMMIT=1e362c90a715ef9fb86c52b795237093d5645b47
PREREG=integration/f-rom/ROM1AD1_PREREGISTRATION.json
PARENT=integration/f-rom/ROM1AD1_PARENT_FAILURE.json
TEST=tests/rom/test_rom1ad1_mode2_failure_diagnostic.f90
ANALYZER=tests/rom/analyze_rom1ad1_mode2_failure_diagnostic.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rom1ad1-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${ROM1AD1_EVIDENCE_DIR:-$ROOT/ROM1AD1_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "ROM1AD1_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG_COMMIT" HEAD || fail "D1 preregistration not ancestor"
git diff --quiet "$PREREG_COMMIT"...HEAD -- src reference || fail "D1 changed src/reference"
echo "ROM1AD1_SOURCE_FREEZE=PASS"

python3 - "$PREREG" "$PARENT" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); f=json.load(open(sys.argv[2]))
assert p["phase"]=="PREREGISTERED_BEFORE_DIAGNOSTIC_EXECUTION"
assert p["case"]["history"]=="D01"
assert p["case"]["accepted_predecessor_steps"]==20
assert p["case"]["failed_step"]==21
assert p["case"]["bottom_mode"]==2
assert p["frozen_controls"]["total_balance_tolerance_cm_per_day"]==1e-12
assert p["representation_diagnostic"]["policy_applied_to_solver"] is False
assert f["observed_failure"]["accepted_steps_before_failure"]==20
assert f["observed_failure"]["failed_step"]==21
print("ROM1AD1_AUTHORITY_LOCK=PASS")
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/stubs_n16.f90"     --target "$TEST" --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$EVIDENCE/o$opt.txt" 2>&1 || {
    cat "$EVIDENCE/o$opt.txt" >&2
    fail "D1 diagnostic O$opt"
  }
  cat "$EVIDENCE/o$opt.txt"
  grep -Fq 'ROM1AD1_DIAGNOSTIC_COMPLETE=PASS' "$EVIDENCE/o$opt.txt" || fail "missing D1 complete marker O$opt"
done
cmp "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" || fail "D1 O0/O2 output drift"

python3 "$ANALYZER" --input "$EVIDENCE/o2.txt" --repeat "$EVIDENCE/o0.txt"   --output "$EVIDENCE/ROM1AD1_RESULT.json" | tee "$EVIDENCE/analyzer.txt"
cat "$EVIDENCE/ROM1AD1_RESULT.json"
sha256sum "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" "$EVIDENCE/ROM1AD1_RESULT.json"   "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"
git diff --check "$PREREG_COMMIT"...HEAD
echo "ROM1AD1_EVIDENCE_PRESERVED=PASS"
