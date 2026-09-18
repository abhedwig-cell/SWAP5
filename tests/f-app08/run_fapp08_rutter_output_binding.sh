#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fapp08-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_APP08_FAIL $*" >&2; exit 1; }

BASE=b1f23b069f733f1d711699b9d3cd4b8acaec968b
expected_src='src/runtime/mod_fmr_rutter_output_application_binding.f90'
[[ "$(git diff --name-only "$BASE" -- src | sort)" == "$expected_src" ]] || fail "unexpected production delta"
[[ "$(git hash-object src/process/mod_rutter_interception_process.f90)" == fd6ba136e02c13add1933ca6d63f25b2e7c5d822 ]] || fail "Rutter owner drift"

python3 - <<'PY'
from pathlib import Path
p=Path('src/runtime/mod_fmr_rutter_output_application_binding.f90').read_text()
low=p.lower()
for forbidden in ['mod_kernel_transactions','headcalc','newton','jacobian','open(','read(']:
    assert forbidden not in low, forbidden
for required in [
    'bound_request%precipitation_rate_cm_per_day = net_rain',
    'bound_request%irrigation_rate_cm_per_day = net_irrigation',
    'bound_input%potential_transpiration = ptra',
    'validate_crop_root_uptake_input'
]:
    assert required in p, required
print('F_APP08_STATIC_TRANSPARENT_MAPPING=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  gfortran "${COMMON[@]}" -Wno-error=unused-dummy-argument -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_soil_water_solver_contract.f90 -o "$OUT/swcontract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_b110_default_mvg_provider.f90 -o "$OUT/mvg.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_restricted_surface_evaporation.f90 -o "$OUT/evap.o"
  gfortran "${COMMON[@]}" -Wno-error=compare-reals -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_b110_dynamic_top_boundary_provider.f90 -o "$OUT/dyntop.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/crop/mod_crop_root_uptake_input_contract.f90 -o "$OUT/root.o"
  gfortran "${COMMON[@]}" -Werror -pedantic-errors -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_rutter_interception_process.f90 -o "$OUT/rutter.o"
  gfortran "${COMMON[@]}" -Werror -pedantic-errors -O"$opt" -J "$OUT" -I "$OUT" -c src/runtime/mod_fmr_rutter_output_application_binding.f90 -o "$OUT/bind.o"
  gfortran "${COMMON[@]}" -Wno-error=compare-reals -O"$opt" -J "$OUT" -I "$OUT" -c tests/f-app08/test_rutter_output_binding.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/swcontract.o" "$OUT/mvg.o" "$OUT/evap.o" "$OUT/dyntop.o" "$OUT/root.o" "$OUT/rutter.o" "$OUT/bind.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "runtime O$opt"; }
  for m in F_APP08_FROZEN_B111_VECTORS=PASS F_APP08_RUTTER_SURFACE_FLUX_BINDING=PASS F_APP08_RUTTER_PTRA_ROOT_BINDING=PASS F_APP08_FAIL_CLOSED=PASS; do
    grep -Fq "$m" "$OUT/output.txt" || fail "missing O$opt marker $m"
  done
done
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || { diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true; fail "O0/O2 drift"; }
cat "$BUILD/o0/output.txt"
echo "F_APP08_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'F_APP08_OWNER_QUALIFICATION=PASS'
