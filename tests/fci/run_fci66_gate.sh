#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fci66-gate-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
COMMON=(-std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -fopenmp)
TX="$ROOT/src/transaction/mod_transaction_reference.f90"
CONTRACTS="$ROOT/src/runtime/mod_canonical_contracts.f90"
RUNTIME="$ROOT/src/runtime/mod_canonical_interval_runtime.f90"
TEST="$ROOT/tests/fci/test_fci66_subinterval_policy.f90"

# First preserve the complete pre-existing F-CI04 runtime contract under the
# no-selector/default path.
bash "$ROOT/tests/fci/run_fci04_gate.sh"

# F-CI66 changes execution policy only; the physical-model contract remains
# byte-identical to the current canonical authority.
test "$(git -C "$ROOT" hash-object src/runtime/mod_canonical_contracts.f90)" = \
  "3cbb81b25626e6574ae83416f088dc52882f91fc"

grep -q 'canonical_subinterval_target_selector' "$RUNTIME"
grep -q 'max_retries_cap' "$RUNTIME"
grep -q 'min(config%transaction%max_retries, max_retries_cap)' "$RUNTIME"
grep -q 'transaction_t1 > interval%t1' "$RUNTIME"
if grep -Ein 'rossfast|ross01|d3r|dyadic|0\.0016' "$RUNTIME"; then
  echo 'FCI66_STATIC_GATE FAIL: model-specific scheduling policy leaked into canonical runtime' >&2
  exit 1
fi

for OPT in o0 o2; do
  FLAG="-O0"
  if [[ "$OPT" == "o2" ]]; then FLAG="-O2"; fi
  gfortran "${COMMON[@]}" "$FLAG" -J "$BUILD/$OPT" \
    "$TX" "$CONTRACTS" "$RUNTIME" "$TEST" -o "$BUILD/test_$OPT"
  "$BUILD/test_$OPT"
done

echo 'FCI66_CANONICAL_SUBINTERVAL_POLICY_GATE PASS'
