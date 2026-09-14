#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fci66-gate-$$"
mkdir -p "$BUILD/legacy_o0" "$BUILD/legacy_o2" "$BUILD/selector_o0" "$BUILD/selector_o2"
trap 'rm -rf "$BUILD"' EXIT

COMMON=(-std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -fopenmp)
TX="$ROOT/src/transaction/mod_transaction_reference.f90"
CONTRACTS="$ROOT/src/runtime/mod_canonical_contracts.f90"
RUNTIME="$ROOT/src/runtime/mod_canonical_interval_runtime.f90"
LEGACY_TEST="$ROOT/tests/fci/test_fci04_interval_runtime.f90"
SELECTOR_TEST="$ROOT/tests/fci/test_fci66_window_target_selector.f90"

# Immutable dependencies: F-CI66 changes the interval execution-policy seam only.
test "$(git -C "$ROOT" rev-parse HEAD:src/transaction/mod_transaction_reference.f90)" = \
  d5a71a526efaebd82054580c3186f8e3545db331
test "$(git -C "$ROOT" rev-parse HEAD:src/runtime/mod_canonical_contracts.f90)" = \
  3cbb81b25626e6574ae83416f088dc52882f91fc

# The canonical seam must remain generic; RossFast science belongs outside it.
if grep -Eiq 'ROSSFAST|ROSS01|D3R|DYADIC|0\.0016' "$RUNTIME"; then
  echo 'FCI66_STATIC_GATE FAIL: model-specific scheduler semantics leaked into canonical runtime' >&2
  exit 1
fi

grep -Fq 'procedure(canonical_subinterval_target_selector), optional :: target_selector' "$RUNTIME"
grep -Fq 'call target_selector(cursor, interval%t1, transaction_t1, max_retries_cap, selector_valid)' "$RUNTIME"
grep -Fq 'transaction_policy%max_retries = min(config%transaction%max_retries, max_retries_cap)' "$RUNTIME"
grep -Fq 'call execute_reference_interval(model, working, cursor, transaction_t1, transaction_policy, tx)' "$RUNTIME"
grep -Fq 'next_cursor > transaction_t1 + tol' "$RUNTIME"

for OPT in o0 o2; do
  FLAG="-O0"
  if [[ "$OPT" == "o2" ]]; then FLAG="-O2"; fi

  # Replay existing FCI04 executable semantics on the modified source to prove
  # that omitting the optional selector preserves the established API and
  # current-canonical interval behavior.
  gfortran "${COMMON[@]}" "$FLAG" -J "$BUILD/legacy_$OPT" \
    "$TX" "$CONTRACTS" "$RUNTIME" "$LEGACY_TEST" -o "$BUILD/legacy_$OPT/test"
  "$BUILD/legacy_$OPT/test"

  gfortran "${COMMON[@]}" "$FLAG" -J "$BUILD/selector_$OPT" \
    "$TX" "$CONTRACTS" "$RUNTIME" "$SELECTOR_TEST" -o "$BUILD/selector_$OPT/test"
  "$BUILD/selector_$OPT/test"
done

if grep -Ein '\bsave\b|open\s*\(|read\s*\(|write\s*\(' "$CONTRACTS" "$RUNTIME"; then
  echo 'FCI66_STATIC_GATE FAIL: hidden state or file I/O found in canonical runtime' >&2
  exit 1
fi

echo 'FCI66_CURRENT_CANONICAL_SUBINTERVAL_EXECUTION_POLICY_ADMISSION=PASS'
