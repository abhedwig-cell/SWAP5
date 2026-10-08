#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap431_age_substep"
rm -rf "$BUILD"
mkdir -p "$BUILD"

for OPT in O0 O2; do
  FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -ffpe-trap=invalid,zero,overflow "-$OPT")
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/process/mod_solute_compartment_state.f90" -o "$BUILD/comp_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/process/mod_b111_age_tracer_substep.f90" -o "$BUILD/age_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" "$ROOT/tests/physics/test_b111_age_tracer_substep.f90" "$BUILD/comp_$OPT.o" "$BUILD/age_$OPT.o" -o "$BUILD/test_$OPT"
  "$BUILD/test_$OPT"
done
