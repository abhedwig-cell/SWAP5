#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
build_root="${TMPDIR:-/tmp}/ppa-wu05b-frost-effect"
mkdir -p "$build_root"

for opt in 0 2; do
  exe="$build_root/test_ppa_wu05b_frost_effect_O${opt}"
  gfortran -std=f2008 -Wall -Wextra -Werror -Wno-error=compare-reals -Wno-error=unused-dummy-argument \
    -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -O"$opt" -J"$build_root" -I"$build_root" \
    "$repo_root/src/solver/mod_soil_water_solver_contract.f90" \
    "$repo_root/src/process/mod_frost_hydraulic_effect.f90" \
    "$repo_root/src/solver/mod_frost_hydraulic_provider.f90" \
    "$repo_root/tests/frost/test_ppa_wu05b_frost_effect.f90" -o "$exe"
  "$exe"
  provider_exe="$build_root/test_ppa_wu05b_frost_provider_O${opt}"
  gfortran -std=f2008 -Wall -Wextra -Werror -Wno-error=compare-reals -Wno-error=unused-dummy-argument \
    -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -O"$opt" -J"$build_root" -I"$build_root" \
    "$repo_root/src/solver/mod_soil_water_solver_contract.f90" \
    "$repo_root/src/process/mod_frost_hydraulic_effect.f90" \
    "$repo_root/src/solver/mod_frost_hydraulic_provider.f90" \
    "$repo_root/tests/frost/test_ppa_wu05b_frost_provider.f90" -o "$provider_exe"
  "$provider_exe"
done
