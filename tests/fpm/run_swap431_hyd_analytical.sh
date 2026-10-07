#!/usr/bin/env bash
set -euo pipefail
FC="${FC:-gfortran}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap431-hyd-analytical-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
for OPT in "-O0 -fcheck=all" "-O2"; do
  rm -f "$BUILD"/*.o "$BUILD"/*.mod "$BUILD"/test
  "$FC" $OPT -ffree-line-length-none -J"$BUILD" -I"$BUILD" \
    "$ROOT/src/solver/mod_soil_water_solver_contract.f90" \
    "$ROOT/src/solver/mod_b110_default_mvg_provider.f90" \
    "$ROOT/tests/fpm/test_swap431_hyd_analytical.f90" -o "$BUILD/test"
  "$BUILD/test"
done
