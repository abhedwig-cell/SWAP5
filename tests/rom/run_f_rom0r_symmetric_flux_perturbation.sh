#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=f7bd4d470d14bdedcbe60ef2b674fce4f1575e9c
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
TEST=tests/rom/test_f_rom0r_symmetric_flux_perturbation.f90
ANALYZER=tests/rom/analyze_f_rom0r_symmetric_flux_perturbation.py
PREREG=integration/f-rom/F-ROM0R_R2_PREREGISTRATION.json
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-f-rom0r-r2-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROM0R_R2_EVIDENCE_DIR:-$ROOT/F-ROM0R_R2_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE/cases"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "F_ROM0R_R2_GATE_FAIL $*" >&2; exit 1; }

if [[ "${GITHUB_EVENT_NAME:-}" == "pull_request" && -n "${GITHUB_HEAD_REF:-}" ]]; then
  CANDIDATE="$(git rev-parse "origin/$GITHUB_HEAD_REF")"
else
  CANDIDATE="$(git rev-parse HEAD)"
fi

git merge-base --is-ancestor "$BASE" "$CANDIDATE" || fail "R2 base not ancestor"
git diff --quiet "$BASE...$CANDIDATE" -- src reference || fail "R2 mutated production/reference source"
echo "F_ROM0R_R2_PRODUCTION_REFERENCE_DELTA=NONE"

python3 - "$PREREG" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p["phase"]=="PREREGISTERED_BEFORE_EXECUTION"
assert p["materials"]==["B01","B14"]
assert p["perturbation"]["epsilon_fraction_of_k0"]==0.01
assert p["perturbation"]["base_perturbation_intervals"]==8
assert p["perturbation"]["refined_perturbation_intervals"]==16
assert p["perturbation"]["physical_horizon_day"]==0.0128
assert p["perturbation"]["base_interval_day"]==0.0016
assert p["perturbation"]["refined_interval_day"]==0.0008
assert p["threshold_retuning_after_execution_allowed"] is False
assert p["rom1a_authorized"] is False
print("F_ROM0R_R2_PREREGISTRATION_LOCK=PASS")
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/rom0r_stubs_n16.f90" --nodes 16 --dz-cm 10
python3 "$COMPILER"   --root "$ROOT"   --stub "$BUILD/rom0r_stubs_n16.f90"   --target "$TEST"   --external-source src/legacy/b1_10_port/headcalc.f90   --build "$BUILD/r2"   --opt 2

EXE="$BUILD/r2/rom0_test"
cases=(
  'B01|TOP_PLUS|0.0016'
  'B01|TOP_MINUS|0.0016'
  'B14|TOP_PLUS|0.0016'
  'B14|TOP_MINUS|0.0016'
  'B01|TOP_PLUS|0.0008'
  'B14|TOP_PLUS|0.0008'
)
for spec in "${cases[@]}"; do
  IFS='|' read -r material cid dt <<<"$spec"
  out="$EVIDENCE/cases/${material}_${cid}_dt${dt}.txt"
  echo "F_ROM0R_R2_RUN_CASE=${material}_${cid}_dt${dt}"
  if ! "$EXE" "$material" "$cid" "$dt" >"$out" 2>&1; then
    cat "$out" >&2
    fail "R2 case failed: $spec"
  fi
  grep -Fq "F_ROM0R_R2_PASS|MATERIAL=$material|CASE=$cid" "$out" || {
    cat "$out" >&2
    fail "missing R2 pass marker $spec"
  }
  cat "$out"
done

python3 "$ANALYZER" --cases "$EVIDENCE/cases" --output "$EVIDENCE/F-ROM0R_R2_RESULT.json"
sha256sum "$EVIDENCE"/cases/*.txt "$EVIDENCE/F-ROM0R_R2_RESULT.json" >"$EVIDENCE/sha256.txt"
cat "$EVIDENCE/F-ROM0R_R2_RESULT.json"
echo "F_ROM0R_R2_GATE=PASS"
