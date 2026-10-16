#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="$(mktemp -d /tmp/swap5-frost-nan-independent-XXXXXX)"
trap 'rm -rf "$BUILD"' EXIT
for opt in 0 2; do
  mkdir "$BUILD/o$opt"
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror \
    -fcheck=all -ffpe-trap=invalid,zero,overflow -O"$opt" \
    -J "$BUILD/o$opt" -I "$BUILD/o$opt" \
    "$ROOT/src/process/mod_frost_hydraulic_effect.f90" \
    "$ROOT/tests/frost/test_frost_nan_guard_independent.f90" -o "$BUILD/o$opt/test"
  "$BUILD/o$opt/test" > "$BUILD/o$opt/output"
  cat "$BUILD/o$opt/output"
done
cmp "$BUILD/o0/output" "$BUILD/o2/output"
echo 'FROST_NAN_GUARD_INDEPENDENT_O0_O2_IDENTITY=PASS'
