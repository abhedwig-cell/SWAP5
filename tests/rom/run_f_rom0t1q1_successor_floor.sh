#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PREREG_COMMIT=957dd5df6d89f6364e6f863fac62b98b7a9eddcc
TA5_SOURCE_HEAD=a388a4f14002fafd1cd8e3471675222672d01eb7
PREREG=integration/f-rom/F-ROM0T1Q1_PREREGISTRATION.json
T1_STATUS=integration/f-rom/F-ROM0T1_STATUS.json
D1_STATUS=integration/f-rom/F-ROM0T1D1_STATUS.json
V1_STATUS=integration/f-rom/F-ROM0V1_STATUS.json
TEST=tests/rom/test_f_rom0t1q1_successor_floor.f90
ANALYZER=tests/rom/analyze_f_rom0t1q1_successor_floor.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rom0t1q1-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROM0T1Q1_EVIDENCE_DIR:-$ROOT/F-ROM0T1Q1_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROM0T1Q1_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG_COMMIT" HEAD || fail "ROM0T1Q1 preregistration not ancestor"
git diff --quiet "$TA5_SOURCE_HEAD"...HEAD -- src reference || fail "ROM0T1Q1 changed production/reference source"
echo "F_ROM0T1Q1_SOURCE_FREEZE=PASS"

python3 - "$PREREG" "$T1_STATUS" "$D1_STATUS" "$V1_STATUS" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]));t=json.load(open(sys.argv[2]));d=json.load(open(sys.argv[3]));v=json.load(open(sys.argv[4]))
assert p["phase"]=="PREREGISTERED_BEFORE_SUCCESSOR_POLICY_EXECUTION"
assert p["predecessors"]["T1"]=="ORIGINAL_TEMPORAL_REFERENCE_FLOOR_NOT_MEASURABLE_UNDER_FROZEN_CONTROL"
assert p["predecessors"]["T1D1"]=="T1_RETRY_CAUSE_NONUNIFORM"
assert p["independent_policy_authority"]["P2E19"]["integrated_balance_allowance_cm_per_substep"]==1.6e-15
assert p["independent_policy_authority"]["P2E21"]["failed_residual_used"] is False
assert p["strict_control"]["dt_base_day"]==0.0016
assert p["strict_control"]["dt_refined_day"]==0.0008
assert p["overlap_neutrality"]["expected_strict_accepted_refined_steps"]==87
assert p["production_admission_authorized"] is False
assert p["rom1a_authorized"] is False
assert t["decision"]=="ORIGINAL_TEMPORAL_REFERENCE_FLOOR_NOT_MEASURABLE_UNDER_FROZEN_CONTROL"
assert d["decision"]=="T1_RETRY_CAUSE_NONUNIFORM"
assert v["decision"]=="VERTICAL_REFERENCE_FLOOR_MEASURED"
print("F_ROM0T1Q1_AUTHORITY_LOCK=PASS")
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/stubs_n16.f90"     --target "$TEST" --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$EVIDENCE/o$opt.txt" 2>&1 || {
    cat "$EVIDENCE/o$opt.txt" >&2
    fail "T1Q1 executable O$opt"
  }
  cat "$EVIDENCE/o$opt.txt"
  grep -Fq 'F_ROM0T1Q1_EXECUTION_COMPLETE=PASS' "$EVIDENCE/o$opt.txt" || fail "execution marker O$opt"
  [[ "$(grep -c 'F_ROM0T1Q1_BASE_PASS|' "$EVIDENCE/o$opt.txt")" -eq 4 ]] || fail "four base trajectories O$opt"
  [[ "$(grep -c 'F_ROM0T1Q1_CONTROL|' "$EVIDENCE/o$opt.txt")" -eq 4 ]] || fail "four strict provenance rows O$opt"
  [[ "$(grep -c 'F_ROM0T1Q1_CASE_PASS|' "$EVIDENCE/o$opt.txt")" -eq 4 ]] || fail "four successor case pass rows O$opt"
  [[ "$(grep -c 'F_ROM0T1Q1_COMPARE|' "$EVIDENCE/o$opt.txt")" -eq 128 ]] || fail "128 temporal comparisons O$opt"
done
cmp "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" || fail "T1Q1 O0/O2 drift"
"$BUILD/o2/rom0_test" > "$EVIDENCE/o2_repeat.txt" 2>&1 || fail "T1Q1 repeat"
cmp "$EVIDENCE/o2.txt" "$EVIDENCE/o2_repeat.txt" || fail "T1Q1 repeat drift"
echo "F_ROM0T1Q1_O0_O2_IDENTITY=PASS"
echo "F_ROM0T1Q1_REPEAT_IDENTITY=PASS"

python3 "$ANALYZER" --input "$EVIDENCE/o2.txt" --repeat "$EVIDENCE/o2_repeat.txt"   --output "$EVIDENCE/F-ROM0T1Q1_RESULT.json" | tee "$EVIDENCE/analyzer.txt"
python3 - "$EVIDENCE/F-ROM0T1Q1_RESULT.json" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
assert r["decision"] in {"T1_SUCCESSOR_REFERENCE_POLICY_QUALIFIED_AND_TEMPORAL_FLOOR_MEASURED","T1_SUCCESSOR_REFERENCE_POLICY_NO_GO"}
assert r["strict_refined_provenance_reproduced"] is True
assert r["repeat_stdout_bitwise_identity"] is True
print("F_ROM0T1Q1_SCIENTIFIC_DECISION="+r["decision"])
PY
cat "$EVIDENCE/F-ROM0T1Q1_RESULT.json"
sha256sum "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" "$EVIDENCE/o2_repeat.txt"   "$EVIDENCE/F-ROM0T1Q1_RESULT.json" "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"
git diff --check "$PREREG_COMMIT"...HEAD
echo "F_ROM0T1Q1_EVIDENCE_PRESERVED=PASS"
