#!/usr/bin/env bash
set -euo pipefail
FC="${FC:-gfortran}"
BUILD="${TMPDIR:-/tmp}/ppa_wu05c3r_scalar_bracket"
rm -rf "$BUILD"
mkdir -p "$BUILD"
"$FC" -std=f2008 -Wall -Wextra -Werror -fcheck=all -ffree-line-length-none \
  src/physics/oxygen/mod_oxygen_scalar_bracket.f90 \
  tests/physics/test_oxygen_scalar_bracket.f90 \
  -o "$BUILD/test_oxygen_scalar_bracket"
"$BUILD/test_oxygen_scalar_bracket"
