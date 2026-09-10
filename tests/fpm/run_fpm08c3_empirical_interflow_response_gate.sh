#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpm08c3-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=3553c63e753bbf714378cd0dff5047769ad3185b
changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "src/process/mod_drainage_empirical_interflow_response.f90" ]] || {
  echo 'FPM08C3_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FPM08C3_PRODUCTION_DELTA_SINGLE_PROCESS_MODULE=PASS'

changed_ref="$(git diff --name-only "$BASE" -- reference)"
[[ -z "$changed_ref" ]] || {
  echo 'FPM08C3_REFERENCE_DELTA_NONE=FAIL' >&2
  printf '%s\n' "$changed_ref" >&2
  exit 1
}
echo 'FPM08C3_REFERENCE_DELTA_NONE=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FPM08C3_PROTECTED_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}
check_blob src/solver/mod_soil_water_solver_contract.f90 dc7b14a06f64c8ab0af9747f707b3394a5f5cbe0
check_blob src/solver/mod_process_hydraulic_view.f90 d7d85fe71ced0d94b29c8d9395859ae1834f7dd6
check_blob src/solver/mod_b110_source_sink_provider.f90 d6c57add72387e5c0022a44319fff08046194aac

echo 'FPM08C3_PROTECTED_OWNER_SOURCE_LOCKS=PASS'

python3 - <<'PY'
from pathlib import Path
p=Path('src/process/mod_drainage_empirical_interflow_response.f90').read_text()
low=p.lower()
for forbidden in ['headcalc','open(','read(','write(unit','.dra','owltab','t1900','jacobian','epsilon','tolerance','smooth','clip','cap_tangent']:
    assert forbidden not in low, forbidden
for required in ['empirical_interflow_parameters_t','empirical_interflow_control_t','process_hydraulic_view_t',
                 'coefficient','exponent','drain_head','hydraulic_view%groundwater_level',
                 'signed_soil_to_drain_rate','dq_dgroundwater_level','derivative_defined',
                 'singular_activation_tangent','drainage_side_activation_tangent_defined',
                 'negative_side_exchange_out_of_scope','persistent_process_state',
                 'process_side_tangent_regularization']:
    assert required in low, required
assert 'save' not in p.upper()
assert 'difference**parameters%exponent' in low
assert 'difference**(parameters%exponent - 1.0_real64)' in low
print('FPM08C3_PARAMETER_CONTROL_HYDRAULIC_SEPARATION_STATIC=PASS')
print('FPM08C3_NO_IO_HEADCALC_OR_SOLVER_MUTATION=PASS')
print('FPM08C3_NO_PROCESS_SIDE_TANGENT_REGULARIZATION=PASS')
print('FPM08C3_STATELESS_MASS_SCOPE_STATIC=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror=compare-reals -fcheck=all -fbacktrace)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_soil_water_solver_contract.f90 -o "$OUT/mod_soil_water_solver_contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_process_hydraulic_view.f90 -o "$OUT/mod_process_hydraulic_view.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_drainage_empirical_interflow_response.f90 -o "$OUT/mod_drainage_empirical_interflow_response.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpm/test_fpm08c3_empirical_interflow_response.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/mod_soil_water_solver_contract.o" "$OUT/mod_process_hydraulic_view.o" \
    "$OUT/mod_drainage_empirical_interflow_response.o" "$OUT/test.o" -o "$OUT/test_fpm08c3"
  "$OUT/test_fpm08c3" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }

  for marker in \
    'FPM08C3_ACTIVE_LEGACY_POWER_RESPONSE=PASS' \
    'FPM08C3_ANALYTIC_TANGENT_FINITE_DIFFERENCE=PASS' \
    'FPM08C3_NEGATIVE_SIDE_INTERFLOW_CONTRIBUTION_INACTIVE=PASS' \
    'FPM08C3_SUBLINEAR_ACTIVATION_SINGULAR_TANGENT=PASS' \
    'FPM08C3_LINEAR_ACTIVATION_ONE_SIDED_TANGENT_DIAGNOSTIC=PASS' \
    'FPM08C3_EXPONENT_ONE_ACTIVE_BRANCH=PASS' \
    'FPM08C3_NO_PROCESS_SIDE_NEAR_ACTIVATION_CAP=PASS' \
    'FPM08C3_PARAMETER_BOUND_RESPONSE=PASS' \
    'FPM08C3_INVALID_AND_NUMERICAL_DOMAIN_FAIL_CLOSED=PASS' \
    'FPM08C3_STATELESS_A_B_A_IDENTITY=PASS' \
    'FPM08C3_STATE_MASS_AND_SCOPE_OWNERSHIP=PASS' \
    'FPM08C3_EMPIRICAL_INTERFLOW_RESPONSE_TEST PASS'; do
    grep -Fq "$marker" "$OUT/output.txt"
  done
  echo "FPM08C3_CANDIDATE_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FPM08C3_CANDIDATE_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FPM08C3_CANDIDATE_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FPM08C3_EMPIRICAL_INTERFLOW_RESPONSE_GATE PASS'
