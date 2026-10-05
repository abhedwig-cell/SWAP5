#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/ppa-wu05b3-bottom-unit"
mkdir -p "$BUILD"
for opt in 0 2; do
  mkdir -p "$BUILD/o$opt"
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -Wno-compare-reals -fcheck=all \
    -ffpe-trap=invalid,zero,overflow -O"$opt" -J "$BUILD/o$opt" -I "$BUILD/o$opt" \
    "$ROOT/src/process/mod_frost_bottom_boundary_effect.f90" "$ROOT/tests/frost/test_ppa_wu05b3_frost_bottom.f90" \
    -o "$BUILD/o$opt/test"
  "$BUILD/o$opt/test" > "$BUILD/o$opt/output.txt"
  cat "$BUILD/o$opt/output.txt"
done
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
