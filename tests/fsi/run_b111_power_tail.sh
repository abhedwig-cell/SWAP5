#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-b111-power"
rm -rf "$BUILD"
mkdir -p "$BUILD"
cd "$BUILD"
SOURCES=(
  "$ROOT/src/solver/mod_soil_water_solver_contract.f90"
  "$ROOT/src/solver/mod_b111_conductivity_power_tail.f90"
  "$ROOT/tests/fsi/test_b111_power_tail.f90"
)
gfortran -std=f2018 -ffree-line-length-none -O0 -fcheck=all -ffpe-trap=invalid,zero,overflow "${SOURCES[@]}" -o p0
./p0 > o0.txt
rm -f ./*.o ./*.mod
gfortran -std=f2018 -ffree-line-length-none -O2 "${SOURCES[@]}" -o p2
./p2 > o2.txt
cmp o0.txt o2.txt
grep -q B111_POWER_TAIL_PASS o0.txt
echo B111_POWER_O0_O2=PASS
