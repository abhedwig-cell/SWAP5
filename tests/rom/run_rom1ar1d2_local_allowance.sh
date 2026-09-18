#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PREREG_COMMIT=227bc7d3765d3bf77a129fe796f6251f36e9b08b
PREREG=integration/f-rom/ROM1AR1D2_PREREGISTRATION.json
D1_STATUS=integration/f-rom/ROM1AR1D1_STATUS.json
TEST=tests/rom/test_rom1ar1d1_d08_failure_diagnostic.f90
ANALYZER=tests/rom/analyze_rom1ar1d2_local_allowance.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rom1ar1d2-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${ROM1AR1D2_EVIDENCE_DIR:-$ROOT/ROM1AR1D2_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "ROM1AR1D2_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG_COMMIT" HEAD || fail "D2 preregistration not ancestor"
git diff --quiet "$PREREG_COMMIT"...HEAD -- src reference || fail "D2 changed src/reference"
echo "ROM1AR1D2_SOURCE_FREEZE=PASS"

python3 - "$PREREG" "$D1_STATUS" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); d=json.load(open(sys.argv[2]))
assert p["phase"]=="PREREGISTERED_BEFORE_DIAGNOSTIC_EXECUTION"
assert p["case"]["history"]=="D08"
assert p["case"]["failed_step"]==34
assert p["case"]["expected_failure_class"]=="RETRY_LOCAL_BALANCE"
assert p["independent_method_authority"]["compartment_integrated_allowance_cm"]==1.6e-15
assert p["independent_method_authority"]["failed_D08_residual_used_to_choose_allowance"] is False
assert p["diagnostic"]["policy_applied_to_solver"] is False
assert d["decision"]=="ROM1AR1D1_RETRY_LOCAL_BALANCE"
assert d["local_balance_policy_authorized"] is False
print("ROM1AR1D2_AUTHORITY_LOCK=PASS")
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/stubs_n16.f90"     --target "$TEST" --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$EVIDENCE/o$opt.txt" 2>&1 || {
    cat "$EVIDENCE/o$opt.txt" >&2
    fail "D2 diagnostic O$opt"
  }
  grep -Fq 'ROM1AR1D1_DIAGNOSTIC_COMPLETE=PASS' "$EVIDENCE/o$opt.txt" || fail "missing source diagnostic completion O$opt"
done
cmp "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" || fail "D2 O0/O2 drift"

python3 "$ANALYZER" --input "$EVIDENCE/o2.txt" --repeat "$EVIDENCE/o0.txt"   --output "$EVIDENCE/ROM1AR1D2_RESULT.json" | tee "$EVIDENCE/analyzer.txt"
cat "$EVIDENCE/ROM1AR1D2_RESULT.json"
sha256sum "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" "$EVIDENCE/ROM1AR1D2_RESULT.json"   "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"
git diff --check "$PREREG_COMMIT"...HEAD
echo "ROM1AR1D2_EVIDENCE_PRESERVED=PASS"
