#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-/tmp}/fpe-h04-component-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -O2)
gfortran "${COMMON[@]}" -J"$BUILD" -I"$BUILD" -c src/solver/mod_soil_water_solver_contract.f90 -o "$BUILD/contract.o"
gfortran "${COMMON[@]}" -J"$BUILD" -I"$BUILD" -c src/solver/mod_b110_default_mvg_provider.f90 -o "$BUILD/provider.o"
gfortran "${COMMON[@]}" -J"$BUILD" -I"$BUILD" -c tests/fpe/test_fpe_zero_waste01_h04_component_cost.f90 -o "$BUILD/test.o"
gfortran -O2 "$BUILD/contract.o" "$BUILD/provider.o" "$BUILD/test.o" -o "$BUILD/test"

"$BUILD/test" 4 100000
"$BUILD/test" 60 10000
"$BUILD/test" 200 3000
"$BUILD/test" 1000 500
echo 'FPE_ZERO_WASTE01_H04_COMPONENT_COST=PASS'
