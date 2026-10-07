#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cd "$work"

for opt in -O0 -O2; do
  gfortran "$opt" -std=f2008 -ffree-line-length-none -fcheck=all -ffpe-trap=invalid,zero,overflow     "$root/src/process/mod_soil_n_pool_state.f90"     "$root/src/process/mod_soil_n_reaction_transfer.f90"     "$root/tests/physics/test_soil_n_reaction_transfer.f90"     -o soil_n_reaction
  ./soil_n_reaction

  gfortran "$opt" -std=f2008 -ffree-line-length-none -fcheck=all -ffpe-trap=invalid,zero,overflow     "$root/src/process/mod_b111_soil_n_rate_factors.f90"     "$root/tests/physics/test_b111_soil_n_rate_factors.f90"     -o soil_n_rates
  ./soil_n_rates

  gfortran "$opt" -std=f2008 -ffree-line-length-none -fcheck=all -ffpe-trap=invalid,zero,overflow     "$root/src/process/mod_solute_compartment_state.f90"     "$root/tests/physics/test_solute_compartment_state.f90"     -o solute_compartments
  ./solute_compartments

  gfortran "$opt" -std=f2008 -ffree-line-length-none -fcheck=all -ffpe-trap=invalid,zero,overflow     "$root/src/process/mod_solute_mobile_salt_state.f90"     "$root/src/process/mod_solute_compartment_state.f90"     "$root/src/process/mod_solute_sorption_transfer.f90"     "$root/tests/physics/test_solute_sorption_transfer.f90"     -o solute_sorption
  ./solute_sorption
  gfortran "$opt" -std=f2008 -ffree-line-length-none -fcheck=all -ffpe-trap=invalid,zero,overflow \
    "$root/src/process/mod_b111_solute_sorption.f90" \
    "$root/src/process/mod_b111_solute_decay.f90" \
    "$root/tests/physics/test_b111_solute_sorption_decay.f90" \
    -o b111_sorp_decay
  ./b111_sorp_decay
  gfortran "$opt" -std=f2008 -ffree-line-length-none -fcheck=all -ffpe-trap=invalid,zero,overflow \
    "$root/src/process/mod_b111_pond_solute_exchange.f90" \
    "$root/src/process/mod_b111_age_tracer_production.f90" \
    "$root/tests/physics/test_b111_pond_age.f90" \
    -o b111_pond_age
  ./b111_pond_age
done
