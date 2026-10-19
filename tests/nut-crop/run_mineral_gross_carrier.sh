#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
build="$(mktemp -d)"
trap 'rm -rf "$build"' EXIT
for opt in 0 2; do
 mkdir -p "$build/o$opt"
 gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all \
   -ffpe-trap=invalid,zero,overflow -O"$opt" -J "$build/o$opt" -I "$build/o$opt" \
   src/process/mod_soil_n_pool_state.f90 \
   src/process/mod_b111_soil_n_storage_conversion.f90 \
   src/process/mod_b111_soil_n_transport.f90 \
   src/process/mod_b111_soil_n_mineral_owner.f90 \
   tests/nut-crop/test_mineral_gross_carrier.f90 -o "$build/o$opt/test"
 "$build/o$opt/test" > "$build/o$opt/output"
 grep -Fq 'MC_NUT01_MINERAL_GROSS_SOURCE_O0_O2=PASS' "$build/o$opt/output"
 echo "MC_NUT01_MINERAL_GROSS_CARRIER_O$opt=PASS"
done
cmp "$build/o0/output" "$build/o2/output"
