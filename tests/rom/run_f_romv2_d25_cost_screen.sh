#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=e6c28770786a4cc7cb2ab6cf4b8e3f936c44b3f1
PREREG=integration/f-rom/F-ROMV2_D25_PREREGISTRATION.json
PREREG_BLOB=b36e5ad7ab2a3f952b264598ecf632cf502adaf3
D24_PREREG=integration/f-rom/F-ROMV2_D24_PREREGISTRATION.json
ORACLE=tests/rom/oracle_f_romv2_d25_fmc.py
FMC_TEST=tests/rom/test_f_romv2_d25_fmc_compiled.f90
REF_TEST=tests/rom/test_f_romv2_d25_reference_benchmark.f90
EQUIV=tests/rom/validate_f_romv2_d25_fmc_equivalence.py
TIMING=tests/rom/run_f_romv2_d25_timing.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py

EXPECTED_R16_SHA=c0571d38427e4122a6376afb9f24aa6a1c625b2ba2524f81542c5dca3bb0c826
EXPECTED_R2_SHA=a1fec425c91e5131bccb53874ed4f8d82c65a62d8e8e3a6b901806b710e20748

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-romv2-d25-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROMV2_D25_EVIDENCE_DIR:-$ROOT/F-ROMV2-D25-EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROMV2_D25_GATE_FAIL $*" >&2; exit 1; }

git fetch --no-tags origin integration/f-ci-canonical
LIVE="$(git rev-parse FETCH_HEAD)"
[[ "$LIVE" == "$BASE" ]] || fail "canonical advanced after D25 preregistration: $LIVE"
git merge-base --is-ancestor "$BASE" HEAD || fail "D25 candidate not descendant of preregistered canonical"
git diff --quiet "$BASE"...HEAD -- src reference || fail "D25 mutated src/reference"
[[ "$(git rev-parse HEAD:$PREREG)" == "$PREREG_BLOB" ]] || fail "D25 preregistration blob drift"

python3 - "$PREREG" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p["phase"]=="PREREGISTERED_BEFORE_COMPILED_FMC_IMPLEMENTATION_AND_TIMING_EXPOSURE"
assert p["compiled_FMC_identity"]["moisture_bins"]==200
assert p["compiled_FMC_identity"]["process_step_seconds"]==10
assert p["stage2_R16_only_timing_calibration"]["FMC_R2_timing_exposed_during_calibration"] is False
assert p["stage3_screening_protocol"]["measured_samples_per_route"]==30
assert "NO_FORMAL_SPEEDUP_CLAIM" in p["firewalls"]
print("F_ROMV2_D25_PREREGISTRATION_LOCK=PASS")
PY

# Stage 1A: regenerate the frozen D24 Python oracle.
python3 "$ORACLE" --prereg "$D24_PREREG" --output "$EVIDENCE/F-ROMV2_D25_ORACLE.json" \
  | tee "$EVIDENCE/oracle.txt"
grep -Fq '"decision": "D25_FROZEN_D24_PYTHON_ORACLE_PASS"' "$EVIDENCE/F-ROMV2_D25_ORACLE.json" \
  || fail "D24 Python oracle no-go"

# Stage 1B: compile standalone FMC at O0/O2 and validate against the frozen oracle.
for opt in 0 2; do
  exe="$BUILD/fmc_o$opt"
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -pedantic -O$opt "$FMC_TEST" -o "$exe"
  "$exe" validate > "$EVIDENCE/FMC_o$opt.txt" 2>&1 || {
    tail -n 300 "$EVIDENCE/FMC_o$opt.txt" >&2
    fail "FMC O$opt validation execution"
  }
  grep -Fq 'F_ROMV2_D25_FMC_VALIDATE_COMPLETE=PASS' "$EVIDENCE/FMC_o$opt.txt" || fail "FMC O$opt completion missing"
done

python3 "$EQUIV" \
  --oracle "$EVIDENCE/F-ROMV2_D25_ORACLE.json" \
  --o0 "$EVIDENCE/FMC_o0.txt" --o2 "$EVIDENCE/FMC_o2.txt" \
  --output "$EVIDENCE/F-ROMV2_D25_FMC_EQUIVALENCE.json" \
  | tee "$EVIDENCE/equivalence.txt"
grep -Fq '"decision": "D25_COMPILED_FMC_IMPLEMENTATION_EQUIVALENCE_PASS"' "$EVIDENCE/F-ROMV2_D25_FMC_EQUIVALENCE.json" \
  || fail "compiled FMC implementation equivalence no-go"

# Stage 1C: current-source R16/R2 validation must remain byte-identical to D24.
for spec in "R16 16 10" "R2 2 80"; do
  read -r id n dz <<<"$spec"
  stub="$BUILD/stubs_n$n.f90"
  python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90 --output "$stub" --nodes "$n" --dz-cm "$dz"
  for opt in 0 2; do
    outdir="$BUILD/${id}_o${opt}"
    python3 "$COMPILER" --root "$ROOT" --stub "$stub" --target "$REF_TEST" \
      --external-source src/legacy/b1_10_port/headcalc.f90 --build "$outdir" --opt "$opt"
    "$outdir/rom0_test" > "$EVIDENCE/${id}_o${opt}.txt" 2>&1 || {
      tail -n 600 "$EVIDENCE/${id}_o${opt}.txt" >&2
      fail "${id} O${opt} validation execution"
    }
    grep -Fq 'F_ROMV2_D24_REF_EXECUTION_COMPLETE=PASS' "$EVIDENCE/${id}_o${opt}.txt" \
      || fail "${id} O${opt} completion missing"
  done
  cmp "$EVIDENCE/${id}_o0.txt" "$EVIDENCE/${id}_o2.txt" || fail "${id} O0/O2 validation drift"
done

R16_SHA="$(sha256sum "$EVIDENCE/R16_o2.txt" | awk '{print $1}')"
R2_SHA="$(sha256sum "$EVIDENCE/R2_o2.txt" | awk '{print $1}')"
[[ "$R16_SHA" == "$EXPECTED_R16_SHA" ]] || fail "R16 validation hash drift: $R16_SHA"
[[ "$R2_SHA" == "$EXPECTED_R2_SHA" ]] || fail "R2 validation hash drift: $R2_SHA"
echo "F_ROMV2_D25_D24_REFERENCE_IDENTITY=PASS"

# Stages 2+3: R16-only calibration, then warmups + frozen 30-triad shared-host screen.
python3 "$TIMING" \
  --fmc "$BUILD/fmc_o2" \
  --r2 "$BUILD/R2_o2/rom0_test" \
  --r16 "$BUILD/R16_o2/rom0_test" \
  --fmc-validate "$EVIDENCE/FMC_o2.txt" \
  --r2-validate "$EVIDENCE/R2_o2.txt" \
  --r16-validate "$EVIDENCE/R16_o2.txt" \
  --calibration-output "$EVIDENCE/F-ROMV2_D25_TIMING_CALIBRATION.json" \
  --output "$EVIDENCE/F-ROMV2_D25_COST_SCREEN.json" \
  | tee "$EVIDENCE/timing.txt"

sha256sum "$EVIDENCE"/* > "$EVIDENCE/sha256.txt"
echo "F_ROMV2_D25_SHARED_HOST_COST_SCREEN=PASS"
