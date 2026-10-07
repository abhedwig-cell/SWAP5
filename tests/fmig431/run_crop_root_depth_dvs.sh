#!/usr/bin/env bash
set -euo pipefail
R="$(cd "$(dirname "$0")/../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
for o in 0 2; do
  gfortran -O$o -std=f2008 -ffree-line-length-none -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow \
    "$R/src/crop/mod_wofost_rate_table.f90" \
    "$R/src/crop/mod_crop_root_depth_dvs.f90" \
    "$R/tests/fmig431/test_crop_root_depth_dvs.f90" -o "$T/test"
  "$T/test"
done
