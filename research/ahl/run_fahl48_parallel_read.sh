#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fahl48-parallel-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
COMMON=(-std=f2008 -ffree-line-length-none -O3 -fopenmp)
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c src/solver/mod_soil_water_solver_contract.f90 -o "$BUILD/contract.o"
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c src/solver/mod_b110_default_mvg_provider.f90 -o "$BUILD/default.o"
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c research/ahl/mod_ahl48_shared_direct_retention_provider.f90 -o "$BUILD/shared.o"
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c research/ahl/test_fahl48_parallel_read.f90 -o "$BUILD/test.o"
gfortran -O3 -fopenmp "$BUILD/contract.o" "$BUILD/default.o" "$BUILD/shared.o" "$BUILD/test.o" -o "$BUILD/test"
OMP_NUM_THREADS=8 "$BUILD/test"
