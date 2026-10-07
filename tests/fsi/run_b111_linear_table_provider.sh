#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-b111-linear-table"
rm -rf "$BUILD"; mkdir -p "$BUILD"; cd "$BUILD"
SRC=("$ROOT/src/solver/mod_soil_water_solver_contract.f90" "$ROOT/src/solver/mod_b111_linear_table_provider.f90" "$ROOT/tests/fsi/test_b111_linear_table_provider.f90")
gfortran -std=f2018 -ffree-line-length-none -O0 -fcheck=all -ffpe-trap=invalid,zero,overflow "${SRC[@]}" -o l0
./l0 > o0.txt
rm -f ./*.o ./*.mod
gfortran -std=f2018 -ffree-line-length-none -O2 "${SRC[@]}" -o l2
./l2 > o2.txt
cmp o0.txt o2.txt
grep -q B111_LINEAR_TABLE_PASS o0.txt
echo B111_LINEAR_TABLE_O0_O2=PASS
