#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${TMPDIR:-/tmp}/swap5-fgc49a-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

python3 - <<'PY'
from pathlib import Path
src=Path('src/runtime/mod_groundwater_application_plan.f90').read_text().lower()
for token in [
    'groundwater_application_plan_t',
    'groundwater_application_cell_plan_t',
    'materialize_groundwater_application_plan',
    'compose_modflow6_multiswap_cell_response',
    'compose_modflow6_linear_boundary_term',
    'modflow6_api_slot_binding_t',
    'groundwater_topology_t',
]:
    assert token in src, token
for forbidden in [
    'commit_candidate',
    'rollback_candidate',
    'prepare_solve',
    'finalize_solve',
    'finalize_time_step',
    'xmiwrapper',
    'kernel_executor_t',
    'corrector_trial',
    'solve_iteration',
    'finite_difference',
]:
    assert forbidden not in src, forbidden
print('FGC49A_PLAN_COMPOSITION_ONLY=PASS')
print('FGC49A_NO_SOLVER_TRANSACTION_OR_PUBLICATION_OWNERSHIP=PASS')
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
  src/runtime/mod_groundwater_application_plan.f90
)

for opt in 0 2; do
  dir="$BUILD/o$opt"
  mkdir -p "$dir"
  if ! gfortran "${COMMON[@]}" -O"$opt" -J "$dir" -I "$dir"       "${SOURCES[@]}" tests/fgc/test_fgc49a_groundwater_application_plan.f90       -o "$dir/test_fgc49a" 2>"$dir/compiler.txt"; then
    echo "FGC49A_COMPILE_O${opt}=FAIL" >&2
    cat "$dir/compiler.txt" >&2
    exit 30
  fi
  if grep -E 'Warning:' "$dir/compiler.txt" | grep -v -F '[-Wcompare-reals]'; then
    echo "FGC49A_UNEXPECTED_WARNING_O${opt}=FAIL" >&2
    cat "$dir/compiler.txt" >&2
    exit 31
  fi
  "$dir/test_fgc49a" > "$dir/output.txt"
done

diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o0/output.txt"

for marker in   FGC49A_FGC44_ONE_TO_ONE_PLAN   FGC49A_FGC45_N_TO_ONE_PLAN   FGC49A_FGC46_MULTICELL_PLAN   FGC49A_FGC47_MIXED_PLAN   FGC49A_INPUT_ORDER_INVARIANCE   FGC49A_FAIL_CLOSED_PROVENANCE_AND_AREA; do
  grep -q "^${marker}=PASS$" "$BUILD/o0/output.txt"
done

echo 'FGC49A_O0_O2_OUTPUT_IDENTITY=PASS'
echo 'F-GC49A APPLICATION PLAN GATE PASS'
