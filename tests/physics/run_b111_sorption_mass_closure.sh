#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
cd "$BUILD"
for OPT in O0 O2; do
  gfortran "-$OPT" -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror \
    -fcheck=all -ffpe-trap=invalid,zero,overflow \
    "$ROOT/src/process/mod_b111_solute_sorption.f90" \
    "$ROOT/tests/physics/test_b111_sorption_mass_closure.f90" \
    -o "test_$OPT"
  "./test_$OPT"
done
