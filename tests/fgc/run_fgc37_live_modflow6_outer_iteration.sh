#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${TMPDIR:-/tmp}/swap5-fgc37-$$"
mkdir -p "$BUILD/modflow-bin" "$BUILD/downloads" "$BUILD/bridge"
trap 'rm -rf "$BUILD"' EXIT

python3 - <<'PY'
import ast
from pathlib import Path

host = Path("src/adapter/modflow6_outer_iteration_host.py").read_text()
tree = ast.parse(host)

for forbidden in [
    "ribasim",
    "groundwater_commit_prepared",
    "groundwater_prepare_candidate",
    "commit_candidate(" + "executor",
]:
    assert forbidden not in host.lower(), forbidden

assert "prepare_time_step" in host
assert "prepare_solve" in host
assert "finalize_solve" in host
assert "finalize_time_step" in host
assert "refresh_after_prepare_time_step" in host
assert "_republish_current_generation" in host

# No pointer reacquisition in the iteration republisher.
republisher = next(
    node for node in tree.body
    if isinstance(node, ast.ClassDef) and node.name == "Modflow6OuterIterationHost"
)
fn = next(
    node for node in republisher.body
    if isinstance(node, ast.FunctionDef) and node.name == "_republish_current_generation"
)
segment = ast.get_source_segment(host, fn)
assert "get_value_ptr" not in segment
assert "get_var_address" not in segment
assert "refresh_after_prepare_time_step" not in segment

print("FGC37_NO_FAKE_MODFLOW_ROLLBACK=PASS")
print("FGC37_ITERATION_REPUBLISH_NO_POINTER_REACQUISITION=PASS")
print("FGC37_NO_RIBASIM_OR_SWAP_COMMIT_OWNERSHIP=PASS")
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
echo 'FGC37_MODFLOW680_ASSET_SHA256=PASS'

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
echo 'FGC37_REAL_FGC34_SHARED_BRIDGE=PASS'

LIBMF6="$BUILD/modflow-bin/libmf6.so" \
FGC34_BRIDGE_LIB="$BUILD/bridge/libfgc34_bridge.so" \
python3 tests/fgc/test_fgc37_live_modflow6_outer_iteration.py

echo 'F-GC37 LIVE MODFLOW6 OUTER ITERATION HOST GATE PASS'
