#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr01-gate-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT

COMMON=(-std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -fopenmp -ffree-line-length-none)
TX="$ROOT/src/transaction/mod_transaction_reference.f90"
CONTRACTS="$ROOT/src/runtime/mod_canonical_contracts.f90"
RUNTIME="$ROOT/src/runtime/mod_canonical_interval_runtime.f90"
KERNEL="$ROOT/src/kernel/mod_kernel_transactions.f90"
CHECKPOINT="$ROOT/src/runtime/mod_fmr_checkpoint_orchestrator.f90"
CORE="$ROOT/src/runtime/mod_fmr_runtime_core.f90"
DETERMINISTIC="$ROOT/src/runtime/mod_fmr_deterministic_runtime.f90"
CHECKPOINT_TEST="$ROOT/tests/fmr/test_fmr01_checkpoint_integration.f90"
RUNTIME_TEST="$ROOT/tests/fmr/test_fmr01_runtime.f90"

# Preserve the exact consumed F-KT05 qualification boundary before F-MR testing.
bash "$ROOT/tests/fkt/run_fkt05_gate.sh"
python3 "$ROOT/tools/fmr/fmr01_contract_gate.py"

for OPT in o0 o2; do
  FLAG="-O0"
  if [[ "$OPT" == "o2" ]]; then FLAG="-O2"; fi

  gfortran "${COMMON[@]}" "$FLAG" -J "$BUILD/$OPT" \
    "$TX" "$CONTRACTS" "$RUNTIME" "$KERNEL" "$CHECKPOINT" \
    "$CHECKPOINT_TEST" -o "$BUILD/checkpoint_$OPT"
  "$BUILD/checkpoint_$OPT"

  gfortran "${COMMON[@]}" "$FLAG" -J "$BUILD/$OPT" \
    "$TX" "$CONTRACTS" "$RUNTIME" "$KERNEL" "$CHECKPOINT" "$CORE" \
    "$DETERMINISTIC" "$RUNTIME_TEST" -o "$BUILD/runtime_$OPT"
  OMP_DYNAMIC=FALSE "$BUILD/runtime_$OPT"
done

echo 'FMR01_FOCUSED_O0_O2_GATE PASS'
