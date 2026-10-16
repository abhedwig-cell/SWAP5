#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
for OPT in 0 2; do
  mkdir -p "$BUILD/O$OPT"
  cd "$BUILD/O$OPT"
  for file in \
    src/crop/mod_crop_rotation_calendar.f90 \
    src/crop/mod_crop_rotation_transition.f90 \
    src/crop/mod_crop_rotation_lifecycle_preflight.f90; do
    gfortran -O"$OPT" -std=f2008 -ffree-line-length-none -fcheck=all \
      -ffpe-trap=invalid,zero,overflow -c "$ROOT/$file"
  done
  gfortran -O"$OPT" -std=f2008 -ffree-line-length-none -fcheck=all \
    -ffpe-trap=invalid,zero,overflow "$ROOT/tests/fmig431/test_crop_lifecycle_preflight.f90" ./*.o -o check
  ./check > "$BUILD/O$OPT.txt"
done
cmp "$BUILD/O0.txt" "$BUILD/O2.txt"
grep -Fxq SW431_CROP_LIFECYCLE_PREFLIGHT=PASS "$BUILD/O0.txt"
echo SW431_CROP_LIFECYCLE_PREFLIGHT_O0_O2=PASS
