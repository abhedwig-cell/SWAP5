#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
for opt in 0 2; do
  gfortran -O"$opt" -std=f2008 -Wall -Wextra -Werror -ffree-line-length-none -fcheck=all \
    -J"$BUILD" -I"$BUILD" \
    "$ROOT/src/crop/mod_crop_preparation_sowing_preflight.f90" \
    "$ROOT/tests/fmig431/test_crop_preparation_sowing_preflight.f90" \
    -o "$BUILD/check_$opt"
  "$BUILD/check_$opt" > "$BUILD/o$opt.txt"
  grep -Fx 'SW431_CROP_PREP_SOW_READONLY=PASS' "$BUILD/o$opt.txt"
done
cmp "$BUILD/o0.txt" "$BUILD/o2.txt"
echo 'SW431_CROP_PREP_SOW_O0_O2_IDENTITY=PASS'
