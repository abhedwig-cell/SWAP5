#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-nlglob14z44a-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

gfortran -std=f2008 -O2 -Wall -Wextra   src/runtime/mod_timestep_numerical_profile.f90   tests/fpe/test_fpe_nlglob14z44a_profile_admission.f90   -o "$BUILD/z44a_profile"
"$BUILD/z44a_profile"

gfortran -std=f2008 -O2 -Wall -Wextra -J"$BUILD" -I"$BUILD"   src/solver/mod_soil_water_solver_contract.f90   src/solver/mod_reference_richards_workspace.f90   src/runtime/mod_moving_interface_manager.f90   tests/fpe/test_fpe_nlglob14z44a_manager_admission.f90   -o "$BUILD/z44a_manager"
"$BUILD/z44a_manager"

echo 'F_PE_NLGLOB14Z44A_RESULT={"aggregate":"QUALIFIED_Z44A_CANONICAL_ADMISSION_READY","profile_default_off":true,"manager_fallback_rollback":true}'
echo 'F_PE_NLGLOB14Z44A=PASS'
