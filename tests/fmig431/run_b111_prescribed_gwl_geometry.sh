#!/usr/bin/env bash
set -euo pipefail
R="$(cd "$(dirname "$0")/../.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
for o in 0 2; do
  gfortran -O$o -std=f2008 -ffree-line-length-none -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -J"$T" -I"$T" "$R/src/solver/mod_b111_prescribed_gwl_geometry.f90" \
    "$R/tests/fmig431/test_b111_prescribed_gwl_geometry.f90" -o "$T/t"
  "$T/t"
done
