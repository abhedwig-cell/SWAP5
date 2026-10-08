#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-b111-hyd"
rm -rf "$BUILD"; mkdir -p "$BUILD"; cd "$BUILD"
python3 "$ROOT/tests/fsi/test_b111_hydraulic_oracle_fail_closed.py"
COMMON=(-std=f2018 -ffree-line-length-none)
SOURCES=(
  "$ROOT/src/solver/mod_soil_water_solver_contract.f90"
  "$ROOT/src/solver/mod_b111_legacy_hydraulic_provider.f90"
  "$ROOT/src/solver/mod_b111_extended_hydraulic_provider.f90"
  "$ROOT/tests/fsi/test_b111_hydraulic_families.f90"
)
gfortran "${COMMON[@]}" -O0 -fcheck=all -ffpe-trap=invalid,zero,overflow "${SOURCES[@]}" -o hyd_o0
./hyd_o0 > o0.txt
python3 "$ROOT/tests/fsi/check_b111_hydraulic_families.py" o0.txt
rm -f ./*.o ./*.mod
gfortran "${COMMON[@]}" -O2 "${SOURCES[@]}" -o hyd_o2
./hyd_o2 > o2.txt
python3 "$ROOT/tests/fsi/check_b111_hydraulic_families.py" o2.txt
cmp o0.txt o2.txt
echo B111_HYDRAULIC_FAMILIES_O0_O2=PASS
