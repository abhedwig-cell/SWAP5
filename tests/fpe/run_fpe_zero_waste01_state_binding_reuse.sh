#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-/tmp}/fpe-zero-waste01-state-binding-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

gfortran -std=f2008 -ffree-line-length-none -O2 -J"$BUILD" -I"$BUILD"   -c src/solver/mod_soil_water_solver_contract.f90 -o "$BUILD/contract.o"
gfortran -std=f2008 -ffree-line-length-none -O2 -J"$BUILD" -I"$BUILD"   -c src/solver/mod_reference_richards_state_binding.f90 -o "$BUILD/binding.o"
gfortran -std=f2008 -ffree-line-length-none -O2 -J"$BUILD" -I"$BUILD"   -c tests/fpe/test_fpe_zero_waste01_state_binding_reuse.f90 -o "$BUILD/test.o"
gfortran -O2 "$BUILD/contract.o" "$BUILD/binding.o" "$BUILD/test.o" -o "$BUILD/test"

"$BUILD/test" 60 100000
"$BUILD/test" 200 30000
"$BUILD/test" 1000 5000
