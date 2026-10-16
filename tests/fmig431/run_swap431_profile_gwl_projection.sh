#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FC="${FC:-gfortran}"
for opt in O0 O2; do
  tmp="$(mktemp -d)"
  "$FC" "-$opt" -std=f2008 -ffree-line-length-none -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -J"$tmp" -I"$tmp" \
    "$ROOT/src/solver/mod_b111_profile_groundwater_projection.f90" \
    "$ROOT/tests/fmig431/test_swap431_profile_gwl_projection.f90" -o "$tmp/test"
  out="$("$tmp/test")"
  test "$out" = "SW431-GW-PROJECTION-COMPONENT=PASS"
  echo "$opt $out"
  rm -rf "$tmp"
done
