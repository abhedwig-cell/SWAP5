#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=f7bd4d470d14bdedcbe60ef2b674fce4f1575e9c
PREREG_COMMIT=92acc3848c33cdfbd224f23e569a04f7c82d599b
PREREG=integration/f-rom/F-ROM0TA1_PREREGISTRATION.json
TEST=tests/rom/test_f_rom0ta1_reference_temporal_measurement.f90
ANALYZER=tests/rom/analyze_f_rom0ta1_reference_temporal_measurement.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-f-rom0ta1-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROM0TA1_EVIDENCE_DIR:-$ROOT/F-ROM0TA1_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROM0TA1_GATE_FAIL $*" >&2; exit 1; }

if [[ "${GITHUB_EVENT_NAME:-}" == "pull_request" && -n "${GITHUB_HEAD_REF:-}" ]]; then
  CANDIDATE="$(git rev-parse "origin/$GITHUB_HEAD_REF")"
else
  CANDIDATE="$(git rev-parse HEAD)"
fi

git merge-base --is-ancestor "$BASE" "$CANDIDATE" || fail "ROM authority base not ancestor"
git merge-base --is-ancestor "$PREREG_COMMIT" "$CANDIDATE" || fail "preregistration commit not ancestor of execution candidate"
git diff --quiet "$BASE...$CANDIDATE" -- src reference || fail "production/reference source changed in ROM workstream"
echo "F_ROM0TA1_PRODUCTION_REFERENCE_DELTA=NONE"

python3 - "$PREREG" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p["phase"]=="PREREGISTERED_BEFORE_FIRST_EXECUTION"
assert p["materials"]==["B01","B14"]
assert p["geometry"]=={"nodes":16,"dz_cm":10,"depth_cm":160}
assert p["perturbation"]["epsilon_fraction_of_k0"]==0.01
assert p["matrix_rows"]==8
assert p["temporal_pairs"]==[
 {"full_dt_day":0.0016,"half_dt_day":0.0008,"common_horizon_day":0.0016},
 {"full_dt_day":0.0008,"half_dt_day":0.0004,"common_horizon_day":0.0008}]
assert p["measurement_surface"]["head_budget_used"] is False
assert p["measurement_surface"]["transaction_acceptance_used_as_authority"] is False
assert p["threshold_retuning_after_execution_allowed"] is False
assert p["rom1a_authorized"] is False
print("F_ROM0TA1_PREREGISTRATION_LOCK=PASS")
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --output "$BUILD/rom0ta1_stubs_n16.f90" --nodes 16 --dz-cm 10
python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/rom0ta1_stubs_n16.f90" \
  --target "$TEST" --external-source src/legacy/b1_10_port/headcalc.f90 \
  --build "$BUILD/o2" --opt 2

"$BUILD/o2/rom0_test" | tee "$EVIDENCE/raw.txt"
python3 "$ANALYZER" --input "$EVIDENCE/raw.txt" --output "$EVIDENCE/F-ROM0TA1_RESULT.json" | tee "$EVIDENCE/analyzer.txt"
sha256sum "$EVIDENCE/raw.txt" "$EVIDENCE/F-ROM0TA1_RESULT.json" "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"
cat "$EVIDENCE/F-ROM0TA1_RESULT.json"
echo "F_ROM0TA1_EXECUTION_COMPLETE=PASS"
