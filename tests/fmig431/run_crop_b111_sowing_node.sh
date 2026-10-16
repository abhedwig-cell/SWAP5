#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
for OPT in 0 2; do
 mkdir -p "$BUILD/o$OPT"
 (
  cd "$BUILD/o$OPT"
  gfortran -std=f2008 -Wall -Wextra -fcheck=all "-O$OPT" "$ROOT/src/crop/mod_crop_b111_sowing_node.f90" "$ROOT/tests/fmig431/test_crop_b111_sowing_node.f90" -o test
  ./test > out
 )
 grep -Fx 'B111_SOWING_NODE=PASS' "$BUILD/o$OPT/out"
done
cmp "$BUILD/o0/out" "$BUILD/o2/out"
echo 'SW431_CROP_B111_SOWING_NODE_O0_O2=PASS'
