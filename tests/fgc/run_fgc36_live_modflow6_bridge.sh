#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${TMPDIR:-/tmp}/swap5-fgc36-$$"
mkdir -p "$BUILD/modflow-bin" "$BUILD/downloads" "$BUILD/bridge"
trap 'rm -rf "$BUILD"' EXIT

python3 - <<'PY'
import ast
from pathlib import Path

bridge = Path("src/adapter/mod_modflow6_fgc34_c_bridge.f90").read_text().lower()
assert "call publish_modflow6_api_terms" in bridge
assert 'bind(c, name="fgc34_publish_c")' in bridge
for forbidden in [
    "prepare_time_step",
    "prepare_solve",
    "solve(",
    "ribasim",
    "groundwater_commit",
]:
    assert forbidden not in bridge, forbidden

publisher = Path("src/adapter/modflow6_fgc34_ctypes_publisher.py").read_text()
tree = ast.parse(publisher)
for forbidden in ["prepare_time_step", "prepare_solve", "solve", "finalize_time_step"]:
    assert forbidden not in publisher, forbidden

print("FGC36_REAL_FGC34_BRIDGE_SYMBOL=PASS")
print("FGC36_PRODUCTION_ADAPTER_NO_SOLVE_OWNERSHIP=PASS")
PY

python3 - <<PY
from pathlib import Path
from flopy.utils.get_modflow import run_main

bindir = Path("$BUILD/modflow-bin")
downloads = Path("$BUILD/downloads")
run_main(
    bindir,
    owner="MODFLOW-ORG",
    repo="modflow6",
    release_id="6.8.0",
    subset={"mf6", "libmf6.so"},
    downloads_dir=downloads,
    force=True,
    quiet=False,
)
PY

ARCHIVE="$BUILD/downloads/modflow6-6.8.0-linux.zip"
echo "33edf988b672a9f282d6773304c079d0f180541f6fe0c6555265d9c71841256e  $ARCHIVE" | sha256sum -c -
test -x "$BUILD/modflow-bin/mf6"
test -f "$BUILD/modflow-bin/libmf6.so"
echo 'FGC36_MODFLOW680_ASSET_SHA256=PASS'

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

gfortran "${COMMON[@]}" -shared -J "$BUILD/bridge" -I "$BUILD/bridge" \
  "${SOURCES[@]}" -o "$BUILD/bridge/libfgc34_bridge.so"

nm -D "$BUILD/bridge/libfgc34_bridge.so" | grep -q 'fgc34_publish_c'
echo 'FGC36_FGC34_SHARED_BRIDGE_BUILD=PASS'

LIBMF6="$BUILD/modflow-bin/libmf6.so" \
FGC34_BRIDGE_LIB="$BUILD/bridge/libfgc34_bridge.so" \
python3 tests/fgc/test_fgc36_live_modflow6_bridge.py

echo 'F-GC36 LIVE MODFLOW6 F-GC34 BRIDGE GATE PASS'
