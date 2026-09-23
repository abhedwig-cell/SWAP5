#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ftab03-provider-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"; trap 'rm -rf "$BUILD"' EXIT
COMMON=(-std=f2018 -ffree-line-length-none -Wall -Wextra -pedantic -fcheck=all -fbacktrace)
run_one(){
  local opt="$1" out="$BUILD/o$1"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c src/solver/mod_soil_water_solver_contract.f90 -o "$out/contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c src/solver/mod_b110_default_mvg_provider.f90 -o "$out/mvg.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c src/solver/mod_b110_generated_mvg_tspack.f90 -o "$out/tspack.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c src/solver/mod_b110_generated_mvg_table_state.f90 -o "$out/state.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c src/solver/mod_b110_generated_mvg_provider.f90 -o "$out/provider.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" tests/fsi/test_ftab03_ksatexm_generated_provider.f90     "$out/contract.o" "$out/mvg.o" "$out/tspack.o" "$out/state.o" "$out/provider.o" -o "$out/test"
  "$out/test" > "$out/output.txt"
}
run_one 0
run_one 2
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o2/output.txt"
echo "F_TAB03_PROVIDER_O0_O2_OUTPUT_IDENTITY=PASS"
echo "F-TAB03 TYPED PROVIDER OWNER GATE PASS"
