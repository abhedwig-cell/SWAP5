#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fkt07-gate-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
COMMON=(-std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -fopenmp)
TX="$ROOT/src/transaction/mod_transaction_reference.f90"
CONTRACTS="$ROOT/src/runtime/mod_canonical_contracts.f90"
RUNTIME="$ROOT/src/runtime/mod_canonical_interval_runtime.f90"
STUBS="$ROOT/tests/fci/fci08_process_state_stubs.f90"
WATER="$ROOT/src/adapter/mod_b1_10_water_checkpoint.f90"
PROCESS="$ROOT/src/adapter/mod_b1_10_process_checkpoint.f90"
KERNEL="$ROOT/src/kernel/mod_kernel_transactions.f90"
TEST="$ROOT/tests/fkt/test_fkt07_macropore_continuation.f90"

# Preserve the complete previously-qualified F-KT06 boundary first.
bash "$ROOT/tests/fkt/run_fkt06_gate.sh"
python3 "$ROOT/tools/fkt/fkt07_contract_gate.py"

for OPT in o0 o2; do
  FLAG="-O0"
  if [[ "$OPT" == "o2" ]]; then FLAG="-O2"; fi
  gfortran "${COMMON[@]}" "$FLAG" -J "$BUILD/$OPT" \
    "$TX" "$CONTRACTS" "$RUNTIME" "$STUBS" "$WATER" "$PROCESS" \
    "$KERNEL" "$TEST" -o "$BUILD/test_$OPT"
  "$BUILD/test_$OPT"
done

echo 'FKT07_FOCUSED_O0_O2_GATE PASS'
