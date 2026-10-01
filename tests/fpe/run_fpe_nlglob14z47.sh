#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-nlglob14z47-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

gfortran -std=f2008 -O2 -Wall -Wextra -ffree-line-length-none -J"$BUILD" -I"$BUILD" \
  src/solver/mod_soil_water_solver_contract.f90 \
  src/solver/mod_reference_richards_state_binding.f90 \
  src/runtime/mod_timestep_numerical_profile.f90 \
  src/runtime/mod_moving_interface_manager.f90 \
  tests/fpe/test_fpe_nlglob14z47_eligibility.f90 \
  -o "$BUILD/z47_eligibility"

"$BUILD/z47_eligibility"
