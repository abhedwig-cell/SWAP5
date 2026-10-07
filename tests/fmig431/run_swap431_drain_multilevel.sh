#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
for opt in 0 2; do
  D="$BUILD/o$opt"; mkdir -p "$D"
  gfortran -std=f2008 -ffree-line-length-none -fcheck=all -ffpe-trap=invalid,zero,overflow -O"$opt" -J"$D" -I"$D" \
    "$ROOT/tests/fmig431/swap431_multilevel_legacy_globals.f90" \
    "$ROOT/reference/swap-4.3.1/b1_11_frost_source/SWAP/divdra.f90" \
    "$ROOT/src/solver/mod_soil_water_solver_contract.f90" \
    "$ROOT/src/solver/mod_process_hydraulic_view.f90" \
    "$ROOT/src/process/mod_drainage_spatial_distribution.f90" \
    "$ROOT/src/process/mod_drainage_multilevel_distribution.f90" \
    "$ROOT/tests/fmig431/test_swap431_drain_multilevel.f90" -o "$D/test"
  "$D/test" > "$D/out.txt"
done
diff -u "$BUILD/o0/out.txt" "$BUILD/o2/out.txt"
grep -Fx 'SW431_DRAIN_DIV_MULTI_SOURCE_PARITY=PASS' "$BUILD/o0/out.txt"
grep -Fx 'SW431_DRAIN_DIV_MULTI_MASS=PASS' "$BUILD/o0/out.txt"
echo SW431_DRAIN_DIV_MULTI_QUALIFICATION=PASS
