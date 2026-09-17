#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${TMPDIR:-/tmp}/swap5-fgc31-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

python3 - <<'PY'
from pathlib import Path
src = Path('src/runtime/mod_modflow6_multiswap_cell_response.f90').read_text().lower()
for token in [
    'reference_head_m',
    'q_u_at_reference_m_per_s',
    'coupling_storage_coefficient_u',
    'dq_u_dh_per_s',
    'modflow6_swap_predictor_response_t',
    'groundwater_direct_tile_binding_t',
]:
    assert token in src, token
for forbidden in [
    'commit_candidate',
    'groundwater_trial_from_checkpoint',
    'groundwater_commit',
    'ribasim',
    'xmiwrapper',
]:
    assert forbidden not in src, forbidden
print('FGC31_NONCOMMITTING_CELL_COMPOSER=PASS')
print('FGC31_NO_MODFLOW_BACKEND_OR_RIBASIM=PASS')
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
)

for opt in 0 2; do
  dir="$BUILD/o$opt"
  mkdir -p "$dir"
  if ! gfortran "${COMMON[@]}" -O"$opt" -J "$dir" -I "$dir" \
      "${SOURCES[@]}" tests/fgc/test_fgc31_modflow6_multiswap_cell_response.f90 \
      -o "$dir/test_fgc31" 2>"$dir/compiler.txt"; then
    echo "FGC31_COMPILE_O${opt}=FAIL" >&2
    cat "$dir/compiler.txt" >&2
    exit 30
  fi
  if grep -E 'Warning:' "$dir/compiler.txt" | grep -v -F '[-Wcompare-reals]'; then
    echo "FGC31_UNEXPECTED_WARNING_O${opt}=FAIL" >&2
    cat "$dir/compiler.txt" >&2
    exit 31
  fi
  "$dir/test_fgc31" > "$dir/output.txt"
done

diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o0/output.txt"

for marker in \
  FGC31_SINGLE_TILE_EQUIVALENCE \
  FGC31_HETEROGENEOUS_AFFINE_CLOSURE \
  FGC31_REFERENCE_HEAD_RECONCILIATION \
  FGC31_AREA_WEIGHTED_U \
  FGC31_PERMUTATION_DETERMINISM \
  FGC31_CANONICAL_TILE_PROVENANCE \
  FGC31_PROVENANCE_FAIL_CLOSED \
  FGC31_CELL_RESPONSE_CONTRACT_GATE; do
  grep -q "^${marker}=PASS$" "$BUILD/o0/output.txt"
done

echo 'FGC31_O0_O2_OUTPUT_IDENTITY=PASS'
echo 'F-GC31 MULTISWAP MODFLOW6 CELL RESPONSE GATE PASS'
