#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

OWNER_HEAD="2bc4ccb1cbedde8af60cd8390799373ed4310cb1"
PRODUCTION_PATH="src/runtime/mod_modflow6_api_binding.f90"
PRODUCTION_BLOB="780ed4bf3a8bdf067db40f4aedd800832144eca6"
BUILD="${TMPDIR:-/tmp}/fvq108-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

test "$(git rev-parse "HEAD:$PRODUCTION_PATH")" = "$PRODUCTION_BLOB"
test "$(git rev-parse "$OWNER_HEAD:$PRODUCTION_PATH")" = "$PRODUCTION_BLOB"
test -z "$(git diff --name-only "$OWNER_HEAD..HEAD" -- src)"
echo 'FVQ108_VERIFIER_PRODUCTION_DELTA_NONE=PASS'
echo 'FVQ108_OWNER_PRODUCTION_BLOB_LOCK=PASS'

python3 - <<'PY'
from pathlib import Path
v=Path('tests/fvq/test_fvq108_fgc34_independent.f90').read_text()
assert 'test_fgc34_modflow6_api_binding' not in v
assert 'permutation_shadow_oracle' in v
assert 'atomic_rejection_oracle' in v
print('FVQ108_OWNER_TEST_NOT_REUSED=PASS')
print('FVQ108_INDEPENDENT_ORACLE_STRUCTURE=PASS')
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
  dir="$BUILD/o$opt"; mkdir -p "$dir"
  gfortran "${COMMON[@]}" -O"$opt" -J "$dir" -I "$dir" "${SOURCES[@]}"     tests/fvq/test_fvq108_fgc34_independent.f90 -o "$dir/test"
  "$dir/test" > "$dir/out"
done

diff -u "$BUILD/o0/out" "$BUILD/o2/out"
cat "$BUILD/o0/out"
grep -q '^FVQ108_INDEPENDENT_API_BINDING_GATE=PASS$' "$BUILD/o0/out"
echo 'FVQ108_INDEPENDENT_O0_O2_IDENTITY=PASS'
echo 'F-VQ108 F-GC34 INDEPENDENT QUALIFICATION PASS'
