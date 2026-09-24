#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-/tmp}/fpe-profile01-constitutive-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

gfortran -std=f2008 -ffree-line-length-none -O2 -J"$BUILD" -I"$BUILD" \
  -c src/solver/mod_soil_water_solver_contract.f90 -o "$BUILD/contract.o"
gfortran -std=f2008 -ffree-line-length-none -O2 -J"$BUILD" -I"$BUILD" \
  -c src/solver/mod_b110_default_mvg_provider.f90 -o "$BUILD/provider.o"
gfortran -std=f2008 -ffree-line-length-none -O2 -J"$BUILD" -I"$BUILD" \
  -c tests/fpe/test_fpe_profile01_constitutive_timing.f90 -o "$BUILD/test.o"
gfortran -O2 "$BUILD/contract.o" "$BUILD/provider.o" "$BUILD/test.o" -o "$BUILD/test"

for spec in '4 1000000' '20 500000' '60 250000' '200 100000' '1000 30000'; do
  read -r nodes calls <<<"$spec"
  "$BUILD/test" "$nodes" "$calls"
done

echo 'PROFILE01_CONSTITUTIVE_MICROBENCHMARK=PASS'
