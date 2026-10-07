#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-b111-hyst"
rm -rf "$BUILD"; mkdir -p "$BUILD"; cd "$BUILD"
SRC=("$ROOT/src/solver/mod_b111_hysteresis_state.f90" "$ROOT/tests/fsi/test_b111_hysteresis_state.f90")
gfortran -std=f2018 -ffree-line-length-none -O0 -fcheck=all -ffpe-trap=invalid,zero,overflow "${SRC[@]}" -o h0
./h0 > o0.txt
rm -f ./*.o ./*.mod
gfortran -std=f2018 -ffree-line-length-none -O2 "${SRC[@]}" -o h2
./h2 > o2.txt
cmp o0.txt o2.txt
grep -q B111_HYST_STATE_PASS o0.txt
echo B111_HYST_STATE_O0_O2=PASS
