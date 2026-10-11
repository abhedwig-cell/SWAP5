#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fci12-gate-$$"
trap 'rm -rf "$BUILD"' EXIT
mkdir -p "$BUILD/o0" "$BUILD/o2"

python "$ROOT/tools/fci/fci12_reference_model_gate.py"

TX="$ROOT/src/transaction/mod_transaction_reference.f90"
CONTRACTS="$ROOT/src/runtime/mod_canonical_contracts.f90"
WORKER="$ROOT/src/runtime/mod_a23bu_worker_execution_context.f90"
TRIAL="$ROOT/src/adapter/mod_b1_10_trial_mass.f90"
INTERVAL="$ROOT/src/adapter/mod_b1_10_interval_seam.f90"
BASE="$ROOT/src/adapter/mod_b1_10_transaction_binding.f90"
MASS="$ROOT/src/adapter/mod_b1_10_mass_seam.f90"
TEMPORAL="$ROOT/src/adapter/mod_b1_10_temporal_characterization.f90"
EXECUTOR="$ROOT/src/adapter/mod_b1_10_physical_interval_executor.f90"
REFERENCE="$ROOT/src/adapter/mod_b1_10_reference_model.f90"
STUBS="$ROOT/tests/fci/fci12_reference_model_stubs.f90"
TEST="$ROOT/tests/fci/test_fci12_reference_model.f90"

for opt in 0 2; do
  O="$BUILD/o$opt"
  FLAGS=(-O$opt -std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffree-line-length-none -J "$O" -I "$O")
  gfortran "${FLAGS[@]}" -c "$TX" -o "$O/transaction.o"
  gfortran "${FLAGS[@]}" -c "$CONTRACTS" -o "$O/contracts.o"
  gfortran "${FLAGS[@]}" -c "$WORKER" -o "$O/worker.o"
  gfortran "${FLAGS[@]}" -c "$TRIAL" -o "$O/trial_mass.o"
  gfortran "${FLAGS[@]}" -c "$INTERVAL" -o "$O/interval.o"
  gfortran "${FLAGS[@]}" -c "$STUBS" -o "$O/stubs.o"
  gfortran "${FLAGS[@]}" -c "$BASE" -o "$O/base_binding.o"
  gfortran "${FLAGS[@]}" -c "$MASS" -o "$O/mass_seam.o"
  gfortran "${FLAGS[@]}" -c "$TEMPORAL" -o "$O/temporal.o"
  gfortran "${FLAGS[@]}" -c "$EXECUTOR" -o "$O/executor.o"
  gfortran "${FLAGS[@]}" -c "$REFERENCE" -o "$O/reference.o"
  gfortran "${FLAGS[@]}" -c "$TEST" -o "$O/test.o"
  gfortran -O$opt -o "$O/test_reference" \
    "$O/transaction.o" "$O/contracts.o" "$O/worker.o" "$O/trial_mass.o" "$O/interval.o" \
    "$O/stubs.o" "$O/base_binding.o" "$O/mass_seam.o" "$O/temporal.o" "$O/executor.o" "$O/reference.o" "$O/test.o"

  "$O/test_reference" > "$O/pass.log"
  grep -q 'FCI12_REFERENCE_MODEL PASS' "$O/pass.log"

  if "$O/test_reference" temporal-negative > "$O/temporal-negative.log" 2>&1; then
    echo 'F-CI12 temporal negative control unexpectedly succeeded' >&2
    exit 3
  fi
  grep -q 'scalar temporal error policy not admitted' "$O/temporal-negative.log"

  if "$O/test_reference" storage-negative > "$O/storage-negative.log" 2>&1; then
    echo 'F-CI12 storage negative control unexpectedly succeeded' >&2
    exit 4
  fi
  grep -q 'profile storage accounting incomplete' "$O/storage-negative.log"
done

cmp "$BUILD/o0/pass.log" "$BUILD/o2/pass.log"
echo FCI12_GATE_PASS
