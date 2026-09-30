#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-nlglob14z35-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

python3 tests/fpe/materialize_fpe_nlglob14z35_physical_fixture.py "$BUILD/mod_fpe_nlglob14z35_fixture.f90"

gfortran -std=f2008 -O2 -Wall -Wextra -J"$BUILD" -I"$BUILD"   src/solver/mod_soil_water_solver_contract.f90   src/solver/mod_reference_richards_workspace.f90   src/runtime/mod_moving_interface_manager.f90   "$BUILD/mod_fpe_nlglob14z35_fixture.f90"   tests/fpe/test_fpe_nlglob14z35_manager_physical_binding.f90   -o "$BUILD/z35_manager_physical"

"$BUILD/z35_manager_physical"
