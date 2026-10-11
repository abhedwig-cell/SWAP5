#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-nlglob14z43f-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

gfortran -std=f2008 -O2 -Wall -Wextra -J"$BUILD" -I"$BUILD"   src/runtime/mod_timestep_numerical_profile.f90   tests/fpe/test_fpe_nlglob14z43f_profile.f90   -o "$BUILD/z43f_profile"

"$BUILD/z43f_profile"

gfortran -std=f2008 -O2 -Wall -Wextra -J"$BUILD" -I"$BUILD"   src/solver/mod_soil_water_solver_contract.f90   src/solver/mod_reference_richards_workspace.f90   src/runtime/mod_moving_interface_manager.f90   tests/fpe/test_fpe_nlglob14z43f_manager_admission.f90   -o "$BUILD/z43f_manager"

"$BUILD/z43f_manager"

echo "F_PE_NLGLOB14Z43F=PASS"
