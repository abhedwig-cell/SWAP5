#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=e6c28770786a4cc7cb2ab6cf4b8e3f936c44b3f1
PREREG=integration/f-rom/F-ROMV2_D25_PREREGISTRATION.json
PREREG_BLOB=188d4912875b58cd8a31dcdd6f256b868e648166
D24_PREREG=integration/f-rom/F-ROMV2_D24_PREREGISTRATION.json
ORACLE=tests/rom/oracle_f_romv2_d25_fmc.py
FMC_SRC=tests/rom/test_f_romv2_d25_fmc_compiled.f90
FMC_EQ=tests/rom/validate_f_romv2_d25_fmc_equivalence.py
REF_SRC=tests/rom/test_f_romv2_d25_reference_benchmark.f90
SCREEN=tests/rom/run_f_romv2_d25_cost_screen.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
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

python3 - "$PREREG" integration/f-rom/F-ROMV2_D24_STATUS.json <<'PY'
import json,sys
p=json.load(open(sys.argv[1]));d24=json.load(open(sys.argv[2]))
assert p["phase"]=="PREREGISTERED_BEFORE_COMPILED_FMC_IMPLEMENTATION_AND_TIMING_EXPOSURE"
assert d24["decision"]=="FMC_NATIVE_RAINFALL_GROUNDWATER_COMPOSITION_RETAINS_RESEARCH_CANDIDACY_RELATIVE_TO_R2"
assert d24["all_eight_preregistered_frontier_gates_pass"] is True
assert p["performance_governance"]["cpu_baseline_established"] is False
assert "NO_EFFECT_BASED_BATCH_LENGTH_SELECTION" in p["firewalls"]
assert "NO_FORMAL_SPEEDUP_CLAIM" in p["firewalls"]
print("F_ROMV2_D25_PREREGISTRATION_LOCK=PASS")
PY

# Verify that the predecessor execution source named in the preregistration still has its frozen identity.
git fetch --no-tags origin work/f-romv2-d24-native-rainfall-groundwater
D24_EXEC="$(git rev-parse FETCH_HEAD)"
D24_ORACLE_BLOB="$(git rev-parse "$D24_EXEC:tests/rom/preflight_f_romv2_d24_native_rain_gw.py")"
D24_REF_BLOB="$(git rev-parse "$D24_EXEC:tests/rom/test_f_romv2_d24_native_rain_gw_comparators.f90")"
[[ "$D24_ORACLE_BLOB" == "2ca5ddef865f964b4acec92228569154e8214b25" ]] || fail "D24 oracle source drift"
[[ "$D24_REF_BLOB" == "482965026d7589bfd5b8dedbe8949ebcb78a3030" ]] || fail "D24 reference source drift"

# Stage 1A: frozen Python oracle.
python3 "$ORACLE" --prereg "$D24_PREREG" --output "$EVIDENCE/F-ROMV2_D25_ORACLE.json"   | tee "$EVIDENCE/oracle.txt"
grep -Fq '"decision": "D25_FROZEN_D24_PYTHON_ORACLE_PASS"' "$EVIDENCE/F-ROMV2_D25_ORACLE.json"   || fail "D25 Python oracle no-go"

# Stage 1B: compiled FMC at O0 and O2; compare all frozen endpoint quantities to the oracle.
for opt in 0 2; do
  exe="$BUILD/fmc_o$opt"
  gfortran -std=f2008 -ffree-line-length-none -O$opt "$FMC_SRC" -o "$exe"
  "$exe" validate > "$EVIDENCE/FMC_o$opt.txt"
done
python3 "$FMC_EQ" --oracle "$EVIDENCE/F-ROMV2_D25_ORACLE.json"   --o0 "$EVIDENCE/FMC_o0.txt" --o2 "$EVIDENCE/FMC_o2.txt"   --output "$EVIDENCE/F-ROMV2_D25_FMC_EQUIVALENCE.json" | tee "$EVIDENCE/equivalence.txt"
grep -Fq '"decision": "D25_COMPILED_FMC_IMPLEMENTATION_EQUIVALENCE_PASS"'   "$EVIDENCE/F-ROMV2_D25_FMC_EQUIVALENCE.json" || fail "compiled FMC equivalence no-go"

# Stage 1C: benchmark-capable R16/R2 harness must reproduce the immutable D24 validation stdout exactly.
for spec in "R16 16 10 c0571d38427e4122a6376afb9f24aa6a1c625b2ba2524f81542c5dca3bb0c826"             "R2 2 80 a1fec425c91e5131bccb53874ed4f8d82c65a62d8e8e3a6b901806b710e20748"; do
  read -r id n dz expected <<<"$spec"
  stub="$BUILD/stubs_n${n}.f90"
  python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90 --output "$stub" --nodes "$n" --dz-cm "$dz"
  for opt in 0 2; do
    outdir="$BUILD/${id}_o${opt}"
    python3 "$COMPILER" --root "$ROOT" --stub "$stub" --target "$REF_SRC"       --external-source src/legacy/b1_10_port/headcalc.f90 --build "$outdir" --opt "$opt"
    "$outdir/rom0_test" > "$EVIDENCE/${id}_o${opt}.txt" 2>&1 || {
      tail -n 500 "$EVIDENCE/${id}_o${opt}.txt" >&2
      fail "${id} validation O${opt}"
    }
    got="$(sha256sum "$EVIDENCE/${id}_o${opt}.txt" | awk '{print $1}')"
    [[ "$got" == "$expected" ]] || fail "${id} O${opt} stdout identity drift: $got"
  done
  cmp "$EVIDENCE/${id}_o0.txt" "$EVIDENCE/${id}_o2.txt" || fail "${id} O0/O2 validation drift"
done
echo "F_ROMV2_D25_REFERENCE_IMPLEMENTATION_EQUIVALENCE=PASS"

# Stage 2+3: R16-only calibration then fixed paired shared-host screen.
python3 "$SCREEN"   --fmc "$BUILD/fmc_o2"   --r2 "$BUILD/R2_o2/rom0_test"   --r16 "$BUILD/R16_o2/rom0_test"   --equivalence "$EVIDENCE/F-ROMV2_D25_FMC_EQUIVALENCE.json"   --output "$EVIDENCE/F-ROMV2_D25_COST_SCREEN.json"   | tee "$EVIDENCE/screen.txt"

sha256sum "$EVIDENCE"/* > "$EVIDENCE/sha256.txt"
echo "F_ROMV2_D25_SHARED_HOST_COST_SCREEN=PASS"
