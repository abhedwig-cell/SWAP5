#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${TMPDIR:-/tmp}/swap5-fgc33-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

python3 - <<'PY'
from pathlib import Path
src = Path('src/runtime/mod_modflow6_linear_response_backend.f90').read_text().lower()
for token in [
    'hcof_m2_per_day',
    'rhs_m3_per_day',
    'reference_volume_flux_m3_per_day',
    'modflow6_multiswap_cell_response_t',
    'hcof * cell%reference_head_m - reference_volume_flux',
]:
    assert token in src, token
for forbidden in [
    'get_value_ptr',
    'nodelist',
    'xmiwrapper',
    'ribasim',
    'commit_candidate',
    'groundwater_commit',
]:
    assert forbidden not in src, forbidden
print('FGC33_PURE_LINEAR_BACKEND=PASS')
print('FGC33_NO_XMI_NODELIST_OR_COMMIT=PASS')
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
)

for opt in 0 2; do
  dir="$BUILD/o$opt"
  mkdir -p "$dir"
  if ! gfortran "${COMMON[@]}" -O"$opt" -J "$dir" -I "$dir" \
      "${SOURCES[@]}" tests/fgc/test_fgc33_modflow6_linear_response_backend.f90 \
      -o "$dir/test_fgc33" 2>"$dir/compiler.txt"; then
    echo "FGC33_COMPILE_O${opt}=FAIL" >&2
    cat "$dir/compiler.txt" >&2
    exit 30
  fi
  if grep -E 'Warning:' "$dir/compiler.txt" | grep -v -F '[-Wcompare-reals]'; then
    echo "FGC33_UNEXPECTED_WARNING_O${opt}=FAIL" >&2
    cat "$dir/compiler.txt" >&2
    exit 31
  fi
  "$dir/test_fgc33" > "$dir/output.txt"
done

diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o0/output.txt"

for marker in \
  FGC33_EXACT_HCOF_RHS_TRANSFORM \
  FGC33_REFERENCE_HEAD_CLOSURE \
  FGC33_SECOND_HEAD_CLOSURE \
  FGC33_REFERENCE_REPRESENTATION_INVARIANCE \
  FGC33_AREA_SCALING \
  FGC33_SIGN_PRESERVATION \
  FGC33_IDENTITY_NOT_NODE_INDEX \
  FGC33_FAIL_CLOSED \
  FGC33_LINEAR_RESPONSE_BACKEND_GATE; do
  grep -q "^${marker}=PASS$" "$BUILD/o0/output.txt"
done

echo 'FGC33_O0_O2_OUTPUT_IDENTITY=PASS'
echo 'F-GC33 MODFLOW6 LINEAR RESPONSE BACKEND GATE PASS'
