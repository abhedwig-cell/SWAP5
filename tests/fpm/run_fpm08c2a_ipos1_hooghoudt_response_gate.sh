#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpm08c2a-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=3e21bffdf8e8c354c336d0b4898fdf77db320bf1
changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "src/process/mod_drainage_hooghoudt_ipos1_response.f90" ]] || {
  echo 'FPM08C2A_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FPM08C2A_PRODUCTION_DELTA_SINGLE_PROCESS_MODULE=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FPM08C2A_PROTECTED_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/solver/mod_soil_water_solver_contract.f90 dc7b14a06f64c8ab0af9747f707b3394a5f5cbe0
check_blob src/solver/mod_process_hydraulic_view.f90 d7d85fe71ced0d94b29c8d9395859ae1834f7dd6
check_blob src/solver/mod_b110_source_sink_provider.f90 d6c57add72387e5c0022a44319fff08046194aac

echo 'FPM08C2A_PROTECTED_OWNER_SOURCE_LOCKS=PASS'

python3 - <<'PY'
from pathlib import Path
p=Path('src/process/mod_drainage_hooghoudt_ipos1_response.f90').read_text()
for forbidden in ['HeadCalc','headcalc','basegw','dbot','zintf','khbot','kvtop','kvbot','wetper','geofac',
                  'AFGEN','open(','read(','write(unit','t1900','SAVE','pressure_head','water_content']:
    assert forbidden not in p, forbidden
assert 'process_hydraulic_view_t' in p
assert 'hydraulic_view%groundwater_level' in p
assert 'DRAIN_IPOS1_B110_DIFFL_CUTOFF = 1.0e-10_real64' in p
assert 'difference < DRAIN_IPOS1_B110_DIFFL_CUTOFF' in p
assert 'parameters%drain_spacing**2' in p
assert '4.0_real64 * parameters%horizontal_conductivity_top * abs(difference)' in p
assert 'signed_soil_to_drain_rate = difference / total_resistance' in p
assert 'dq_dgroundwater_level' in p
assert 'at_exact_compatibility_cutoff' in p
assert 'persistent_process_state = .false.' in p
print('FPM08C2A_NORMALIZED_IPOS1_BOUNDARY_STATIC=PASS')
print('FPM08C2A_EXACT_B110_CUTOFF_VISIBLE=PASS')
print('FPM08C2A_NO_UNUSED_LEGACY_GEOMETRY_OR_IO=PASS')
print('FPM08C2A_STATELESS_DERIVATIVE_METADATA_STATIC=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_soil_water_solver_contract.f90 -o "$OUT/mod_soil_water_solver_contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_process_hydraulic_view.f90 -o "$OUT/mod_process_hydraulic_view.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_drainage_hooghoudt_ipos1_response.f90 -o "$OUT/mod_drainage_hooghoudt_ipos1_response.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpm/test_fpm08c2a_ipos1_hooghoudt_response.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/mod_soil_water_solver_contract.o" "$OUT/mod_process_hydraulic_view.o" \
    "$OUT/mod_drainage_hooghoudt_ipos1_response.o" "$OUT/test.o" -o "$OUT/test_fpm08c2a"
  "$OUT/test_fpm08c2a" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }

  for marker in \
    'FPM08C2A_ACTIVE_SOURCE_EQUATION=PASS' \
    'FPM08C2A_ANALYTIC_TANGENT_FINITE_DIFFERENCE=PASS' \
    'FPM08C2A_INACTIVE_COMPATIBILITY_BRANCH=PASS' \
    'FPM08C2A_EXACT_CUTOFF_FLUX_PARITY_TANGENT_HELD=PASS' \
    'FPM08C2A_CUTOFF_SIDEDNESS_EXPLICIT=PASS' \
    'FPM08C2A_NORMALIZED_DOMAIN_FAIL_CLOSED=PASS' \
    'FPM08C2A_STATELESS_A_B_A_IDENTITY=PASS' \
    'FPM08C2A_STATE_AND_MASS_OWNERSHIP=PASS' \
    'FPM08C2A_IPOS1_HOOGHOUDT_RESPONSE_TEST PASS'; do
      grep -Fq "$marker" "$OUT/output.txt"
  done
  echo "FPM08C2A_CANDIDATE_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FPM08C2A_CANDIDATE_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FPM08C2A_CANDIDATE_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FPM08C2A_IPOS1_HOOGHOUDT_RESPONSE_GATE PASS'
