#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${TMPDIR:-/tmp}/swap5-fvq121-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SOURCES=(
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_groundwater_interface_mass_ledger.f90
  src/runtime/mod_groundwater_tile_aggregation.f90
  src/runtime/mod_groundwater_multiswap_types.f90
  src/runtime/mod_modflow6_swap_predictor_response.f90
  src/runtime/mod_modflow6_multiswap_cell_response.f90
  src/runtime/mod_modflow6_linear_response_backend.f90
  src/runtime/mod_modflow6_api_binding.f90
  src/runtime/mod_groundwater_topology_composition.f90
  src/runtime/mod_groundwater_application_plan.f90
)

for opt in 0 2; do
  dir="$BUILD/o$opt"
  mkdir -p "$dir"
  gfortran "${COMMON[@]}" -O"$opt" -J "$dir" -I "$dir"     "${SOURCES[@]}" tests/fvq/test_fvq121_fgc49a_application_plan_independent.f90     -o "$dir/test_fvq121"
  "$dir/test_fvq121" > "$dir/output.txt"
done

diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o0/output.txt"

for marker in   FVQ121_PLAN_EQUALS_DIRECT_FGC40_FGC33   FVQ121_MIXED_CELL1_N1_EQUIVALENCE   FVQ121_MIXED_CELL2_1TO1_EQUIVALENCE   FVQ121_PLAN_TO_FGC34_PUBLICATION   FVQ121_API_SLOT_NODE_AND_TERM_IDENTITY   FVQ121_UNMAPPED_API_TAIL_PRESERVED; do
  grep -q "^${marker}=PASS$" "$BUILD/o0/output.txt"
done

echo 'FVQ121_O0_O2_OUTPUT_IDENTITY=PASS'
echo 'F-VQ121 F-GC49A INDEPENDENT QUALIFICATION PASS'
