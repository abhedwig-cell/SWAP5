#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-nlglob14z34-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

gfortran -std=f2008 -O2 -Wall -Wextra -J"$BUILD" -I"$BUILD"   src/solver/mod_soil_water_solver_contract.f90   src/solver/mod_reference_richards_workspace.f90   src/runtime/mod_moving_interface_manager.f90   tests/fpe/test_fpe_nlglob14z34_manager_seam.f90   -o "$BUILD/z34_manager_seam"

"$BUILD/z34_manager_seam"
