#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for opt in 0 2; do
  gfortran -std=f2008 -fcheck=all -Werror -Wno-error=compare-reals -O"$opt" \
    "$ROOT/src/crop/mod_crop_tav_day_window.f90" \
    "$ROOT/tests/fmig431/test_crop_tav_day_window.f90" -o "$TMP/test$opt"
  "$TMP/test$opt" > "$TMP/out$opt"
  grep -Fx 'CROP_TAV_DAY_WINDOW=PASS' "$TMP/out$opt"
done
cmp "$TMP/out0" "$TMP/out2"
echo 'CROP_TAV_DAY_WINDOW_O0_O2=PASS'
