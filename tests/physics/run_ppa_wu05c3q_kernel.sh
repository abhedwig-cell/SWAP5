#!/usr/bin/env bash
set -euo pipefail
FC="${FC:-gfortran}"
B="${TMPDIR:-/tmp}/ppa_wu05c3q_kernel"
rm -rf "$B"; mkdir -p "$B"
FLAGS=(-std=f2008 -Wall -Wextra -Werror -fcheck=all -ffree-line-length-none)
"$FC" "${FLAGS[@]}" \
  src/physics/oxygen/mod_oxygen_macro_zero_depth.f90 \
  src/physics/oxygen/mod_oxygen_scalar_bracket.f90 \
  src/physics/oxygen/mod_bartholomeus_micro.f90 \
  src/physics/oxygen/mod_bartholomeus_macro.f90 \
  src/physics/oxygen/mod_bartholomeus_response.f90 \
  tests/physics/test_bartholomeus_kernel_smoke.f90 -o "$B/kernel"
"$B/kernel"
"$FC" "${FLAGS[@]}" src/physics/oxygen/mod_oxygen_macro_zero_depth.f90 tests/physics/test_oxygen_macro_zero_depth.f90 -o "$B/macro"
"$B/macro"
"$FC" "${FLAGS[@]}" src/physics/oxygen/mod_oxygen_scalar_bracket.f90 tests/physics/test_oxygen_scalar_bracket.f90 -o "$B/bracket"
"$B/bracket"
