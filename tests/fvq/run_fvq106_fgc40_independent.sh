#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
OWNER_HEAD="7993c143eaa1cf8d6580fdd7bde0ae05b07b5b4d"
BLOB="288a274612f6c0be0b3ced149028066a066908ca"
BUILD="${TMPDIR:-/tmp}/fvq106-$$"; mkdir -p "$BUILD"; trap 'rm -rf "$BUILD"' EXIT

test "$(git rev-parse "HEAD:src/runtime/mod_modflow6_multiswap_cell_response.f90")" = "$BLOB"
test "$(git rev-parse "$OWNER_HEAD:src/runtime/mod_modflow6_multiswap_cell_response.f90")" = "$BLOB"
test -z "$(git diff --name-only "$OWNER_HEAD..HEAD" -- 'src/**')"
echo 'FVQ106_VERIFIER_PRODUCTION_DELTA_NONE=PASS'
echo 'FVQ106_OWNER_PRODUCTION_BLOB_LOCK=PASS'

python3 - <<'PY'
from pathlib import Path
v=Path('tests/fvq/test_fvq106_fgc40_independent.f90').read_text()
assert 'test_fgc40_modflow6_multiswap_cell_response' not in v
assert 'direct_sum' in v and 'permutation_oracle' in v
print('FVQ106_OWNER_TEST_NOT_REUSED=PASS')
print('FVQ106_INDEPENDENT_ORACLE_STRUCTURE=PASS')
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
 d="$BUILD/o$opt"; mkdir -p "$d"
 gfortran "${COMMON[@]}" -O"$opt" -J "$d" -I "$d" "${SOURCES[@]}"    tests/fvq/test_fvq106_fgc40_independent.f90 -o "$d/test"
 "$d/test" > "$d/out"
done
diff -u "$BUILD/o0/out" "$BUILD/o2/out"
cat "$BUILD/o0/out"
grep -q '^FVQ106_INDEPENDENT_CELL_RESPONSE_GATE=PASS$' "$BUILD/o0/out"
echo 'FVQ106_INDEPENDENT_O0_O2_IDENTITY=PASS'
echo 'F-VQ106 F-GC40 INDEPENDENT QUALIFICATION PASS'
