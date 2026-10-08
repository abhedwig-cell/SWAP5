#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  for test in test_ppa_wu05b_frost_effect test_frost_invalid_input_preservation; do
    gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror \
      -fcheck=all -ffpe-trap=invalid,zero,overflow -O"$opt" \
      -J "$OUT" -I "$OUT" \
      "$ROOT/src/process/mod_frost_hydraulic_effect.f90" \
      "$ROOT/tests/frost/$test.f90" -o "$OUT/$test"
    "$OUT/$test" >> "$OUT/output.txt"
  done
  grep -Fxq 'PPA-WU05B frost effect: PASS' "$OUT/output.txt"
  grep -Fxq 'FROST_INVALID_INPUT_PRESERVATION=PASS' "$OUT/output.txt"
  cat "$OUT/output.txt"
done
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FROST_INVALID_INPUT_O0_O2_IDENTICAL=PASS'
