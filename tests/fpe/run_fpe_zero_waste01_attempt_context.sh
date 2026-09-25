#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-/tmp}/fpe-zero-waste01-attempt-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

COMMON=(-std=f2008 -ffree-line-length-none -O2 -Wall -Wextra)
gfortran "${COMMON[@]}" -J"$BUILD" -I"$BUILD" -c src/transaction/mod_transaction_reference.f90 -o "$BUILD/tx.o"
gfortran "${COMMON[@]}" -J"$BUILD" -I"$BUILD" -c src/solver/mod_soil_water_accepted_step_direction_contract.f90 -o "$BUILD/dir_contract.o"
gfortran "${COMMON[@]}" -J"$BUILD" -I"$BUILD" -c src/transaction/mod_accepted_trajectory_directional_sensitivity.f90 -o "$BUILD/traj.o"
gfortran "${COMMON[@]}" -J"$BUILD" -I"$BUILD" -c src/runtime/mod_fmr_bottom_thermal_carrier.f90 -o "$BUILD/bottom.o"
gfortran "${COMMON[@]}" -J"$BUILD" -I"$BUILD" -c src/runtime/mod_fmr_top_sensible_boundary_carrier.f90 -o "$BUILD/top.o"
gfortran "${COMMON[@]}" -J"$BUILD" -I"$BUILD" -c tests/fpe/test_fpe_zero_waste01_attempt_context.f90 -o "$BUILD/test.o"
gfortran -O2 "$BUILD/tx.o" "$BUILD/dir_contract.o" "$BUILD/traj.o" "$BUILD/bottom.o" "$BUILD/top.o" "$BUILD/test.o" -o "$BUILD/test"
"$BUILD/test"
