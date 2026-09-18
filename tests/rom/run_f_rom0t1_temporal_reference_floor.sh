#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PREREG_COMMIT=bd9f1a8ac6ab5b718b01049b4d2dc90f4b9b909a
TA5_SOURCE_HEAD=a388a4f14002fafd1cd8e3471675222672d01eb7
PREREG=integration/f-rom/F-ROM0T1_PREREGISTRATION.json
V1_STATUS=integration/f-rom/F-ROM0V1_STATUS.json
TEST=tests/rom/test_f_rom0t1_temporal_reference_floor.f90
ANALYZER=tests/rom/analyze_f_rom0t1_temporal_reference_floor.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rom0t1-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROM0T1_EVIDENCE_DIR:-$ROOT/F-ROM0T1_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROM0T1_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG_COMMIT" HEAD || fail "ROM0T1 preregistration not ancestor"
git diff --quiet "$TA5_SOURCE_HEAD"...HEAD -- src reference || fail "ROM0T1 changed production/reference source"
echo "F_ROM0T1_SOURCE_FREEZE=PASS"

python3 - "$PREREG" "$V1_STATUS" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); v=json.load(open(sys.argv[2]))
assert p["phase"]=="PREREGISTERED_BEFORE_EXECUTION"
assert p["authority"]["why_TA1_TA3_do_not_substitute"]
assert len(p["cases"])==4
assert p["temporal_levels"][0]=={"id":"DT_BASE","dt_day":0.0016,"steps":32}
assert p["temporal_levels"][1]=={"id":"DT_REFINED","dt_day":0.0008,"steps":64}
assert p["common_horizon_day"]==0.0512
assert p["reference_sample_controls"]["representation_bounded_total_policy_used"] is False
assert p["reference_sample_controls"]["total_balance_rate_tolerance_cm_per_day"]==1e-12
assert p["threshold_rule"]=="MEASURE_ONLY_NO_POST_RESULT_NUMERICAL_ACCEPTANCE_THRESHOLD"
assert v["decision"]=="VERTICAL_REFERENCE_FLOOR_MEASURED"
assert p["rom1a_authorized"] is False
print("F_ROM0T1_AUTHORITY_LOCK=PASS")
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  out="$BUILD/o${opt}"
  python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/stubs_n16.f90" --target "$TEST" \
    --external-source src/legacy/b1_10_port/headcalc.f90 --build "$out" --opt "$opt"
  "$out/rom0_test" > "$EVIDENCE/o${opt}.txt" 2>&1 || {
    cat "$EVIDENCE/o${opt}.txt" >&2
    fail "O${opt} execution"
  }
  cat "$EVIDENCE/o${opt}.txt"
  grep -Fq 'F_ROM0T1_EXECUTION_COMPLETE=PASS' "$EVIDENCE/o${opt}.txt" || fail "completion marker O${opt}"
  pass_count="$(grep -c 'F_ROM0T1_CASE_PASS|' "$EVIDENCE/o${opt}.txt" || true)"
  [[ "$pass_count" -eq 8 ]] || fail "eight trajectories O${opt}; observed $pass_count"
done
cmp "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" || fail "O0/O2 drift"
"$BUILD/o2/rom0_test" > "$EVIDENCE/o2_repeat.txt" 2>&1 || fail "O2 repeat execution"
cmp "$EVIDENCE/o2.txt" "$EVIDENCE/o2_repeat.txt" || fail "O2 repeat drift"
echo "F_ROM0T1_O0_O2_IDENTITY=PASS"
echo "F_ROM0T1_REPEAT_IDENTITY=PASS"

python3 "$ANALYZER" --input "$EVIDENCE/o2.txt" --repeat "$EVIDENCE/o2_repeat.txt" \
  --output "$EVIDENCE/F-ROM0T1_RESULT.json" | tee "$EVIDENCE/analyzer.txt"
cat "$EVIDENCE/F-ROM0T1_RESULT.json"

python3 - "$EVIDENCE/F-ROM0T1_RESULT.json" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
assert r["decision"] in {"ORIGINAL_TEMPORAL_REFERENCE_FLOOR_MEASURED","ORIGINAL_TEMPORAL_REFERENCE_FLOOR_NOT_MEASURABLE_UNDER_FROZEN_CONTROL"}
print("F_ROM0T1_SCIENTIFIC_DECISION="+r["decision"])
PY

sha256sum "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" "$EVIDENCE/o2_repeat.txt" \
  "$EVIDENCE/F-ROM0T1_RESULT.json" "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"
git diff --check "$PREREG_COMMIT"...HEAD
echo "F_ROM0T1_EVIDENCE_PRESERVED=PASS"
