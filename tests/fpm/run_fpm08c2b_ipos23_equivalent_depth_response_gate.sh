#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpm08c2b-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=3e21bffdf8e8c354c336d0b4898fdf77db320bf1
changed_src="$(git diff --name-only "$BASE" -- src)"
expected_src=$'src/process/mod_drainage_hooghoudt_equivalent_depth.f90\nsrc/process/mod_drainage_hooghoudt_ipos23_response.f90'
[[ "$changed_src" == "$expected_src" ]] || {
  echo 'FPM08C2B_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FPM08C2B_PRODUCTION_DELTA_TWO_PROCESS_MODULES=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FPM08C2B_PROTECTED_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}
check_blob src/solver/mod_soil_water_solver_contract.f90 dc7b14a06f64c8ab0af9747f707b3394a5f5cbe0
check_blob src/solver/mod_process_hydraulic_view.f90 d7d85fe71ced0d94b29c8d9395859ae1834f7dd6
check_blob src/solver/mod_b110_source_sink_provider.f90 d6c57add72387e5c0022a44319fff08046194aac

echo 'FPM08C2B_PROTECTED_OWNER_SOURCE_LOCKS=PASS'

python3 - <<'PY'
from pathlib import Path
eq=Path('src/process/mod_drainage_hooghoudt_equivalent_depth.f90').read_text()
r=Path('src/process/mod_drainage_hooghoudt_ipos23_response.f90').read_text()
for text in (eq,r):
    for forbidden in ['HeadCalc','headcalc','open(','read(','write(unit','t1900','AFGEN','SAVE']:
        assert forbidden not in text, forbidden
assert 'immutable_parameter_cache = .true.' in eq
assert 'persistent_process_state = .false.' in eq
assert 'x > EQDEPTH_X_SERIES' in eq
assert 'x < EQDEPTH_X_SHALLOW' in eq
assert 'EQDEPTH_X_SERIES = 0.5_real64' in eq
assert 'EQDEPTH_X_SHALLOW = 1.0e-6_real64' in eq
assert 'exp(' in eq and 'log(' in eq
assert 'prepared%equivalent_depth = min(raw_depth, depth_below_drain)' in eq
assert 'process_hydraulic_view_t' in r
assert 'hydraulic_view%groundwater_level' in r
assert 'DRAIN_IPOS23_B110_DIFFL_CUTOFF = 1.0e-10_real64' in r
assert '8.0_real64 * conductivity_equivalent_depth * prepared%equivalent_depth' in r
assert '4.0_real64 * conductivity_top * abs(difference)' in r
assert 'prepared_equivalent_depth_is_shared_immutable = .true.' in r
assert 'persistent_process_state = .false.' in r
for forbidden in ['zintf','kvtop','kvbot','geofac','surfacewater','pressure_head','water_content']:
    assert forbidden not in r, forbidden
print('FPM08C2B_PREPARED_EQDEPTH_BOUNDARY_STATIC=PASS')
print('FPM08C2B_EQDEPTH_BRANCHES_UNSMOOTHED=PASS')
print('FPM08C2B_DYNAMIC_RESPONSE_GWL_ONLY=PASS')
print('FPM08C2B_SHARED_IMMUTABLE_CACHE_AND_STATELESS_RESPONSE=PASS')
print('FPM08C2B_NO_IO_HEADCALC_OR_IPOS45_LEAKAGE=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_soil_water_solver_contract.f90 -o "$OUT/mod_soil_water_solver_contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_process_hydraulic_view.f90 -o "$OUT/mod_process_hydraulic_view.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_drainage_hooghoudt_equivalent_depth.f90 -o "$OUT/mod_drainage_hooghoudt_equivalent_depth.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_drainage_hooghoudt_ipos23_response.f90 -o "$OUT/mod_drainage_hooghoudt_ipos23_response.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpm/test_fpm08c2b_ipos23_equivalent_depth_response.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/mod_soil_water_solver_contract.o" "$OUT/mod_process_hydraulic_view.o" \
    "$OUT/mod_drainage_hooghoudt_equivalent_depth.o" "$OUT/mod_drainage_hooghoudt_ipos23_response.o" \
    "$OUT/test.o" -o "$OUT/test_fpm08c2b"
  "$OUT/test_fpm08c2b" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }
  for marker in \
    'FPM08C2B_EQDEPTH_SOURCE_EQUATION=PASS' \
    'FPM08C2B_EQDEPTH_IMMUTABLE_CACHE_OWNERSHIP=PASS' \
    'FPM08C2B_EQDEPTH_REPEAT_IDENTITY=PASS' \
    'FPM08C2B_EQDEPTH_X1E6_EFFECTIVELY_CONTINUOUS=PASS' \
    'FPM08C2B_EQDEPTH_X05_FINITE_BRANCH_JUMP=PASS' \
    'FPM08C2B_EQDEPTH_DOMAIN_FAIL_CLOSED=PASS' \
    'FPM08C2B_IPOS2_SOURCE_EQUATION=PASS' \
    'FPM08C2B_IPOS3_SOURCE_EQUATION=PASS' \
    'FPM08C2B_IPOS23_ANALYTIC_TANGENTS_FINITE_DIFFERENCE=PASS' \
    'FPM08C2B_IPOS3_ZERO_BOTTOM_CONDUCTIVITY_ADMISSIBLE=PASS' \
    'FPM08C2B_RESPONSE_DOMAIN_FAIL_CLOSED=PASS' \
    'FPM08C2B_EXACT_CUTOFF_BRANCH_EXPLICIT=PASS' \
    'FPM08C2B_STATELESS_A_B_A_IDENTITY=PASS' \
    'FPM08C2B_STATE_AND_MASS_OWNERSHIP=PASS' \
    'FPM08C2B_IPOS23_EQDEPTH_RESPONSE_TEST PASS'; do
      grep -Fq "$marker" "$OUT/output.txt"
  done
  echo "FPM08C2B_CANDIDATE_O${opt}=PASS"
done
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FPM08C2B_CANDIDATE_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FPM08C2B_CANDIDATE_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FPM08C2B_IPOS23_EQDEPTH_RESPONSE_GATE PASS'
