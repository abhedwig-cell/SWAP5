#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
for OPT in 0 2; do
  mkdir -p "$BUILD/o$OPT"
  (
    cd "$BUILD/o$OPT"
    gfortran -std=f2008 -Wall -Wextra -fcheck=all "-O$OPT" \
      "$ROOT/src/crop/mod_crop_b111_pressure_head_average.f90" \
      "$ROOT/tests/fmig431/test_crop_b111_pressure_head_average.f90" -o test
    ./test > out
  )
  grep -Fx 'CROP_HAVG_B111=PASS' "$BUILD/o$OPT/out"
done
cmp "$BUILD/o0/out" "$BUILD/o2/out"
echo 'SW431_CROP_HAVG_O0_O2=PASS'
