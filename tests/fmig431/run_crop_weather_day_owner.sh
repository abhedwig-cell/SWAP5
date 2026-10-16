#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for opt in 0 2; do
 (cd "$TMP" && gfortran -std=f2008 -fcheck=all -ffpe-trap=invalid,zero,overflow -Wall -Wextra -Werror -Wno-error=compare-reals -O"$opt" "$ROOT/src/crop/mod_crop_weather_day_owner.f90" "$ROOT/tests/fmig431/test_crop_weather_day_owner.f90" -o "test$opt")
 "$TMP/test$opt" > "$TMP/out$opt"
 grep -Fx 'CROP_WEATHER_DAY_OWNER=PASS' "$TMP/out$opt"
done
cmp "$TMP/out0" "$TMP/out2"
echo CROP_WEATHER_DAY_OWNER_O0_O2=PASS
