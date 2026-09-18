#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

OWNER_HEAD="9f903a2febb905316fab3d6b577c0d4a6f904a7c"
PRODUCTION_PATH="src/adapter/modflow6_prepared_solve_session.py"
PRODUCTION_BLOB="d26a11b292c114083d4de15c32f0a56fc45db833"
BUILD="${TMPDIR:-/tmp}/swap5-fvq111-$$"
mkdir -p "$BUILD/modflow-bin" "$BUILD/downloads" "$BUILD/bridge"
trap 'rm -rf "$BUILD"' EXIT

test "$(git rev-parse "HEAD:$PRODUCTION_PATH")" = "$PRODUCTION_BLOB"
test "$(git rev-parse "$OWNER_HEAD:$PRODUCTION_PATH")" = "$PRODUCTION_BLOB"
test -z "$(git diff --name-only "$OWNER_HEAD..HEAD" -- src)"
echo 'FVQ111_VERIFIER_PRODUCTION_DELTA_NONE=PASS'
echo 'FVQ111_OWNER_PRODUCTION_BLOB_LOCK=PASS'

python3 - <<'PY'
from pathlib import Path
v=Path("tests/fvq/test_fvq111_fgc38_prepared_solve_independent.py").read_text()
assert "test_fgc38_live_prepared_solve" not in v
assert "maxbound=2" in v
assert "response_sequence" in v
assert "clean_head" in v
print("FVQ111_OWNER_TEST_NOT_REUSED=PASS")
print("FVQ111_DISTINCT_TWO_SLOT_ITERATIVE_ORACLE=PASS")
PY

python3 - <<PY
from pathlib import Path
from flopy.utils.get_modflow import run_main
run_main(
    Path("$BUILD/modflow-bin"),
    owner="MODFLOW-ORG",
    repo="modflow6",
    release_id="6.8.0",
    subset={"mf6", "libmf6.so"},
    downloads_dir=Path("$BUILD/downloads"),
    force=True,
    quiet=False,
)
PY

ARCHIVE="$BUILD/downloads/modflow6-6.8.0-linux.zip"
echo "33edf988b672a9f282d6773304c079d0f180541f6fe0c6555265d9c71841256e  $ARCHIVE" | sha256sum -c -
echo 'FVQ111_MODFLOW680_ASSET_SHA256=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -fPIC -Wall -Wextra -Werror -Wno-error=compare-reals)
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
  src/adapter/mod_modflow6_fgc34_c_bridge.f90
)

gfortran "${COMMON[@]}" -shared -J "$BUILD/bridge" -I "$BUILD/bridge"   "${SOURCES[@]}" -o "$BUILD/bridge/libfgc34_bridge.so"

nm -D "$BUILD/bridge/libfgc34_bridge.so" | grep -q 'fgc34_publish_c'
echo 'FVQ111_REAL_FGC34_BRIDGE_BUILD=PASS'

LIBMF6="$BUILD/modflow-bin/libmf6.so" FGC34_BRIDGE_LIB="$BUILD/bridge/libfgc34_bridge.so" python3 tests/fvq/test_fvq111_fgc38_prepared_solve_independent.py

echo 'F-VQ111 F-GC38 INDEPENDENT PREPARED-SOLVE QUALIFICATION PASS'
