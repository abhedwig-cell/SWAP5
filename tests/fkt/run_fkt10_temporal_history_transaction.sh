#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fkt10-history-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

build_run() {
  local opt="$1" tag="$2"
  local out="$BUILD/$tag"
  mkdir -p "$out"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/transaction/mod_transaction_reference.f90 -o "$out/mod_transaction_reference.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/transaction/mod_fkt_temporal_indicator_history.f90 -o "$out/mod_fkt_temporal_indicator_history.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c tests/fkt/test_fkt10_temporal_history_transaction.f90 -o "$out/test.o"
  gfortran "$opt" "$out/mod_transaction_reference.o" "$out/mod_fkt_temporal_indicator_history.o" "$out/test.o" -o "$out/test_fkt10"
  "$out/test_fkt10" | tee "$out/output.txt"
  grep -Fq 'FKT10_TEMPORAL_HISTORY_TRANSACTION PASS' "$out/output.txt"
}

build_run -O0 o0
build_run -O2 o2
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FKT10_GATE_H_O0_O2_IDENTITY=PASS'
echo 'FKT10_TEMPORAL_HISTORY_RUNNER PASS'
