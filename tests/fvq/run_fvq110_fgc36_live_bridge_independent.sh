#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

OWNER_HEAD="8d6f723d4de9b3cc47bb5012b67237aa7fc8febb"
C_BRIDGE_BLOB="5c5577715c9c150f72de7bfccaf966cd72db5add"
PY_PUBLISHER_BLOB="ccf16f446ae9aaab34dae6f432082d70569faad9"
BUILD="${TMPDIR:-/tmp}/swap5-fvq110-$$"
mkdir -p "$BUILD/modflow-bin" "$BUILD/downloads" "$BUILD/bridge"
trap 'rm -rf "$BUILD"' EXIT

test "$(git rev-parse HEAD:src/adapter/mod_modflow6_fgc34_c_bridge.f90)" = "$C_BRIDGE_BLOB"
test "$(git rev-parse HEAD:src/adapter/modflow6_fgc34_ctypes_publisher.py)" = "$PY_PUBLISHER_BLOB"
test "$(git rev-parse "$OWNER_HEAD:src/adapter/mod_modflow6_fgc34_c_bridge.f90")" = "$C_BRIDGE_BLOB"
test "$(git rev-parse "$OWNER_HEAD:src/adapter/modflow6_fgc34_ctypes_publisher.py")" = "$PY_PUBLISHER_BLOB"
test -z "$(git diff --name-only "$OWNER_HEAD..HEAD" -- src)"
echo 'FVQ110_VERIFIER_PRODUCTION_DELTA_NONE=PASS'
echo 'FVQ110_OWNER_BRIDGE_BLOBS_LOCKED=PASS'

python3 - <<'PY'
from pathlib import Path
v=Path("tests/fvq/test_fvq110_fgc36_live_bridge_independent.py").read_text()
assert "test_fgc36_live_modflow6_bridge" not in v
assert "ncol=4" in v
assert "np.linalg.solve" in v
print("FVQ110_OWNER_TEST_NOT_REUSED=PASS")
print("FVQ110_DISTINCT_TWO_SLOT_ORACLE=PASS")
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
echo 'FVQ110_MODFLOW680_ASSET_SHA256=PASS'

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
echo 'FVQ110_REAL_FGC34_BRIDGE_BUILD=PASS'

LIBMF6="$BUILD/modflow-bin/libmf6.so" FGC34_BRIDGE_LIB="$BUILD/bridge/libfgc34_bridge.so" python3 tests/fvq/test_fvq110_fgc36_live_bridge_independent.py

echo 'F-VQ110 F-GC36 INDEPENDENT LIVE QUALIFICATION PASS'
