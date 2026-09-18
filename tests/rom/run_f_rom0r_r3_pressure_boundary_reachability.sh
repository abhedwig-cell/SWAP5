#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

R3_PREREG_COMMIT=d5881828e82c7339883180a8cb7afd0fda426e2d
TA5_EXEC_HEAD=a388a4f14002fafd1cd8e3471675222672d01eb7
PREREG=integration/f-rom/F-ROM0R_R3_PREREGISTRATION.json
TA4_STATUS=integration/f-rom/F-ROM0TA4_STATUS.json
TA5_STATUS=integration/f-rom/F-ROM0TA5_STATUS.json
TEST=tests/rom/test_f_rom0r_r3_pressure_boundary_reachability.f90
ANALYZER=tests/rom/analyze_f_rom0r_r3_pressure_boundary_reachability.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-f-rom0r-r3-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROM0R_R3_EVIDENCE_DIR:-$ROOT/F-ROM0R_R3_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROM0R_R3_GATE_FAIL $*" >&2; exit 1; }

if [[ "${GITHUB_EVENT_NAME:-}" == "pull_request" && -n "${GITHUB_HEAD_REF:-}" ]]; then
  CANDIDATE="$(git rev-parse "origin/$GITHUB_HEAD_REF")"
else
  CANDIDATE="$(git rev-parse HEAD)"
fi

git merge-base --is-ancestor "$R3_PREREG_COMMIT" "$CANDIDATE" || fail "R3 preregistration not ancestor"
git diff --quiet "$TA5_EXEC_HEAD"..."$CANDIDATE" -- src reference || fail "production/reference source changed after qualified TA5 head"
echo "F_ROM0R_R3_SOURCE_FREEZE=PASS"

python3 - "$PREREG" "$TA4_STATUS" "$TA5_STATUS" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
t4=json.load(open(sys.argv[2]))
t5=json.load(open(sys.argv[3]))
assert p["phase"]=="PREREGISTERED_EXECUTION_BLOCKED_ON_TA4_AND_TA5"
assert p["materials"]==["B01","B14"]
assert p["pressure_boundary_perturbation"]["cases"][0]["bottom_head_expression"]=="0.75*h0"
assert p["pressure_boundary_perturbation"]["cases"][1]["bottom_head_expression"]=="1.25*h0"
assert p["pressure_boundary_perturbation"]["amplitude_selected_after_ROM_results"] is False
assert p["temporal_control"]["perturbation_dt_day"]==0.0008
assert p["temporal_control"]["perturbation_intervals"]==16
assert p["temporal_control"]["automatic_retry_or_subdivision"] is False
assert p["rom1a_authorized"] is False
assert t4["decision"]=="REFINED_REFERENCE_CANDIDATE_RESTART_REPLAY_QUALIFIED"
assert t4["r3_dependency_satisfied"] is True
assert t5["decision"]=="PRESCRIBED_HEAD_REFERENCE_FLOOR_SAMPLE_BINDING_QUALIFIED"
assert t5["r3_dependency_satisfied"] is True
print("F_ROM0R_R3_PREREGISTRATION_AND_DEPENDENCIES=PASS")
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/rom0r_r3_stubs_n16.f90" --nodes 16 --dz-cm 10
python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/rom0r_r3_stubs_n16.f90"   --target "$TEST" --external-source src/legacy/b1_10_port/headcalc.f90   --build "$BUILD/o2" --opt 2

"$BUILD/o2/rom0_test" >"$EVIDENCE/raw.txt" 2>&1 || {
  cat "$EVIDENCE/raw.txt" >&2
  fail "R3 executable failed structurally"
}
"$BUILD/o2/rom0_test" >"$EVIDENCE/repeat.txt" 2>&1 || {
  cat "$EVIDENCE/repeat.txt" >&2
  fail "R3 repeat executable failed structurally"
}
cat "$EVIDENCE/raw.txt"
python3 "$ANALYZER" --input "$EVIDENCE/raw.txt" --repeat "$EVIDENCE/repeat.txt"   --output "$EVIDENCE/F-ROM0R_R3_RESULT.json" | tee "$EVIDENCE/analyzer.txt"

python3 - "$EVIDENCE/F-ROM0R_R3_RESULT.json" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
allowed={
  "PRESSURE_BOUNDARY_REACHABILITY_QUALIFIED",
  "PRESSURE_BOUNDARY_REFERENCE_SAMPLE_NO_GO",
  "BIDIRECTIONAL_REACHABILITY_NOT_ESTABLISHED",
}
assert r["decision"] in allowed
assert r["structural_execution_complete"] is True
assert r["matrix_cases_attempted"]==4
print("F_ROM0R_R3_SCIENTIFIC_DECISION_RECORDED="+r["decision"])
PY

sha256sum "$EVIDENCE/raw.txt" "$EVIDENCE/repeat.txt" "$EVIDENCE/F-ROM0R_R3_RESULT.json"   "$EVIDENCE/analyzer.txt" >"$EVIDENCE/sha256.txt"
git diff --check "$R3_PREREG_COMMIT"...HEAD
echo "F_ROM0R_R3_EVIDENCE_PRESERVED=PASS"
