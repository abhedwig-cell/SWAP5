#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/ppa-wu05b8-low-air-source"
rm -rf "$BUILD";mkdir -p "$BUILD"
for opt in 0 2; do
 mkdir -p "$BUILD/o$opt"
 gfortran -std=f2008 -ffree-line-length-none -fcheck=all -ffpe-trap=invalid,zero,overflow -O"$opt" \
  -J "$BUILD/o$opt" -I "$BUILD/o$opt" \
  "$ROOT/tests/frost/test_ppa_wu05b5_corrected_drain_globals.f90" \
  "$ROOT/reference/swap-4.3.1/frost-corrections/FROST-GEOMETRY-01/frozencond.f90" \
  "$ROOT/src/process/mod_frost_bottom_boundary_effect.f90" \
  "$ROOT/src/process/mod_frost_drainage_effect.f90" \
  "$ROOT/src/process/mod_frost_geometry_effect.f90" \
  "$ROOT/src/process/mod_frost_low_air_drainage_effect.f90" \
  "$ROOT/tests/frost/test_ppa_wu05b8_low_air_source.f90" -o "$BUILD/o$opt/test"
 "$BUILD/o$opt/test" > "$BUILD/o$opt/output.txt"
 cat "$BUILD/o$opt/output.txt"
done
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'PPA_WU05B8_LOW_AIR_SOURCE_O0_O2_IDENTITY=PASS'
