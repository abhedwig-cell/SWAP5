#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fkt08-gate-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
COMMON=(-std=f2008 -Wall -Wextra -Werror -ffree-line-length-none -fcheck=all -fbacktrace -fopenmp)
TX="$ROOT/src/transaction/mod_transaction_reference.f90"
CONTRACTS="$ROOT/src/runtime/mod_canonical_contracts.f90"
RUNTIME="$ROOT/src/runtime/mod_canonical_interval_runtime.f90"
KERNEL="$ROOT/src/kernel/mod_kernel_transactions.f90"
TEST="$ROOT/tests/fkt/test_fkt08_mass_accounting.f90"

# Preserve the full previously-qualified F-KT01..07 transaction/checkpoint boundary.
bash "$ROOT/tests/fkt/run_fkt07_gate.sh"
python3 "$ROOT/tools/fkt/fkt08_mass_accounting_gate.py"

for OPT in o0 o2; do
  FLAG="-O0"
  if [[ "$OPT" == "o2" ]]; then FLAG="-O2"; fi
  gfortran "${COMMON[@]}" "$FLAG" -J "$BUILD/$OPT" -I "$BUILD/$OPT" \
    "$TX" "$CONTRACTS" "$RUNTIME" "$KERNEL" "$TEST" -o "$BUILD/test_$OPT"
  "$BUILD/test_$OPT" > "$BUILD/$OPT/fkt08.log"
  grep -q 'FKT08_MASS_ACCOUNTING_GATE PASS' "$BUILD/$OPT/fkt08.log"
done

cmp "$BUILD/o0/fkt08.log" "$BUILD/o2/fkt08.log"
echo 'FKT08_FOCUSED_O0_O2_GATE PASS'
