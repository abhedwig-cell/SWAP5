#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-nlglob14z38-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

gfortran -std=f2008 -O3 -Wall -Wextra -ffree-line-length-none -J"$BUILD" -I"$BUILD" \
  src/solver/mod_soil_water_solver_contract.f90 \
  src/solver/mod_reference_linear_solver.f90 \
  src/solver/mod_reference_richards_workspace.f90 \
  src/runtime/mod_moving_interface_manager.f90 \
  tests/fpe/test_fpe_nlglob14z38_fortran_timing.f90 \
  -o "$BUILD/z38_timing"

"$BUILD/z38_timing"
