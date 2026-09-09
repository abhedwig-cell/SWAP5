#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi25-contract-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace \
  -J"$BUILD" -I"$BUILD" \
  src/solver/mod_soil_water_solver_contract.f90 \
  tests/fsi/test_fsi25_temporal_indicator_contract.f90 \
  -o "$BUILD/test_fsi25_contract"

"$BUILD/test_fsi25_contract"
