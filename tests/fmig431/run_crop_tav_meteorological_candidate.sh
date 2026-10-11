#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
for opt in 0 2; do
 gfortran -std=f2008 -fcheck=all -ffree-line-length-none -Werror -Wno-error=compare-reals -O"$opt" \
  "$ROOT/src/crop/mod_crop_tav_meteorological_candidate.f90" \
  "$ROOT/tests/fmig431/test_crop_tav_meteorological_candidate.f90" -o "$BUILD/test$opt"
 "$BUILD/test$opt" > "$BUILD/out$opt"
 grep -Fx 'SW431_CROP_TAV_METEO_CANDIDATE=PASS' "$BUILD/out$opt"
done
cmp "$BUILD/out0" "$BUILD/out2"
echo 'SW431_CROP_TAV_METEO_CANDIDATE_O0_O2=PASS'
