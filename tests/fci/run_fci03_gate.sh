#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fci03-gate-$$"
mkdir -p "$BUILD/worker-o0" "$BUILD/worker-o2"
trap 'rm -rf "$BUILD"' EXIT

python3 "$ROOT/tools/fci/fci03_transaction_substrate_gate.py"

# Re-run the qualified A23BL transaction contract byte-for-byte at O0 and O2.
bash "$ROOT/tests/transaction/run_a23bl_gate.sh"

COMMON=(-std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -fopenmp)
WORKER_SRC="$ROOT/src/runtime/mod_a23bu_worker_execution_context.f90"
WORKER_TEST="$ROOT/tests/runtime/test_a23bu_worker_context.f90"

gfortran "${COMMON[@]}" -O0 -J "$BUILD/worker-o0" "$WORKER_SRC" "$WORKER_TEST" -o "$BUILD/worker_test_o0"
OMP_NUM_THREADS=8 "$BUILD/worker_test_o0"

gfortran "${COMMON[@]}" -O2 -J "$BUILD/worker-o2" "$WORKER_SRC" "$WORKER_TEST" -o "$BUILD/worker_test_o2"
OMP_NUM_THREADS=8 "$BUILD/worker_test_o2"

if grep -Ein '\bsave\b|open\s*\(|read\s*\(|write\s*\(' "$WORKER_SRC"; then
  echo 'F-CI03_WORKER_STATIC_GATE FAIL: hidden state or file I/O found' >&2
  exit 1
fi
if grep -Ein '\buse\s+variables\b|\buse\s+MOD_grid\b|\bsubroutine\s+SWAP\b' "$WORKER_SRC"; then
  echo 'F-CI03_WORKER_STATIC_GATE FAIL: worker context depends on legacy production globals' >&2
  exit 1
fi

echo 'F-CI03_GATE PASS'
