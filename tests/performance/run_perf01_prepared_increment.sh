#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
for opt in 0 2 3; do
  mkdir "$BUILD/O$opt"
  cd "$BUILD/O$opt"
  gfortran -O"$opt" -std=f2008 -ffree-line-length-none -fcheck=all -ffpe-trap=invalid,zero,overflow \
    "$ROOT/src/solver/mod_soil_water_solver_contract.f90" \
    "$ROOT/src/solver/mod_b110_default_mvg_provider.f90" \
    "$ROOT/tests/performance/test_perf01_prepared_increment.f90" -o test
  ./test
 done
