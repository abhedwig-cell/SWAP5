#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-/tmp}/fpe-zero-waste01-param-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

gfortran -std=f2008 -ffree-line-length-none -O2 -J"$BUILD" -I"$BUILD"   -c src/solver/mod_soil_water_solver_contract.f90 -o "$BUILD/contract.o"
gfortran -std=f2008 -ffree-line-length-none -O2 -J"$BUILD" -I"$BUILD"   -c src/solver/mod_b110_default_mvg_provider.f90 -o "$BUILD/mvg.o"
gfortran -std=f2008 -ffree-line-length-none -O2 -J"$BUILD" -I"$BUILD"   -c tests/fpe/test_fpe_zero_waste01_parameter_preprocess.f90 -o "$BUILD/test.o"
gfortran -O2 "$BUILD/contract.o" "$BUILD/mvg.o" "$BUILD/test.o" -o "$BUILD/test"

"$BUILD/test" 4 100000
"$BUILD/test" 60 10000
"$BUILD/test" 200 3000
"$BUILD/test" 1000 500
echo 'FPE_ZERO_WASTE01_PARAMETER_PREPROCESS=PASS'
