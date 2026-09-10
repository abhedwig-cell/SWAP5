#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpm08c1-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=3553c63e753bbf714378cd0dff5047769ad3185b
changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "src/process/mod_drainage_tabulated_response.f90" ]] || {
  echo 'FPM08C1_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FPM08C1_PRODUCTION_DELTA_SINGLE_PROCESS_MODULE=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FPM08C1_PROTECTED_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/solver/mod_soil_water_solver_contract.f90 dc7b14a06f64c8ab0af9747f707b3394a5f5cbe0
check_blob src/solver/mod_process_hydraulic_view.f90 d7d85fe71ced0d94b29c8d9395859ae1834f7dd6
check_blob src/solver/mod_b110_source_sink_provider.f90 d6c57add72387e5c0022a44319fff08046194aac

echo 'FPM08C1_PROTECTED_OWNER_SOURCE_LOCKS=PASS'

python3 - <<'PY'
from pathlib import Path
p=Path('src/process/mod_drainage_tabulated_response.f90').read_text()
for forbidden in ['HeadCalc','headcalc','AFGEN','qdrtab','open(','read(','write(unit','t1900','dt','dramet']:
    assert forbidden not in p, forbidden
assert 'process_hydraulic_view_t' in p
assert 'hydraulic_view%groundwater_level' in p
assert 'abs(hydraulic_view%groundwater_level)' in p
assert 'groundwater_depth(:)' in p
assert 'signed_exchange_rate(:)' in p
assert 'signed_soil_to_drain_rate' in p
assert 'dq_dgroundwater_level' in p
assert 'derivative_defined' in p
assert 'at_table_knot' in p
assert 'size(parameters%groundwater_depth)' in p
assert '50' not in p
assert 'SAVE' not in p.upper()
assert 'pressure_head' not in p
assert 'water_content' not in p
print('FPM08C1_NORMALIZED_TABLE_BOUNDARY_STATIC=PASS')
print('FPM08C1_NO_LEGACY_AFGEN_STORAGE_IO_OR_CALENDAR=PASS')
print('FPM08C1_GROUNDWATER_ONLY_HYDRAULIC_INPUT=PASS')
print('FPM08C1_STATELESS_DERIVATIVE_METADATA_STATIC=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_soil_water_solver_contract.f90 -o "$OUT/mod_soil_water_solver_contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_process_hydraulic_view.f90 -o "$OUT/mod_process_hydraulic_view.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_drainage_tabulated_response.f90 -o "$OUT/mod_drainage_tabulated_response.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpm/test_fpm08c1_tabulated_drainage_response.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/mod_soil_water_solver_contract.o" "$OUT/mod_process_hydraulic_view.o" \
    "$OUT/mod_drainage_tabulated_response.o" "$OUT/test.o" -o "$OUT/test_fpm08c1"
  "$OUT/test_fpm08c1" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }

  for marker in \
    'FPM08C1_NEGATIVE_GWL_LINEAR_SEGMENT=PASS' \
    'FPM08C1_LEGACY_ABS_GWL_PARITY=PASS' \
    'FPM08C1_OPEN_SEGMENT_ANALYTIC_DERIVATIVE=PASS' \
    'FPM08C1_UPPER_ENDPOINT_CLAMP=PASS' \
    'FPM08C1_SIGNED_EXCHANGE_AND_LOWER_CLAMP=PASS' \
    'FPM08C1_TABLE_KNOT_DERIVATIVE_UNAVAILABLE=PASS' \
    'FPM08C1_SINGLE_POINT_CONSTANT_TABLE=PASS' \
    'FPM08C1_INVALID_DOMAIN_FAIL_CLOSED=PASS' \
    'FPM08C1_STATELESS_A_B_A_IDENTITY=PASS' \
    'FPM08C1_STATE_AND_MASS_OWNERSHIP=PASS' \
    'FPM08C1_TABULATED_DRAINAGE_RESPONSE_TEST PASS'; do
      grep -Fq "$marker" "$OUT/output.txt"
  done
  echo "FPM08C1_CANDIDATE_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FPM08C1_CANDIDATE_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FPM08C1_CANDIDATE_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FPM08C1_TABULATED_DRAINAGE_RESPONSE_GATE PASS'
