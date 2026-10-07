#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-mc-irr01-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "MC_IRR01_FAIL $*" >&2; exit 1; }

test "$(git hash-object src/process/mod_irrigation_process.f90)" = c0755c1e0d0b7ca1a35e73cf26158c29e9940aec || fail "F-VQ20 process blob drift"
grep -Fq 'real(real64), allocatable :: subsurface_irrigation_source(:)' src/runtime/mod_fmr_serialized_reference_backend.f90 || fail "missing real FMR SSDI carrier"
grep -Fq 'fmr_build_committed_process_hydraulic_view' src/runtime/mod_fmr_scheduled_irrigation_runtime_binding.f90 || fail "binding does not use committed hydraulic view"
grep -Fq 'evaluate_scheduled_irrigation_interval' src/runtime/mod_fmr_scheduled_irrigation_runtime_binding.f90 || fail "binding does not invoke qualified process"
grep -Fq 'subsurface_irrigation_source' src/runtime/mod_fmr_scheduled_irrigation_runtime_binding.f90 || fail "binding does not route SSDI source"

COMMON=(-std=f2008 -pedantic-errors -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_soil_water_solver_contract.f90 -o "$OUT/solver_contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_process_hydraulic_view.f90 -o "$OUT/hyd_view.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_irrigation_process.f90 -o "$OUT/irrigation.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/mc-irr01/mc_irr01_binding_stubs.f90 -o "$OUT/stubs.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/runtime/mod_fmr_scheduled_irrigation_runtime_binding.f90 -o "$OUT/binding.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/mc-irr01/test_mc_irr01_tcs7_ssdi_binding_unit.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/solver_contract.o" "$OUT/hyd_view.o" "$OUT/irrigation.o" "$OUT/stubs.o" "$OUT/binding.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "runtime O$opt"; }
  grep -Fq 'MC_IRR01_TCS7_SSDI_BINDING_UNIT=PASS' "$OUT/output.txt" || fail "missing binding marker O$opt"
  echo "MC_IRR01_TCS7_SSDI_O${opt}=PASS"
done
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || fail "O0/O2 output drift"
cat "$BUILD/o0/output.txt"
echo "MC_IRR01_TCS7_SSDI_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'MC_IRR01_TCS7_SSDI_RUNTIME_BINDING=PASS'
