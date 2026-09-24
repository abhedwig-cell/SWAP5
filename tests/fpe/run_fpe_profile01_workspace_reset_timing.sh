#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-/tmp}/fpe-profile01-reset-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

gfortran -std=f2008 -ffree-line-length-none -O2 -J"$BUILD" -I"$BUILD" \
  -c src/solver/mod_soil_water_solver_contract.f90 -o "$BUILD/contract.o"
gfortran -std=f2008 -ffree-line-length-none -O2 -J"$BUILD" -I"$BUILD" \
  -c src/solver/mod_reference_richards_workspace.f90 -o "$BUILD/workspace.o"
gfortran -std=f2008 -ffree-line-length-none -O2 -J"$BUILD" -I"$BUILD" \
  -c tests/fpe/test_fpe_profile01_workspace_reset_timing.f90 -o "$BUILD/test.o"
gfortran -O2 "$BUILD/contract.o" "$BUILD/workspace.o" "$BUILD/test.o" -o "$BUILD/test"

for spec in '4 1000000' '20 500000' '60 250000' '200 100000' '1000 30000'; do
  read -r nodes calls <<<"$spec"
  "$BUILD/test" "$nodes" "$calls"
done

echo 'PROFILE01_RESET_MICROBENCHMARK=PASS'
