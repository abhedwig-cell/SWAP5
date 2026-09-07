#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fkt08-forward-$$"
mkdir -p "$BUILD/fkt06/o0" "$BUILD/fkt06/o2" "$BUILD/fkt07/o0" "$BUILD/fkt07/o2"
trap 'rm -rf "$BUILD"' EXIT
COMMON=(-std=f2008 -Wall -Wextra -Werror -ffree-line-length-none -fcheck=all -fbacktrace -fopenmp)
TX="$ROOT/src/transaction/mod_transaction_reference.f90"
CONTRACTS="$ROOT/src/runtime/mod_canonical_contracts.f90"
RUNTIME="$ROOT/src/runtime/mod_canonical_interval_runtime.f90"
KERNEL="$ROOT/src/kernel/mod_kernel_transactions.f90"
STUBS="$ROOT/tests/fci/fci08_process_state_stubs.f90"
WATER="$ROOT/src/adapter/mod_b1_10_water_checkpoint.f90"
PROCESS="$ROOT/src/adapter/mod_b1_10_process_checkpoint.f90"

for OPT in o0 o2; do
  FLAG="-O0"
  if [[ "$OPT" == "o2" ]]; then FLAG="-O2"; fi
  O="$BUILD/fkt06/$OPT"
  gfortran "${COMMON[@]}" "$FLAG" -J "$O" -I "$O" \
    "$TX" "$CONTRACTS" "$RUNTIME" "$KERNEL" \
    "$ROOT/tests/fkt/test_fkt06_optional_continuation.f90" -o "$O/test"
  "$O/test" > "$O/log"
  grep -q 'FKT06_OPTIONAL_CONTINUATION_GATE PASS' "$O/log"

  O="$BUILD/fkt07/$OPT"
  gfortran "${COMMON[@]}" "$FLAG" -J "$O" -I "$O" \
    "$TX" "$CONTRACTS" "$RUNTIME" "$STUBS" "$WATER" "$PROCESS" "$KERNEL" \
    "$ROOT/tests/fkt/test_fkt07_macropore_continuation.f90" -o "$O/test"
  "$O/test" > "$O/log"
  grep -q 'FKT07_MACROPORE_CONTINUATION_GATE PASS' "$O/log"
done

cmp "$BUILD/fkt06/o0/log" "$BUILD/fkt06/o2/log"
cmp "$BUILD/fkt07/o0/log" "$BUILD/fkt07/o2/log"
echo 'FKT08_FKT06_FKT07_FORWARD_REGRESSION PASS'
