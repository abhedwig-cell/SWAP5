#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-a23bl-gate-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
COMMON=(-std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -fopenmp)
SRC="$ROOT/src/transaction/mod_transaction_reference.f90"
TEST="$ROOT/tests/transaction/test_transaction_reference.f90"
gfortran "${COMMON[@]}" -O0 -J "$BUILD/o0" "$SRC" "$TEST" -o "$BUILD/test_o0"
OMP_NUM_THREADS=8 "$BUILD/test_o0"
gfortran "${COMMON[@]}" -O2 -J "$BUILD/o2" "$SRC" "$TEST" -o "$BUILD/test_o2"
OMP_NUM_THREADS=8 "$BUILD/test_o2"
if grep -Ein '\bsave\b|open\s*\(|read\s*\(|write\s*\(' "$SRC"; then
  echo 'A23BL_STATIC_GATE FAIL: hidden state or file I/O found' >&2
  exit 1
fi
echo 'A23BL_STATIC_GATE PASS'
