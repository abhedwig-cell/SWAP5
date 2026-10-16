#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/ppa-frozen-drain-source"
mkdir -p "$BUILD"
for opt in 0 2; do
  mkdir -p "$BUILD/o$opt"
  gfortran -std=f2008 -ffree-line-length-none -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -O"$opt" -J "$BUILD/o$opt" -I "$BUILD/o$opt" \
    "$ROOT/tests/frost/test_ppa_wu05b_frozen_drain_source.f90" \
    "$ROOT/reference/swap-4.3.1/b1_11_frost_source/SWAP/frozencond.f90" \
    "$ROOT/tests/frost/test_ppa_wu05b_frozen_drain_source_main.f90" -o "$BUILD/o$opt/test"
  "$BUILD/o$opt/test" > "$BUILD/o$opt/output.txt"
  cat "$BUILD/o$opt/output.txt"
done
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
