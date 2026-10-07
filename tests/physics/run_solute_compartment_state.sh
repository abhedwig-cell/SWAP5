#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
for opt in -O0 -O2; do
  gfortran "$opt" -std=f2008 -ffree-line-length-none -fcheck=all \
    -ffpe-trap=invalid,zero,overflow \
    "$root/src/process/mod_solute_compartment_state.f90" \
    "$root/tests/physics/test_solute_compartment_state.f90" \
    -o "$work/test_solcomp"
  "$work/test_solcomp"
done
