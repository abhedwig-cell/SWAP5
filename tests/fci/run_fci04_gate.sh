#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fci04-gate-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
COMMON=(-std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -fopenmp)
TX="$ROOT/src/transaction/mod_transaction_reference.f90"
CONTRACTS="$ROOT/src/runtime/mod_canonical_contracts.f90"
RUNTIME="$ROOT/src/runtime/mod_canonical_interval_runtime.f90"
TEST="$ROOT/tests/fci/test_fci04_interval_runtime.f90"

python3 "$ROOT/tools/fci/fci03_transaction_substrate_gate.py"
python3 "$ROOT/tools/fci/fci04_contract_gate.py"

for OPT in o0 o2; do
  FLAG="-O0"
  if [[ "$OPT" == "o2" ]]; then FLAG="-O2"; fi
  gfortran "${COMMON[@]}" "$FLAG" -J "$BUILD/$OPT" \
    "$TX" "$CONTRACTS" "$RUNTIME" "$TEST" -o "$BUILD/test_$OPT"
  "$BUILD/test_$OPT"
done

if grep -Ein '\bsave\b|open\s*\(|read\s*\(|write\s*\(' "$CONTRACTS" "$RUNTIME"; then
  echo 'FCI04_STATIC_GATE FAIL: hidden state or file I/O found in canonical runtime' >&2
  exit 1
fi

if [[ -e "$ROOT/src/adapter/mod_a23bu_hupsel_worker_component.f90" ]]; then
  echo 'FCI04_STATIC_GATE FAIL: wholesale A23BU adapter must remain absent' >&2
  exit 1
fi

echo 'FCI04_CANONICAL_RUNTIME_GATE PASS'
