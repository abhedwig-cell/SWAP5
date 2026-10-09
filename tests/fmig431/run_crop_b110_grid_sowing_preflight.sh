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
     "$ROOT/src/crop/mod_crop_b111_sowing_node.f90" \
     "$ROOT/src/crop/mod_crop_b110_grid_sowing_preflight.f90" \
     "$ROOT/tests/fmig431/test_crop_b110_grid_sowing_preflight.f90" -o test
   ./test > out
 )
 grep -Fx 'SW431_CROP_B110_GRID_SOW_PREFLIGHT=PASS' "$BUILD/o$OPT/out"
done
cmp "$BUILD/o0/out" "$BUILD/o2/out"
echo 'SW431_CROP_B110_GRID_SOW_O0_O2=PASS'
