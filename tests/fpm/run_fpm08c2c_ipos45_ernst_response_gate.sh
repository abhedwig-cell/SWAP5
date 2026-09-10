#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpm08c2c-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=3e21bffdf8e8c354c336d0b4898fdf77db320bf1
changed_src="$(git diff --name-only "$BASE" -- src)"
expected_src=$'src/process/mod_drainage_ernst_ipos45_preparation.f90\nsrc/process/mod_drainage_ernst_ipos45_response.f90'
[[ "$changed_src" == "$expected_src" ]] || {
  echo 'FPM08C2C_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FPM08C2C_PRODUCTION_DELTA_TWO_PROCESS_MODULES=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FPM08C2C_PROTECTED_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}
check_blob src/solver/mod_soil_water_solver_contract.f90 dc7b14a06f64c8ab0af9747f707b3394a5f5cbe0
check_blob src/solver/mod_process_hydraulic_view.f90 d7d85fe71ced0d94b29c8d9395859ae1834f7dd6
check_blob src/solver/mod_b110_source_sink_provider.f90 d6c57add72387e5c0022a44319fff08046194aac

echo 'FPM08C2C_PROTECTED_OWNER_SOURCE_LOCKS=PASS'

python3 - <<'PY'
from pathlib import Path
p=Path('src/process/mod_drainage_ernst_ipos45_preparation.f90').read_text()
r=Path('src/process/mod_drainage_ernst_ipos45_response.f90').read_text()
for text in (p,r):
    for forbidden in ['HeadCalc','headcalc','open(','read(','write(unit','AFGEN','surfacewater','SAVE']:
        assert forbidden not in text, forbidden
assert 'immutable_parameter_cache = .true.' in p
assert 'persistent_process_state = .false.' in p
assert 'radial_resistance_negative = rrad < 0.0_real64' in p
assert 'log(depth_below_drain / geometry%wetted_perimeter)' in p
assert 'log(logarg)' in p
assert 'vertical_conductivity_bottom' not in p.split('type, public :: ernst_ipos5_geometry_t',1)[1].split('end type ernst_ipos5_geometry_t',1)[0]
assert 'process_hydraulic_view_t' in r
assert 'hydraulic_view%groundwater_level' in r
assert 'DRAIN_ERNST_B110_DIFFL_CUTOFF = 1.0e-10_real64' in r
assert 'gwl > prepared%interface_level' in r
assert 'prepared%vertical_conductivity_top /= prepared%vertical_conductivity_bottom' in r
assert 'total_resistance > 0.0_real64' in r
assert 'prepared_geometry_is_shared_immutable = .true.' in r
assert 'mass_is_authoritative_external_transfer = .true.' in r
assert 'persistent_process_state = .false.' in r
for forbidden in ['pressure_head','water_content','ponding_depth','MODFLOW','.dra','calendar']:
    assert forbidden not in r, forbidden
print('FPM08C2C_PREPARED_GEOMETRY_BOUNDARY_STATIC=PASS')
print('FPM08C2C_IPOS5_UNUSED_KVBOT_OMITTED=PASS')
print('FPM08C2C_NEGATIVE_RRAD_POLICY_STATIC=PASS')
print('FPM08C2C_DYNAMIC_RESPONSE_GWL_ONLY=PASS')
print('FPM08C2C_IPOS4_KINK_UNSMOOTHED=PASS')
print('FPM08C2C_STATELESS_MASS_OWNERSHIP_STATIC=PASS')
print('FPM08C2C_NO_IO_HEADCALC_RUNTIME_LEAKAGE=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_soil_water_solver_contract.f90 -o "$OUT/mod_soil_water_solver_contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_process_hydraulic_view.f90 -o "$OUT/mod_process_hydraulic_view.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_drainage_ernst_ipos45_preparation.f90 -o "$OUT/mod_drainage_ernst_ipos45_preparation.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_drainage_ernst_ipos45_response.f90 -o "$OUT/mod_drainage_ernst_ipos45_response.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpm/test_fpm08c2c_ipos45_ernst_response.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/mod_soil_water_solver_contract.o" "$OUT/mod_process_hydraulic_view.o" \
    "$OUT/mod_drainage_ernst_ipos45_preparation.o" "$OUT/mod_drainage_ernst_ipos45_response.o" "$OUT/test.o" -o "$OUT/test_fpm08c2c"
  "$OUT/test_fpm08c2c" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }
  for marker in \
    'FPM08C2C_IPOS4_SOURCE_EQUATION=PASS' \
    'FPM08C2C_IPOS5_SOURCE_EQUATION=PASS' \
    'FPM08C2C_IPOS4_STABLE_BRANCH_TANGENTS_FD=PASS' \
    'FPM08C2C_IPOS5_TANGENT_FD=PASS' \
    'FPM08C2C_IPOS4_INTERFACE_KINK_EXPLICIT=PASS' \
    'FPM08C2C_NEGATIVE_RADIAL_RESISTANCE_ADMISSIBLE=PASS' \
    'FPM08C2C_POSITIVE_TOTAL_RESISTANCE_FAIL_CLOSED=PASS' \
    'FPM08C2C_EXACT_B110_CUTOFF_BRANCH_EXPLICIT=PASS' \
    'FPM08C2C_STATELESS_A_B_A_IDENTITY=PASS' \
    'FPM08C2C_STATE_AND_MASS_OWNERSHIP=PASS' \
    'FPM08C2C_IPOS45_ERNST_RESPONSE_TEST PASS'; do
      grep -Fq "$marker" "$OUT/output.txt"
  done
  echo "FPM08C2C_CANDIDATE_O${opt}=PASS"
done
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FPM08C2C_CANDIDATE_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FPM08C2C_CANDIDATE_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FPM08C2C_IPOS45_ERNST_RESPONSE_GATE PASS'
