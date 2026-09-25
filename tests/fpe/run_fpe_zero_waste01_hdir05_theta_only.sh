#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-/tmp}/fpe-hdir05-prototype-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -O2 -J"$BUILD" -I"$BUILD"   -c src/solver/mod_soil_water_solver_contract.f90 -o "$BUILD/contract.o"
gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -O2 -J"$BUILD" -I"$BUILD"   -c src/solver/mod_b110_default_mvg_provider.f90 -o "$BUILD/value.o"
gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -O2 -J"$BUILD" -I"$BUILD"   -c src/solver/mod_b110_default_mvg_directional_provider.f90 -o "$BUILD/directional.o"
gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -O2 -J"$BUILD" -I"$BUILD"   -c tests/fpe/test_fpe_zero_waste01_hdir05_theta_only.f90 -o "$BUILD/test.o"
gfortran -O2 "$BUILD/contract.o" "$BUILD/value.o" "$BUILD/directional.o" "$BUILD/test.o" -o "$BUILD/test"
"$BUILD/test"
