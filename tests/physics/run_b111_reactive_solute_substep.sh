#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap431_reactive_substep"
rm -rf "$BUILD"
mkdir -p "$BUILD"

for OPT in O0 O2; do
  FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -ffpe-trap=invalid,zero,overflow "-$OPT")
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/process/mod_solute_mobile_salt_state.f90" -o "$BUILD/mobile_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/process/mod_solute_compartment_state.f90" -o "$BUILD/comp_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/process/mod_b111_solute_sorption.f90" -o "$BUILD/sorp_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/process/mod_b111_solute_decay.f90" -o "$BUILD/decay_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/process/mod_b111_pond_solute_exchange.f90" -o "$BUILD/pond_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/process/mod_b111_reactive_solute_substep.f90" -o "$BUILD/reactive_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" "$ROOT/tests/physics/test_b111_reactive_solute_substep.f90" \
    "$BUILD/mobile_$OPT.o" "$BUILD/comp_$OPT.o" "$BUILD/sorp_$OPT.o" "$BUILD/decay_$OPT.o" "$BUILD/pond_$OPT.o" "$BUILD/reactive_$OPT.o" \
    -o "$BUILD/test_$OPT"
  "$BUILD/test_$OPT"
done
