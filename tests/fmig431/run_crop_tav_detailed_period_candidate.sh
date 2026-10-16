#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
for opt in 0 2; do
 (cd "$TMP" && gfortran -std=f2008 -fcheck=all -ffpe-trap=invalid,zero,overflow -Werror -O"$opt" "$ROOT/src/crop/mod_crop_tav_detailed_period_candidate.f90" "$ROOT/tests/fmig431/test_crop_tav_detailed_period_candidate.f90" -o "test$opt")
 "$TMP/test$opt" > "$TMP/out$opt"
 grep -Fx 'CROP_TAV_DETAILED_PERIOD_CANDIDATE=PASS' "$TMP/out$opt"
done
cmp "$TMP/out0" "$TMP/out2"
echo 'CROP_TAV_DETAILED_PERIOD_O0_O2=PASS'
