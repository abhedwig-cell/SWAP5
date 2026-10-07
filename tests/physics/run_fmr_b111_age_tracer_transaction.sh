#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap431_age_tx"
rm -rf "$BUILD"
mkdir -p "$BUILD"

for OPT in O0 O2; do
  FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -ffpe-trap=invalid,zero,overflow "-$OPT")
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/transaction/mod_transaction_reference.f90" -o "$BUILD/tx_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/process/mod_solute_mobile_salt_state.f90" -o "$BUILD/mobile_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/process/mod_solute_compartment_state.f90" -o "$BUILD/comp_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/process/mod_b111_age_pond_exchange.f90" -o "$BUILD/pond_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/process/mod_b111_age_tracer_matrix_substep.f90" -o "$BUILD/matrix_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/process/mod_b111_age_tracer_interval.f90" -o "$BUILD/interval_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/runtime/mod_fmr_b111_solute_transaction.f90" -o "$BUILD/state_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/runtime/mod_fmr_b111_age_tracer_transaction.f90" -o "$BUILD/model_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" "$ROOT/tests/physics/test_fmr_b111_age_tracer_transaction.f90" \
    "$BUILD/tx_$OPT.o" "$BUILD/mobile_$OPT.o" "$BUILD/comp_$OPT.o" "$BUILD/pond_$OPT.o" \
    "$BUILD/matrix_$OPT.o" "$BUILD/interval_$OPT.o" "$BUILD/state_$OPT.o" "$BUILD/model_$OPT.o" \
    -o "$BUILD/test_$OPT"
  "$BUILD/test_$OPT"
done
