#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

python "$ROOT/tools/fci/fci06_controlled_source_port_gate.py"

for opt in 0 2; do
  BUILD="$ROOT/.fci06-checkpoint-o$opt"
  rm -rf "$BUILD"
  mkdir -p "$BUILD"
  FLAGS=(-O$opt -std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffree-line-length-none -J "$BUILD" -I "$BUILD")

  gfortran "${FLAGS[@]}" -c "$ROOT/src/transaction/mod_transaction_reference.f90" -o "$BUILD/mod_transaction_reference.o"
  gfortran "${FLAGS[@]}" -c "$ROOT/src/runtime/mod_canonical_contracts.f90" -o "$BUILD/mod_canonical_contracts.o"
  gfortran "${FLAGS[@]}" -c "$ROOT/tests/fci/fci06_legacy_state_stubs.f90" -o "$BUILD/fci06_legacy_state_stubs.o"
  gfortran "${FLAGS[@]}" -c "$ROOT/src/adapter/mod_b1_10_water_checkpoint.f90" -o "$BUILD/mod_b1_10_water_checkpoint.o"
  gfortran "${FLAGS[@]}" -c "$ROOT/tests/fci/test_fci06_water_checkpoint.f90" -o "$BUILD/test_fci06_water_checkpoint.o"
  gfortran -O$opt -o "$BUILD/test_fci06_water_checkpoint" \
    "$BUILD/mod_transaction_reference.o" \
    "$BUILD/mod_canonical_contracts.o" \
    "$BUILD/fci06_legacy_state_stubs.o" \
    "$BUILD/mod_b1_10_water_checkpoint.o" \
    "$BUILD/test_fci06_water_checkpoint.o"
  "$BUILD/test_fci06_water_checkpoint" > "$BUILD/gate.log"
  grep -q 'FCI06_B1_10_WATER_CHECKPOINT PASS' "$BUILD/gate.log"
done

cmp "$ROOT/.fci06-checkpoint-o0/gate.log" "$ROOT/.fci06-checkpoint-o2/gate.log"
echo FCI06_GATE_PASS
