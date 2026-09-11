#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpm07b-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=b52e4dc5ff1c16ccaf11853cc085c7099e17ccc0
expected_src=$'src/process/mod_restricted_soil_temperature.f90\nsrc/process/mod_soil_temperature_contract.f90'
changed_src="$(git diff --name-only "$BASE" -- src | sort)"
[[ "$changed_src" == "$expected_src" ]] || {
  echo "FPM07B_UNEXPECTED_PRODUCTION_DELTA" >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FPM07B_PRODUCTION_DELTA_TWO_PROCESS_MODULES=PASS'

git diff --check "$BASE" -- src/process tests/fpm integration/f-pm

echo 'FPM07B_DIFF_CHECK=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FPM07B_PROTECTED_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}
check_blob src/transaction/mod_transaction_reference.f90 2fd932b74dbd0ffc0ec089f49e632b7ac8852df4
check_blob src/solver/mod_soil_water_solver_contract.f90 dc7b14a06f64c8ab0af9747f707b3394a5f5cbe0
check_blob src/solver/mod_process_hydraulic_view.f90 d7d85fe71ced0d94b29c8d9395859ae1834f7dd6
echo 'FPM07B_KERNEL_AND_HYDRAULIC_SEAM_LOCKS=PASS'

python3 - <<'PY'
from pathlib import Path
contract = Path('src/process/mod_soil_temperature_contract.f90').read_text()
process = Path('src/process/mod_restricted_soil_temperature.f90').read_text()

assert 'extends(transaction_state_t)' in contract
assert 'temperature_c(:)' in contract
assert 'soil_temperature_restart_payload_t' in contract
assert 'soil_temperature_workspace_t' in contract
assert 'soil_temperature_field_view_t' in contract
assert 'procedure :: clone => soil_temperature_state_clone' in contract
assert 'require_energy_closure' not in contract
assert 'save' not in contract.lower()
for forbidden in ['open(', 'read(', 'write(', 'daynr', 't1900', 'swpfilnam', 'pathwork', 'headcalc', 'jacobian', 'newton']:
    assert forbidden not in contract.lower(), forbidden

assert 'use mod_process_hydraulic_view, only: process_hydraulic_view_t' in process
assert '0.5_real64*(hydraulic_start%water_content+hydraulic_end%water_content)' in process
assert 'prescribed_surface_temperature_c' in process
assert 'energy_residual_j_cm2' in process
assert 'abs(residual)>numerical%energy_abs_tolerance_j_cm2' in process
assert 'require_energy_closure' not in process
assert 't1<=t0' in process
assert 'save' not in process.lower()
for forbidden in ['headcalc', 'pressure_head', 'jacobian', 'newton', 'open(', 'read(', 'write(', 'daynr', 't1900', 'swpfilnam', 'afgen', 'snow', 'frost', 'latent', 'ice']:
    assert forbidden not in process.lower(), forbidden

print('FPM07B_EXPLICIT_DATA_SEPARATION=PASS')
print('FPM07B_TRANSACTION_STATE_CONTRACT=PASS')
print('FPM07B_NO_LEGACY_IO_OR_CALENDAR_ASSUMPTION=PASS')
print('FPM07B_NO_HEADCALC_OR_SOLVER_INTERNALS=PASS')
print('FPM07B_NO_FROST_OR_SNOW_SCOPE_CREEP=PASS')
print('FPM07B_ENERGY_CLOSURE_HARD_GATE=PASS')
PY

DEPS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
STRICT=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${DEPS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/transaction/mod_transaction_reference.f90 -o "$OUT/mod_transaction_reference.o"
  gfortran "${DEPS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_soil_water_solver_contract.f90 -o "$OUT/mod_soil_water_solver_contract.o"
  gfortran "${DEPS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_process_hydraulic_view.f90 -o "$OUT/mod_process_hydraulic_view.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_soil_temperature_contract.f90 -o "$OUT/mod_soil_temperature_contract.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_restricted_soil_temperature.f90 -o "$OUT/mod_restricted_soil_temperature.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpm/test_fpm07b_restricted_soil_temperature.f90 -o "$OUT/test_fpm07b.o"
  gfortran -O"$opt" \
    "$OUT/mod_transaction_reference.o" "$OUT/mod_soil_water_solver_contract.o" "$OUT/mod_process_hydraulic_view.o" \
    "$OUT/mod_soil_temperature_contract.o" "$OUT/mod_restricted_soil_temperature.o" "$OUT/test_fpm07b.o" \
    -o "$OUT/test_fpm07b"

  "$OUT/test_fpm07b" > "$OUT/output.txt" 2>&1
  "$OUT/test_fpm07b" > "$OUT/output-repeat.txt" 2>&1
  cmp "$OUT/output.txt" "$OUT/output-repeat.txt"

  for marker in \
    'FPM07B_ZERO_GRADIENT_CONDUCTION_IDENTITY=PASS' \
    'FPM07B_CONSTANT_BOUNDARY_INDEPENDENT_REFERENCE=PASS' \
    'FPM07B_SENSIBLE_ENERGY_ACCOUNTING=PASS' \
    'FPM07B_DEVRIES_DRY_TRANSITION_WET_REGIMES=PASS' \
    'FPM07B_TEMPORAL_REFINEMENT=PASS' \
    'FPM07B_CONTINUOUS_SPLIT_RESTART_IDENTITY=PASS' \
    'FPM07B_REJECTED_TRIAL_IMMUTABILITY=PASS' \
    'FPM07B_TRANSACTION_STATE_AND_SEMANTIC_VIEW=PASS' \
    'FPM07B_FAIL_CLOSED_INVALID_INTERVAL=PASS' \
    'FPM07B_MULTISWAP_COLUMN_ISOLATION=PASS' \
    'FPM07B_FAIL_CLOSED_INVALID_HYDRAULIC_VIEW=PASS' \
    'FPM07B_RESTRICTED_SOIL_TEMPERATURE_TEST PASS'; do
      grep -Fq "$marker" "$OUT/output.txt"
  done
  echo "FPM07B_CANDIDATE_O${opt}=PASS"
  echo "FPM07B_REPEATED_RUN_DETERMINISM_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FPM07B_CANDIDATE_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FPM07B_CANDIDATE_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FPM07B_RESTRICTED_SOIL_TEMPERATURE_CANDIDATE_GATE PASS'
