#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/tabhyd-ksatexm-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
COMMON=(-std=f2018 -ffree-line-length-none -Wall -Wextra -pedantic -fcheck=all -fbacktrace)
run_one(){
  local opt="$1"; local out="$BUILD/o$opt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c src/solver/mod_soil_water_solver_contract.f90 -o "$out/contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c src/solver/mod_b110_default_mvg_provider.f90 -o "$out/mvg.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c src/solver/mod_b110_generated_mvg_tspack.f90 -o "$out/tspack.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c src/solver/mod_b110_generated_mvg_table_state.f90 -o "$out/state.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c src/solver/mod_b110_generated_mvg_provider.f90 -o "$out/provider.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out"     research/tabulated_hydraulics/test_ksatexm_lower_layer.f90     "$out/contract.o" "$out/mvg.o" "$out/tspack.o" "$out/state.o" "$out/provider.o"     -o "$out/test"
  "$out/test" > "$out/output.txt"
}
run_one 0
run_one 2
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o2/output.txt"
echo 'TABHYD_KSATEXM_O0_O2_IDENTITY=PASS'
