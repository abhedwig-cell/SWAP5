#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpm08b-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=3ce245e3cac068268bdff2f0af0fdcdf022c82aa
changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "src/process/mod_drainage_spatial_distribution.f90" ]] || {
  echo "FPM08B_UNEXPECTED_PRODUCTION_DELTA" >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FPM08B_PRODUCTION_DELTA_SINGLE_PROCESS_MODULE=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FPM08B_PROTECTED_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/solver/mod_soil_water_solver_contract.f90 dc7b14a06f64c8ab0af9747f707b3394a5f5cbe0
check_blob src/solver/mod_process_hydraulic_view.f90 d7d85fe71ced0d94b29c8d9395859ae1834f7dd6
check_blob src/solver/mod_b110_source_sink_provider.f90 d6c57add72387e5c0022a44319fff08046194aac

echo 'FPM08B_PROTECTED_OWNER_SOURCE_LOCKS=PASS'

python3 - <<'PY'
from pathlib import Path
p=Path('src/process/mod_drainage_spatial_distribution.f90').read_text()
for forbidden in ['HeadCalc', 'headcalc', 'MOD_drainage', 'DIVDRA(', 'open(', 'read(', 'write(unit', 'drainage_resistance', 'drain_head']:
    assert forbidden not in p, forbidden
assert 'process_hydraulic_view_t' in p
assert 'hydraulic_view%groundwater_level' in p
assert 'scalar_transfer' in p
assert 'soil_to_drain_rate' in p
assert 'saturated_conductivity' in p
assert 'horizontal_anisotropy_factor' in p
assert 'drain_spacing' in p
assert '0.25_real64 * parameters%drain_spacing' in p
assert 'scalar_transfer - sum_previous' in p
assert 'LEGACY_ACTIVE_MAGNITUDE = 1.0e-10_real64' in p
assert 'SAVE' not in p.upper()
assert 'pressure_head' not in p
assert 'water_content' not in p
print('FPM08B_SOURCE_BOUNDARY_STATIC=PASS')
print('FPM08B_NO_EXCHANGE_LAW_OR_SOLVER_INTERNALS=PASS')
print('FPM08B_GROUNDWATER_SUMMARY_ONLY_DYNAMIC_HYDRAULIC_INPUT=PASS')
print('FPM08B_WORKER_SCRATCH_STATE_BOUNDARY_STATIC=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_soil_water_solver_contract.f90 -o "$OUT/mod_soil_water_solver_contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_process_hydraulic_view.f90 -o "$OUT/mod_process_hydraulic_view.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_drainage_spatial_distribution.f90 -o "$OUT/mod_drainage_spatial_distribution.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpm/test_fpm08b_drainage_spatial_distribution.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/mod_soil_water_solver_contract.o" "$OUT/mod_process_hydraulic_view.o" \
    "$OUT/mod_drainage_spatial_distribution.o" "$OUT/test.o" -o "$OUT/test_fpm08b"
  "$OUT/test_fpm08b" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }

  for marker in \
    'FPM08B_PRINCIPAL_TRANSMISSIVITY_PARTITION=PASS' \
    'FPM08B_EXACT_SCALAR_TO_NODE_MASS_IDENTITY=PASS' \
    'FPM08B_SPACING_LIMITED_DISCHARGE_LAYER=PASS' \
    'FPM08B_ANISOTROPY_DISCHARGE_DEPTH=PASS' \
    'FPM08B_ZERO_TRANSFER_NO_HYDRAULIC_DEPENDENCY=PASS' \
    'FPM08B_HELD_TRANSFER_DOMAINS_FAIL_CLOSED=PASS' \
    'FPM08B_INVALID_DOMAIN_FAIL_CLOSED=PASS' \
    'FPM08B_STATELESS_A_B_A_IDENTITY=PASS' \
    'FPM08B_SCALAR_AUTHORITY_WORKER_SCRATCH_BOUNDARY=PASS' \
    'FPM08B_DRAINAGE_SPATIAL_DISTRIBUTION_TEST PASS'; do
      grep -Fq "$marker" "$OUT/output.txt"
  done
  echo "FPM08B_CANDIDATE_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FPM08B_CANDIDATE_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FPM08B_CANDIDATE_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FPM08B_DRAINAGE_SPATIAL_DISTRIBUTION_GATE PASS'
