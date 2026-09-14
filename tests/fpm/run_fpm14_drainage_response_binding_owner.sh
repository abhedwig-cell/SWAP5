#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpm14-drainage-binding-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SOURCES=(
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/process/mod_drainage_process.f90
  src/process/mod_drainage_tabulated_response.f90
  src/process/mod_drainage_hooghoudt_equivalent_depth.f90
  src/process/mod_drainage_hooghoudt_ipos1_response.f90
  src/process/mod_drainage_hooghoudt_ipos23_response.f90
  src/process/mod_drainage_ernst_ipos45_preparation.f90
  src/process/mod_drainage_ernst_ipos45_response.f90
  src/process/mod_drainage_empirical_interflow_response.f90
  src/process/mod_drainage_multilevel_aggregation.f90
  src/runtime/mod_fmr_drainage_response_binding.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for source in "${SOURCES[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpm/test_fpm14_drainage_response_binding.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  if ! "$OUT/test" > "$OUT/output.txt" 2>&1; then
    echo "FPM14_DRAINAGE_RESPONSE_BINDING_O${opt}=FAIL" >&2
    cat "$OUT/output.txt" >&2
    exit 1
  fi
  grep -Fq 'FPM14_ALL_RESPONSE_FAMILIES_BOTTOM_LUMPED=PASS' "$OUT/output.txt"
  grep -Fq 'FPM14_MULTILEVEL_DERIVED_TOTAL_SINGLE_BOOKING=PASS' "$OUT/output.txt"
  grep -Fq 'FPM14_UNSUPPORTED_VARIANT_FAIL_CLOSED=PASS' "$OUT/output.txt"
  grep -Fq 'FPM14_DRAINAGE_RESPONSE_BINDING_OWNER_TEST PASS' "$OUT/output.txt"
  echo "FPM14_DRAINAGE_RESPONSE_BINDING_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  exit 87
}
echo 'FPM14_DRAINAGE_RESPONSE_BINDING_O0_O2_EXACT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
