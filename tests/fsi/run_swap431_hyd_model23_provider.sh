#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap431-hyd-model23-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
for opt in 0 2; do
  gfortran -std=f2018 -ffree-line-length-none -O"$opt" \
    -J"$BUILD" -I"$BUILD" \
    "$ROOT/src/solver/mod_soil_water_solver_contract.f90" \
    "$ROOT/src/solver/mod_b111_legacy_hydraulic_provider.f90" \
    "$ROOT/tests/fsi/test_swap431_hyd_model23_provider.f90" \
    -o "$BUILD/test-model23-o$opt"
  "$BUILD/test-model23-o$opt"
done
