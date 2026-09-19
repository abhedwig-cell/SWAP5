#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=e6f7a98b8e4b4e5f7be67f231adf73a1d0b3e382
PREREG=integration/f-rom/F-ROMV2_D16_PREREGISTRATION.json
PREREG_BLOB=160768c6650cafdc33c2d4c2dbd9a587a049b94a
PREFLIGHT=tests/rom/preflight_f_romv2_d16_fmc_surface.py
TEST=tests/rom/test_f_romv2_d16_surface_comparators.f90
ANALYZER=tests/rom/analyze_f_romv2_d16_fmc_surface.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-romv2-d16-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROMV2_D16_EVIDENCE_DIR:-$ROOT/F-ROMV2-D16-EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROMV2_D16_GATE_FAIL $*" >&2; exit 1; }

git fetch --no-tags origin integration/f-ci-canonical
LIVE="$(git rev-parse FETCH_HEAD)"
[[ "$LIVE" == "$BASE" ]] || fail "canonical advanced after D16 preregistration: $LIVE"
git merge-base --is-ancestor "$BASE" HEAD || fail "D16 candidate not descendant of preregistered canonical"
git diff --quiet "$BASE"...HEAD -- src reference || fail "D16 mutated src/reference"
[[ "$(git rev-parse HEAD:$PREREG)" == "$PREREG_BLOB" ]] || fail "D16 preregistration blob drift"

python3 - "$PREREG" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p["phase"]=="PREREGISTERED_BEFORE_SWAP_TRAJECTORY_EXECUTION"
assert p["fmc_discretization"]["moisture_bins"]==200
assert p["fmc_discretization"]["process_substep_seconds"]==10
assert p["fmc_discretization"]["process_substeps_per_observation"]==9
assert p["reference_route"]["bottom_flux_cm_per_day"]==0
assert "NO_DRY_BIN_ACTIVATION_IN_D16" in p["firewalls"]
assert "NO_PONDING_OR_RUNOFF_IN_D16" in p["firewalls"]
assert "NO_RAINFALL_OR_PULSE_DURATION_RETUNING_AFTER_REFERENCE_EXPOSURE" in p["firewalls"]
print("F_ROMV2_D16_PREREGISTRATION_LOCK=PASS")
PY

python3 "$PREFLIGHT" --prereg "$PREREG" --output "$EVIDENCE/F-ROMV2_D16_PREFLIGHT_RESULT.json" | tee "$EVIDENCE/preflight.txt"
grep -Fq '"decision": "D16_FMC_MATCHED_SURFACE_PREFLIGHT_PASS"' "$EVIDENCE/F-ROMV2_D16_PREFLIGHT_RESULT.json" || fail "FMC-only preflight no-go"

for spec in "R16 16 10" "R2 2 80"; do
  read -r id n dz <<<"$spec"
  stub="$BUILD/stubs_n${n}.f90"
  python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90 --output "$stub" --nodes "$n" --dz-cm "$dz"
  for opt in 0 2; do
    outdir="$BUILD/${id}_o${opt}"
    python3 "$COMPILER" --root "$ROOT" --stub "$stub" --target "$TEST" \
      --external-source src/legacy/b1_10_port/headcalc.f90 --build "$outdir" --opt "$opt"
    "$outdir/rom0_test" > "$EVIDENCE/${id}_o${opt}.txt" 2>&1 || {
      tail -n 500 "$EVIDENCE/${id}_o${opt}.txt" >&2
      fail "${id} O${opt} execution"
    }
    grep -Fq 'F_ROMV2_D16_REF_EXECUTION_COMPLETE=PASS' "$EVIDENCE/${id}_o${opt}.txt" || fail "${id} missing completion O${opt}"
    [[ "$(grep -c 'F_ROMV2_D16_REF_STATE|' "$EVIDENCE/${id}_o${opt}.txt")" -eq 256 ]] || fail "${id} expected 256 states O${opt}"
  done
  cmp "$EVIDENCE/${id}_o0.txt" "$EVIDENCE/${id}_o2.txt" || fail "${id} O0/O2 drift"
  echo "F_ROMV2_D16_${id}_O0_O2_IDENTITY=PASS"
done

python3 "$ANALYZER" --r16 "$EVIDENCE/R16_o2.txt" --r2 "$EVIDENCE/R2_o2.txt" \
  --prereg "$PREREG" --preflight "$EVIDENCE/F-ROMV2_D16_PREFLIGHT_RESULT.json" \
  --output "$EVIDENCE/F-ROMV2_D16_RESULT.json" | tee "$EVIDENCE/analyzer.txt"

sha256sum "$EVIDENCE"/R*_o*.txt "$EVIDENCE/F-ROMV2_D16_PREFLIGHT_RESULT.json" \
  "$EVIDENCE/F-ROMV2_D16_RESULT.json" "$EVIDENCE/preflight.txt" "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"

echo "F_ROMV2_D16_FMC_SURFACE_COMPARATOR=PASS"
