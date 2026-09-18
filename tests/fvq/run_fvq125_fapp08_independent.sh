#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fvq125-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_VQ125_FAIL $*" >&2; exit 1; }

SUBJECT=3000730b402eb17726b6bdcb1f9f63adb9f6b68a
BIND=src/runtime/mod_fmr_rutter_output_application_binding.f90
[[ "$(git rev-parse HEAD:$BIND)" == "$(git rev-parse "$SUBJECT:$BIND")" ]] || fail "candidate binding drift"
[[ -z "$(git diff --name-only "$SUBJECT"..HEAD -- src)" ]] || fail "qualification mutated production source"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  gfortran "${COMMON[@]}" -Wno-error=unused-dummy-argument -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_soil_water_solver_contract.f90 -o "$OUT/swcontract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_b110_default_mvg_provider.f90 -o "$OUT/mvg.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_restricted_surface_evaporation.f90 -o "$OUT/evap.o"
  gfortran "${COMMON[@]}" -Wno-error=compare-reals -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_b110_dynamic_top_boundary_provider.f90 -o "$OUT/dyntop.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/crop/mod_crop_root_uptake_input_contract.f90 -o "$OUT/root.o"
  gfortran "${COMMON[@]}" -Werror -pedantic-errors -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_rutter_interception_process.f90 -o "$OUT/rutter.o"
  gfortran "${COMMON[@]}" -Werror -pedantic-errors -O"$opt" -J "$OUT" -I "$OUT" -c "$BIND" -o "$OUT/bind.o"
  gfortran "${COMMON[@]}" -Wno-error=compare-reals -O"$opt" -J "$OUT" -I "$OUT" -c tests/fvq/test_fvq125_fapp08_independent.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/swcontract.o" "$OUT/mvg.o" "$OUT/evap.o" "$OUT/dyntop.o" "$OUT/root.o" "$OUT/rutter.o" "$OUT/bind.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "runtime O$opt"; }
  for m in F_VQ125_SURFACE_SWEEP=PASS F_VQ125_ROOT_SWEEP=PASS F_VQ125_INACTIVE_CROP_ZERO=PASS F_VQ125_FAIL_CLOSED=PASS; do
    grep -Fq "$m" "$OUT/output.txt" || fail "missing marker $m"
  done
done
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || { diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true; fail "O0/O2 drift"; }
cat "$BUILD/o0/output.txt"
echo "F_VQ125_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'F_VQ125_FAPP08_INDEPENDENT=PASS'
