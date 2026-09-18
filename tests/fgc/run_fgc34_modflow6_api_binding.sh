#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${TMPDIR:-/tmp}/swap5-fgc34-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

python3 - <<'PY'
from pathlib import Path
src = Path('src/runtime/mod_modflow6_api_binding.f90').read_text().lower()
for token in [
    'groundwater_cell_id',
    'package_slot',
    'modflow_node_id',
    'nodelist',
    'hcof',
    'rhs',
    'nbound',
    'validation above is intentionally complete before the first package write',
]:
    assert token in src, token
for forbidden in [
    'get_var_address',
    'get_value_ptr',
    'xmiwrapper',
    'prepare_time_step',
    'prepare_solve',
    'ribasim',
    'commit_candidate',
    'groundwater_commit',
]:
    assert forbidden not in src, forbidden
print('FGC34_TYPED_PACKAGE_BINDING=PASS')
print('FGC34_NO_XMI_SOLVE_OR_COMMIT=PASS')
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
)

for opt in 0 2; do
  dir="$BUILD/o$opt"
  mkdir -p "$dir"
  if ! gfortran "${COMMON[@]}" -O"$opt" -J "$dir" -I "$dir" \
      "${SOURCES[@]}" tests/fgc/test_fgc34_modflow6_api_binding.f90 \
      -o "$dir/test_fgc34" 2>"$dir/compiler.txt"; then
    echo "FGC34_COMPILE_O${opt}=FAIL" >&2
    cat "$dir/compiler.txt" >&2
    exit 30
  fi
  if grep -E 'Warning:' "$dir/compiler.txt" | grep -v -F '[-Wcompare-reals]'; then
    echo "FGC34_UNEXPECTED_WARNING_O${opt}=FAIL" >&2
    cat "$dir/compiler.txt" >&2
    exit 31
  fi
  "$dir/test_fgc34" > "$dir/output.txt"
done

diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o0/output.txt"

for marker in \
  FGC34_EXPLICIT_IDENTITY_MAPPING \
  FGC34_HCOF_RHS_PUBLICATION \
  FGC34_NBOUND_ACTIVE_PREFIX \
  FGC34_ORDER_INDEPENDENCE \
  FGC34_N_TO_1_NODE_PRESERVATION \
  FGC34_UNMAPPED_TAIL_PRESERVED \
  FGC34_ATOMIC_FAIL_CLOSED \
  FGC34_TYPED_API_BINDING_GATE; do
  grep -q "^${marker}=PASS$" "$BUILD/o0/output.txt"
done

echo 'FGC34_O0_O2_OUTPUT_IDENTITY=PASS'
echo 'F-GC34 MODFLOW6 TYPED API BINDING GATE PASS'
