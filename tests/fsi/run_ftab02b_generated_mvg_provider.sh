#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ftab02b-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
COMMON=(-std=f2018 -ffree-line-length-none -Wall -Wextra -pedantic -fcheck=all -fbacktrace)

compile_and_run() {
  local opt="$1"
  local out="$BUILD/o$opt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c src/solver/mod_soil_water_solver_contract.f90 -o "$out/contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c src/solver/mod_b110_default_mvg_provider.f90 -o "$out/mvg.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c src/solver/mod_b110_generated_mvg_tspack.f90 -o "$out/tspack.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c src/solver/mod_b110_generated_mvg_table_state.f90 -o "$out/state.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c src/solver/mod_b110_generated_mvg_provider.f90 -o "$out/provider.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" \
    tests/fsi/test_ftab02b_generated_mvg_provider.f90 \
    "$out/contract.o" "$out/mvg.o" "$out/tspack.o" "$out/state.o" "$out/provider.o" \
    -o "$out/test_ftab02b"
  "$out/test_ftab02b" tests/fsi/fixtures/ftab02_staring1994_mvg.dat > "$out/output.txt"
}
compile_and_run 0
compile_and_run 2
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o2/output.txt"

git diff --exit-code 79e84c1d2378c86b1d4e0e79b818cce9ffdf1d6e -- src/solver/mod_b110_default_mvg_provider.f90

echo "F_TAB02_B_O0_O2_OUTPUT_IDENTITY=PASS"
echo "F_TAB02_B_ANALYTICAL_PROVIDER_UNCHANGED=PASS"
echo "F-TAB02-B OWNER QUALIFICATION PASS"
