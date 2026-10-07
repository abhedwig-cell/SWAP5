#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap431_soil_n_tx"
rm -rf "$BUILD"
mkdir -p "$BUILD"

for OPT in O0 O2; do
  FLAGS=(-std=f2008 -Wall -Wextra -Werror -fcheck=all -ffpe-trap=invalid,zero,overflow "-$OPT")
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/transaction/mod_transaction_reference.f90" -o "$BUILD/tx_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/process/mod_soil_n_pool_state.f90" -o "$BUILD/pool_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" -c "$ROOT/src/runtime/mod_fmr_b111_soil_n_transaction.f90" -o "$BUILD/model_$OPT.o"
  gfortran "${FLAGS[@]}" -J"$BUILD" -I"$BUILD" "$ROOT/tests/physics/test_fmr_b111_soil_n_transaction.f90" "$BUILD/tx_$OPT.o" "$BUILD/pool_$OPT.o" "$BUILD/model_$OPT.o" -o "$BUILD/test_$OPT"
  "$BUILD/test_$OPT"
done
