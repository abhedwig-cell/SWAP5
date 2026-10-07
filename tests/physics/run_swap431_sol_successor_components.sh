#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cd "$work"

for opt in -O0 -O2; do
  gfortran "$opt" -std=f2008 -ffree-line-length-none -fcheck=all -ffpe-trap=invalid,zero,overflow     "$root/src/process/mod_solute_mobile_salt_state.f90"     "$root/src/process/mod_solute_compartment_state.f90"     "$root/src/process/mod_solute_decay_transfer.f90"     "$root/tests/physics/test_solute_decay_transfer.f90"     -o solute_decay_transfer
  ./solute_decay_transfer

  gfortran "$opt" -std=f2008 -ffree-line-length-none -fcheck=all -ffpe-trap=invalid,zero,overflow     "$root/src/process/mod_solute_mobile_salt_state.f90"     "$root/src/process/mod_solute_compartment_state.f90"     "$root/src/process/mod_solute_pond_matrix_transfer.f90"     "$root/tests/physics/test_solute_pond_matrix_transfer.f90"     -o solute_pond_matrix
  ./solute_pond_matrix
  gfortran "$opt" -std=f2008 -ffree-line-length-none -fcheck=all -ffpe-trap=invalid,zero,overflow \
    "$root/src/process/mod_solute_mobile_salt_state.f90" \
    "$root/src/process/mod_solute_compartment_state.f90" \
    "$root/src/process/mod_b111_solute_sorption.f90" \
    "$root/src/process/mod_b111_solute_sorption_partition.f90" \
    "$root/tests/physics/test_b111_solute_sorption_partition.f90" \
    -o sorption_partition
  ./sorption_partition
done
