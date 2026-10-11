#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fci11-gate-$$"
trap 'rm -rf "$BUILD"' EXIT
mkdir -p "$BUILD/o0" "$BUILD/o2"
python "$ROOT/tools/fci/fci11_interval_mass_source_gate.py"
for opt in 0 2; do
  O="$BUILD/o$opt"
  FLAGS=(-O$opt -std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffree-line-length-none -J "$O" -I "$O")
  gfortran "${FLAGS[@]}" -c "$ROOT/src/adapter/mod_b1_10_interval_seam.f90" -o "$O/seam.o"
  gfortran "${FLAGS[@]}" -c "$ROOT/tests/fci/test_fci11_interval_seam.f90" -o "$O/test.o"
  gfortran -O$opt -o "$O/test_interval" "$O/seam.o" "$O/test.o"
  "$O/test_interval" > "$O/gate.log"
  grep -q 'FCI11_INTERVAL_SEAM PASS' "$O/gate.log"
done
cmp "$BUILD/o0/gate.log" "$BUILD/o2/gate.log"
echo FCI11_GATE_PASS
