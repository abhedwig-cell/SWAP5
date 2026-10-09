#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for opt in 0 2; do
 (cd "$TMP" && gfortran -std=f2008 -fcheck=all -ffpe-trap=invalid,zero,overflow -Werror -O"$opt" \
 "$ROOT/src/crop/mod_crop_germination_preflight.f90" \
 "$ROOT/tests/fmig431/test_crop_b111_preflight_source_order.f90" -o "test$opt")
 "$TMP/test$opt" > "$TMP/out$opt"
 grep -Fx 'CROP_B111_PREFLIGHT_SOURCE_ORDER=PASS' "$TMP/out$opt"
done
cmp "$TMP/out0" "$TMP/out2"
echo 'CROP_B111_PREFLIGHT_SOURCE_ORDER_O0_O2=PASS'
