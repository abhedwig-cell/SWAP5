#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpm06a-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=2113dd20c2f20c77c3191c65be2f994955202037
changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "src/process/mod_reference_et_demand_process.f90" ]] || {
  echo "FPM06A_UNEXPECTED_PRODUCTION_DELTA" >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FPM06A_PRODUCTION_DELTA_SINGLE_PROCESS_MODULE=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FPM06A_PROTECTED_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/process/mod_root_water_uptake_process.f90 e6134587cf3c0164bbe09f2f4c87aef6886aaeb3
check_blob src/crop/mod_wofost_crop_owner_state.f90 31bb390a0b70bec0a3f525f1d704a2c53890f9b4
echo 'FPM06A_PROTECTED_OWNER_SOURCE_LOCKS=PASS'

python3 - <<'PY'
from pathlib import Path
p = Path('src/process/mod_reference_et_demand_process.f90').read_text()
for forbidden in [
    'HeadCalc', 'headcalc', 'mod_process_hydraulic_view',
    'mod_root_water_uptake_process', 'MOD_rootextraction',
    'open(', 'read(', 'write(', 't1900', 'flday', 'jacobian', 'newton'
]:
    assert forbidden not in p, forbidden
assert 'reference_et_mm_per_day' in p
assert 'vegetation_cover_fraction' in p
assert 'pond_evaporation_factor' in p
assert 'potential_transpiration_cm_per_day' in p
assert 'potential_soil_evaporation_cm_per_day' in p
assert 'potential_pond_evaporation_cm_per_day' in p
assert 'uncovered_reference_et_mm_per_day * 0.1_real64' in p
assert 'parameters%pond_evaporation_factor * 0.1_real64' in p
assert 'canopy%vegetation_cover_fraction * canopy%crop_factor' in p
assert 'canopy%co2_transpiration_factor' in p
assert 'type, public :: reference_et_demand_result_t' in p
assert 'allocatable' not in p.lower()
assert 'save' not in p.lower()
print('FPM06A_PROCESS_BOUNDARY_STATIC=PASS')
print('FPM06A_NO_HYDRAULIC_OR_ROOT_UPTAKE_INTERNALS=PASS')
print('FPM06A_NO_PERSISTENT_PROCESS_STATE=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/process/mod_reference_et_demand_process.f90 -o "$OUT/mod_reference_et_demand_process.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/fpm/test_fpm06a_reference_et_demand.f90 -o "$OUT/test_fpm06a_reference_et_demand.o"
  gfortran -O"$opt" "$OUT/mod_reference_et_demand_process.o" "$OUT/test_fpm06a_reference_et_demand.o" \
    -o "$OUT/test_fpm06a_reference_et_demand"
  "$OUT/test_fpm06a_reference_et_demand" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    exit 1
  }

  for marker in \
    'FPM06A_B110_REFERENCE_ET_EQUATIONS=PASS' \
    'FPM06A_SURFACE_DEMAND_VCOVER_SEMANTICS=PASS' \
    'FPM06A_INACTIVE_CROP_DEPENDENCY_MINIMAL=PASS' \
    'FPM06A_BOUNDARY_CASES=PASS' \
    'FPM06A_FAIL_CLOSED_INVALID_INPUT=PASS' \
    'FPM06A_STATELESS_A_B_A_IDENTITY=PASS' \
    'FPM06A_REFERENCE_ET_DEMAND_TEST PASS'; do
      grep -Fq "$marker" "$OUT/output.txt"
  done
  echo "FPM06A_CANDIDATE_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FPM06A_CANDIDATE_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FPM06A_CANDIDATE_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FPM06A_REFERENCE_ET_DEMAND_CANDIDATE_GATE PASS'
