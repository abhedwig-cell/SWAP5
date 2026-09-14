#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fci66-gate-$$"
mkdir -p "$BUILD/legacy_o0" "$BUILD/legacy_o2" "$BUILD/policy_o0" "$BUILD/policy_o2"
trap 'rm -rf "$BUILD"' EXIT
COMMON=(-std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -fopenmp)
TX="$ROOT/src/transaction/mod_transaction_reference.f90"
CONTRACTS="$ROOT/src/runtime/mod_canonical_contracts.f90"
RUNTIME="$ROOT/src/runtime/mod_canonical_interval_runtime.f90"
LEGACY_TEST="$ROOT/tests/fci/test_fci04_interval_runtime.f90"
TEST="$ROOT/tests/fci/test_fci66_subinterval_policy.f90"

# F-CI66 changes execution policy only. Transaction and physical-model
# contracts remain byte-identical to the current-canonical preimage.
test "$(git -C "$ROOT" hash-object src/transaction/mod_transaction_reference.f90)" = \
  "d5a71a526efaebd82054580c3186f8e3545db331"
test "$(git -C "$ROOT" hash-object src/runtime/mod_canonical_contracts.f90)" = \
  "3cbb81b25626e6574ae83416f088dc52882f91fc"

grep -q 'canonical_subinterval_target_selector' "$RUNTIME"
grep -q 'max_retries_cap' "$RUNTIME"
grep -q 'min(config%transaction%max_retries, max_retries_cap)' "$RUNTIME"
grep -q 'call execute_reference_interval(model, working, cursor, transaction_t1, transaction_policy, tx)' "$RUNTIME"
grep -q 'next_cursor > transaction_t1 + tol' "$RUNTIME"
grep -q 'transaction_t1 > interval%t1' "$RUNTIME"
if grep -Ein 'rossfast|ross01|d3r|dyadic|0\.0016' "$RUNTIME"; then
  echo 'FCI66_STATIC_GATE FAIL: model-specific scheduling policy leaked into canonical runtime' >&2
  exit 1
fi

if grep -Ein '\bsave\b|open\s*\(|read\s*\(|write\s*\(' "$CONTRACTS" "$RUNTIME"; then
  echo 'FCI66_STATIC_GATE FAIL: hidden state or file I/O found in canonical runtime' >&2
  exit 1
fi

for OPT in o0 o2; do
  FLAG="-O0"
  if [[ "$OPT" == "o2" ]]; then FLAG="-O2"; fi

  # Replay the established FCI04 executable behavior directly against the
  # modified current source. The historical FCI03/FCI04 provenance gate is
  # intentionally not invoked: it still freezes superseded A23 byte identity
  # and is not current-canonical authority.
  gfortran "${COMMON[@]}" "$FLAG" -J "$BUILD/legacy_$OPT" \
    "$TX" "$CONTRACTS" "$RUNTIME" "$LEGACY_TEST" -o "$BUILD/legacy_$OPT/test"
  "$BUILD/legacy_$OPT/test"

  gfortran "${COMMON[@]}" "$FLAG" -J "$BUILD/policy_$OPT" \
    "$TX" "$CONTRACTS" "$RUNTIME" "$TEST" -o "$BUILD/policy_$OPT/test"
  "$BUILD/policy_$OPT/test"
done

echo 'FCI66_CANONICAL_SUBINTERVAL_POLICY_GATE PASS'
