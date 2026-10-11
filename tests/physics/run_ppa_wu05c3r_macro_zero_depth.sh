#!/usr/bin/env bash
set -euo pipefail
FC="${FC:-gfortran}"
BUILD="${TMPDIR:-/tmp}/ppa_wu05c3r_macro_zero_depth"
rm -rf "$BUILD"
mkdir -p "$BUILD"
"$FC" -std=f2008 -Wall -Wextra -Werror -fcheck=all -ffree-line-length-none \
  src/physics/oxygen/mod_oxygen_macro_zero_depth.f90 \
  tests/physics/test_oxygen_macro_zero_depth.f90 \
  -o "$BUILD/test_oxygen_macro_zero_depth"
"$BUILD/test_oxygen_macro_zero_depth"
