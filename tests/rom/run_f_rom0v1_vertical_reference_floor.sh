#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PREREG_COMMIT=41dee198f21064f1f644065ea7e1413e95ab62d0
TA5_SOURCE_HEAD=a388a4f14002fafd1cd8e3471675222672d01eb7
PREREG=integration/f-rom/F-ROM0V1_PREREGISTRATION.json
POLICY_RECON=integration/f-rom/F-ROM0_R3_POLICY_AUTHORITY_RECONCILIATION.json
TEST=tests/rom/test_f_rom0v1_vertical_reference_floor.f90
ANALYZER=tests/rom/analyze_f_rom0v1_vertical_reference_floor.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rom0v1-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROM0V1_EVIDENCE_DIR:-$ROOT/F-ROM0V1_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROM0V1_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG_COMMIT" HEAD || fail "ROM0V1 preregistration not ancestor"
git diff --quiet "$TA5_SOURCE_HEAD"...HEAD -- src reference || fail "ROM0V1 changed production/reference source"
echo "F_ROM0V1_SOURCE_FREEZE=PASS"

python3 - "$PREREG" "$POLICY_RECON" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); r=json.load(open(sys.argv[2]))
assert p["phase"]=="PREREGISTERED_BEFORE_EXECUTION"
assert p["cases"][0]["id"]=="B01_E1_NOMINAL_FLUX"
assert p["cases"][1]["id"]=="B14_E2_DRYING_FLUX"
assert p["temporal_control"]["dt_day"]==0.0016
assert p["temporal_control"]["steps"]==32
assert p["temporal_control"]["common_horizon_day"]==0.0512
assert p["threshold_rule"]=="MEASURE_ONLY_NO_POST_RESULT_NUMERICAL_ACCEPTANCE_THRESHOLD"
assert r["current_decision"]=="R3Q2_SUCCESSOR_AUTHORITY_CONTROLS_NEXT_ROM0_STEP"
assert r["vertical_reference_floor_authorized"] is True
assert p["authority"]["fixed_flux_representation_policy_authority"].startswith("PUB-P2E21 ")
assert p["authority"]["sample_authority"].startswith("F-ROM0TA3 ")
assert p["rom1a_authorized"] is False
print("F_ROM0V1_AUTHORITY_LOCK=PASS")
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10
python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n32.f90" --nodes 32 --dz-cm 5

for geom in 16 32; do
  stub="$BUILD/stubs_n${geom}.f90"
  for opt in 0 2; do
    out="$BUILD/g${geom}_o${opt}"
    python3 "$COMPILER" --root "$ROOT" --stub "$stub" --target "$TEST"       --external-source src/legacy/b1_10_port/headcalc.f90 --build "$out" --opt "$opt"
    "$out/rom0_test" > "$EVIDENCE/g${geom}_o${opt}.txt" 2>&1 || {
      cat "$EVIDENCE/g${geom}_o${opt}.txt" >&2
      fail "geometry ${geom} O${opt} execution"
    }
    grep -Fq 'F_ROM0V1_EXECUTION_COMPLETE=PASS' "$EVIDENCE/g${geom}_o${opt}.txt" || fail "completion marker G${geom} O${opt}"
    [[ "$(grep -c 'F_ROM0V1_CASE_PASS|' "$EVIDENCE/g${geom}_o${opt}.txt")" -eq 2 ]] || fail "two cases G${geom} O${opt}"
  done
  cmp "$EVIDENCE/g${geom}_o0.txt" "$EVIDENCE/g${geom}_o2.txt" || fail "O0/O2 drift geometry ${geom}"
  echo "F_ROM0V1_O0_O2_IDENTITY_G${geom}=PASS"
done

python3 "$ANALYZER" --g16 "$EVIDENCE/g16_o2.txt" --g32 "$EVIDENCE/g32_o2.txt"   --output "$EVIDENCE/F-ROM0V1_RESULT.json" | tee "$EVIDENCE/analyzer.txt"
cat "$EVIDENCE/F-ROM0V1_RESULT.json"

python3 - "$EVIDENCE/F-ROM0V1_RESULT.json" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
assert r["decision"] in {"VERTICAL_REFERENCE_FLOOR_MEASURED","VERTICAL_REFERENCE_FLOOR_NOT_MEASURABLE_UNDER_FROZEN_CONTROL"}
print("F_ROM0V1_SCIENTIFIC_DECISION="+r["decision"])
PY

sha256sum "$EVIDENCE/g16_o0.txt" "$EVIDENCE/g16_o2.txt" "$EVIDENCE/g32_o0.txt" "$EVIDENCE/g32_o2.txt"   "$EVIDENCE/F-ROM0V1_RESULT.json" "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"
git diff --check "$PREREG_COMMIT"...HEAD
echo "F_ROM0V1_EVIDENCE_PRESERVED=PASS"
