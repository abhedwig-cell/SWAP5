#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fahl45-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
COMMON=(-std=f2008 -ffree-line-length-none -O3)
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c src/solver/mod_soil_water_solver_contract.f90 -o "$BUILD/contract.o"
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c src/solver/mod_b110_default_mvg_provider.f90 -o "$BUILD/mvg.o"
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c tests/fahl/test_fahl45_direct_index_screen.f90 -o "$BUILD/test.o"
gfortran -O3 "$BUILD/contract.o" "$BUILD/mvg.o" "$BUILD/test.o" -o "$BUILD/test"
"$BUILD/test"
