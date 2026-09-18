#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${TMPDIR:-/tmp}/swap5-fgc48-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

python3 - <<'PY'
from pathlib import Path
src=Path('src/runtime/mod_groundwater_topology_composition.f90').read_text().lower()
for token in [
    'groundwater_topology_tile_t',
    'groundwater_topology_cell_t',
    'groundwater_topology_t',
    'materialize_groundwater_topology',
    'groundwater_direct_tile_binding_t',
    'modflow6_api_slot_binding_t',
    'sort_tiles_by_cell_then_tile',
    'sort_cells_by_id',
    'gw_topology_fraction_sum',
]:
    assert token in src, token
for forbidden in [
    'commit_candidate',
    'prepare_solve',
    'finalize_time_step',
    'xmiwrapper',
    'ribasim',
    'corrector_trial',
    'build_predictor',
    'finite_difference',
]:
    assert forbidden not in src, forbidden
print('FGC48_TYPED_TOPOLOGY_ONLY=PASS')
print('FGC48_NO_SOLVER_TRANSACTION_OR_PHYSICS_OWNERSHIP=PASS')
PY

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
)

for opt in 0 2; do
  dir="$BUILD/o$opt"
  mkdir -p "$dir"
  if ! gfortran "${COMMON[@]}" -O"$opt" -J "$dir" -I "$dir"       "${SOURCES[@]}" tests/fgc/test_fgc48_generic_groundwater_topology.f90       -o "$dir/test_fgc48" 2>"$dir/compiler.txt"; then
    echo "FGC48_COMPILE_O${opt}=FAIL" >&2
    cat "$dir/compiler.txt" >&2
    exit 30
  fi
  if grep -E 'Warning:' "$dir/compiler.txt" | grep -v -F '[-Wcompare-reals]'; then
    echo "FGC48_UNEXPECTED_WARNING_O${opt}=FAIL" >&2
    cat "$dir/compiler.txt" >&2
    exit 31
  fi
  "$dir/test_fgc48" > "$dir/output.txt"
done

diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o0/output.txt"

for marker in   FGC48_FGC45_N1_TOPOLOGY_REGRESSION   FGC48_FGC46_MULTICELL_TOPOLOGY_REGRESSION   FGC48_FGC47_MIXED_TOPOLOGY_REGRESSION   FGC48_CANONICAL_ORDER_INVARIANCE   FGC48_GLOBAL_OWNERSHIP_FAIL_CLOSED   FGC48_PER_CELL_FRACTION_CLOSURE   FGC48_API_SLOT_NODE_MAPPING; do
  grep -q "^${marker}=PASS$" "$BUILD/o0/output.txt"
done

echo 'FGC48_O0_O2_OUTPUT_IDENTITY=PASS'
echo 'F-GC48 GENERIC GROUNDWATER TOPOLOGY GATE PASS'
