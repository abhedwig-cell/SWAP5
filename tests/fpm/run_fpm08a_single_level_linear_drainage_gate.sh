#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpm08a-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=3ce245e3cac068268bdff2f0af0fdcdf022c82aa
changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "src/process/mod_drainage_process.f90" ]] || {
  echo "FPM08A_UNEXPECTED_PRODUCTION_DELTA" >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
[[ -z "$(git diff --name-only "$BASE" -- reference)" ]] || {
  echo "FPM08A_REFERENCE_CHANGED" >&2
  exit 1
}
echo 'FPM08A_PRODUCTION_DELTA_SINGLE_PROCESS_MODULE=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FPM08A_PROTECTED_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob integration/f-pm/F-PM08_READINESS_CONTRACT.json d52e916e8236aa4c0125189d223127f6718b749c
check_blob src/solver/mod_soil_water_solver_contract.f90 dc7b14a06f64c8ab0af9747f707b3394a5f5cbe0
check_blob src/solver/mod_b110_source_sink_provider.f90 d6c57add72387e5c0022a44319fff08046194aac
check_blob src/solver/mod_process_hydraulic_view.f90 d7d85fe71ced0d94b29c8d9395859ae1834f7dd6
check_blob src/runtime/mod_fmr_process_hydraulic_view_binding.f90 37f5968ffe00b1ff56f824f77ab94d3825171acf
echo 'FPM08A_PROTECTED_OWNER_SOURCE_LOCKS=PASS'

python3 - <<'PY'
import json
from pathlib import Path

contract=json.loads(Path('integration/f-pm/F-PM08A_CANDIDATE_CONTRACT.json').read_text())
assert contract['lineage']['readiness_closeout']=='3ce245e3cac068268bdff2f0af0fdcdf022c82aa'
assert contract['legacy_authority']['restricted_switch_identity']=={
    'SWDRA':1,'DRAMET':3,'NRLEVS':1,'SWALLO':3,'SWINTFL':0,'SWDIVD':0
}
assert contract['physics']['law']=='q=max(0,(groundwater_level-drain_head)/drainage_resistance)'
assert contract['mass_contract']['process_mutates_committed_state'] is False
assert contract['mass_contract']['process_books_mass_ledger'] is False
assert contract['mass_contract']['returned_soil_to_drain_rate_is_single_authoritative_physical_transfer'] is True
assert contract['solver_contract']['headcalc_internal_access'] is False
assert contract['solver_contract']['solver_jacobian_mutation'] is False
assert contract['solver_contract']['fully_implicit_trial_state_drainage_admitted'] is False
assert contract['solver_contract']['node_distribution_admitted'] is False
assert contract['time_contract']['fundamental_day_assumption'] is False
assert contract['time_contract']['calendar_table_interpolation_inside_process'] is False
holds='\n'.join(contract['hard_holds'])
for required in ['reverse drainage infiltration','DRAMET=1','DRAMET=2','NRLEVS>1','power interflow','DIVDRA','surface-water','macropore','solute','fully implicit','solver Jacobian']:
    assert required.lower() in holds.lower(), required

p=Path('src/process/mod_drainage_process.f90').read_text()
for forbidden in ['HeadCalc','headcalc','MOD_drain','MOD_drainage','divdra','AFGEN','afgen','t1900','fldaystart','open(', 'read(', 'write(unit']:
    assert forbidden not in p, forbidden
for required in [
    'use mod_process_hydraulic_view, only: process_hydraulic_view_t',
    'hydraulic_view%groundwater_level - control%drain_head',
    'transfer%soil_to_drain_rate = diffl / parameters%drainage_resistance',
    'transfer%dq_dgroundwater_level = 1.0_real64 / parameters%drainage_resistance',
    'transfer%derivative_defined = .false.',
    'diagnostics%activation_kink = .true.'
]:
    assert required in p, required
assert 'hydraulic_view%pressure_head' not in p
assert 'hydraulic_view%water_content' not in p
assert 'step_duration' not in p
assert 't0' not in p and 't1' not in p
print('FPM08A_SOURCE_BOUNDARY_STATIC=PASS')
print('FPM08A_ONLY_GROUNDWATER_SUMMARY_CONSUMED=PASS')
print('FPM08A_NO_CALENDAR_IO_OR_SOLVER_INTERNALS=PASS')
print('FPM08A_HARD_HOLDS_STATIC=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/process/mod_drainage_process.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done

  test=tests/fpm/test_fpm08a_single_level_linear_drainage.f90
  name="$(basename "${test%.*}")"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$test" -o "$OUT/$name.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/$name.o" -o "$OUT/$name"
  "$OUT/$name" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }

  for marker in \
    'FPM08A_ACTIVE_LINEAR_DRAINAGE_LAW=PASS' \
    'FPM08A_GROUNDWATER_ONLY_HYDRAULIC_VIEW=PASS' \
    'FPM08A_DRAINAGE_ONLY_NO_REVERSE_EXCHANGE=PASS' \
    'FPM08A_NONSMOOTH_ACTIVATION_DIAGNOSTIC=PASS' \
    'FPM08A_ACTIVE_DERIVATIVE_FINITE_DIFFERENCE=PASS' \
    'FPM08A_INACTIVE_DERIVATIVE_FINITE_DIFFERENCE=PASS' \
    'FPM08A_STATELESS_A_B_A_IDENTITY=PASS' \
    'FPM08A_INVALID_DOMAIN_FAIL_CLOSED=PASS' \
    'FPM08A_AUTHORITATIVE_TRANSFER_SIGN_AND_RATE=PASS' \
    'FPM08A_SINGLE_LEVEL_LINEAR_DRAINAGE_TEST PASS'; do
      grep -Fq "$marker" "$OUT/output.txt"
  done
  echo "FPM08A_CANDIDATE_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FPM08A_CANDIDATE_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FPM08A_CANDIDATE_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FPM08A_SINGLE_LEVEL_LINEAR_DRAINAGE_CANDIDATE_GATE PASS'
