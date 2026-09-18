#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
PREREG_COMMIT=4649708525ad43bca8d8f2bfe5468e0fbb0a4b7f
PREREG=integration/f-rom/ROM1AR1D3_PREREGISTRATION.json
D2_STATUS=integration/f-rom/ROM1AR1D2_STATUS.json
MODE2_STATUS=integration/f-rom/ROM1AD2_STATUS.json
MODE5_STATUS=integration/f-rom/F-ROM0R_R3D4_STATUS.json
TEST=tests/rom/test_rom1ar1d3_discovery_fallback.f90
ANALYZER=tests/rom/analyze_rom1ar1d3_discovery_fallback.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rom1ar1d3-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${ROM1AR1D3_EVIDENCE_DIR:-$ROOT/ROM1AR1D3_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "ROM1AR1D3_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG_COMMIT" HEAD || fail "D3 preregistration not ancestor"
git diff --quiet "$PREREG_COMMIT"...HEAD -- src reference || fail "D3 changed src/reference"
echo "ROM1AR1D3_SOURCE_FREEZE=PASS"

python3 - "$PREREG" "$D2_STATUS" "$MODE2_STATUS" "$MODE5_STATUS" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); d2=json.load(open(sys.argv[2]))
m2=json.load(open(sys.argv[3])); m5=json.load(open(sys.argv[4]))
assert p["phase"]=="PREREGISTERED_BEFORE_POLICY_EXECUTION"
assert p["qualification_population"]["histories"]==[f"D{i:02d}" for i in range(1,9)]
assert p["qualification_population"]["target_accepted_steps"]==512
assert p["qualification_population"]["held_out_histories_executed"] is False
assert p["qualification_population"]["B14_executed"] is False
assert p["policy"]["pre_solve"]["local_integrated_allowance_cm"]==1.6e-15
assert p["policy"]["pre_solve"]["failed_residual_used_to_choose_any_bound"] is False
assert d2["decision"]=="ROM1AR1D2_LOCAL_RESIDUAL_WITHIN_PRIOR_INTEGRATED_ALLOWANCE"
assert m2["decision"]=="ROM1AD2_MODE2_FAIL_CLOSED_FALLBACK_QUALIFIED"
assert m5["decision"]=="R3_FAIL_CLOSED_TOTAL_ONLY_FALLBACK_QUALIFIED"
print("ROM1AR1D3_AUTHORITY_LOCK=PASS")
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/stubs_n16.f90"     --target "$TEST" --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$EVIDENCE/o$opt.txt" 2>&1 || {
    tail -n 300 "$EVIDENCE/o$opt.txt" >&2
    fail "D3 executable O$opt"
  }
  grep -Fq 'ROM1AR1D3_EXECUTION_COMPLETE=PASS' "$EVIDENCE/o$opt.txt" || fail "missing D3 completion O$opt"
  [[ "$(grep -c 'ROM1AR1D3_STATE|' "$EVIDENCE/o$opt.txt")" -eq 512 ]] || fail "expected 512 states O$opt"
done
cmp "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" || fail "D3 O0/O2 drift"

python3 "$ANALYZER" --input "$EVIDENCE/o2.txt" --repeat "$EVIDENCE/o0.txt"   --output "$EVIDENCE/ROM1AR1D3_RESULT.json" | tee "$EVIDENCE/analyzer.txt"
cat "$EVIDENCE/ROM1AR1D3_RESULT.json"
sha256sum "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" "$EVIDENCE/ROM1AR1D3_RESULT.json"   "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"
git diff --check "$PREREG_COMMIT"...HEAD
echo "ROM1AR1D3_EVIDENCE_PRESERVED=PASS"
