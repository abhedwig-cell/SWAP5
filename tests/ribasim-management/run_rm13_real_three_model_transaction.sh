#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rm13-triangle-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/modflow-bin" "$BUILD/downloads" "$BUILD/bridge"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "RM13_FAIL $*" >&2; exit 1; }

MODFLOW_ARCHIVE="$BUILD/downloads/mf6.8.0_linux.zip"
MODFLOW_RELEASE_DIR="$BUILD/modflow-release"
curl -L --fail --retry 3 \
  https://github.com/MODFLOW-ORG/modflow6/releases/download/6.8.0/mf6.8.0_linux.zip \
  -o "$MODFLOW_ARCHIVE"
echo "33edf988b672a9f282d6773304c079d0f180541f6fe0c6555265d9c71841256e  $MODFLOW_ARCHIVE" | \
  sha256sum -c - || fail "MODFLOW 6.8.0 release asset hash"
mkdir -p "$MODFLOW_RELEASE_DIR"
unzip -q "$MODFLOW_ARCHIVE" -d "$MODFLOW_RELEASE_DIR"
LIBMF6_SOURCE="$(find "$MODFLOW_RELEASE_DIR" -type f -name 'libmf6.so' -print -quit)"
MF6_SOURCE="$(find "$MODFLOW_RELEASE_DIR" -type f -name 'mf6' -perm -u+x -print -quit)"
test -n "$LIBMF6_SOURCE" -a -f "$LIBMF6_SOURCE" || fail "missing libmf6.so in official MODFLOW release"
test -n "$MF6_SOURCE" -a -f "$MF6_SOURCE" || fail "missing mf6 in official MODFLOW release"
cp "$LIBMF6_SOURCE" "$BUILD/modflow-bin/libmf6.so"
cp "$MF6_SOURCE" "$BUILD/modflow-bin/mf6"
chmod +x "$BUILD/modflow-bin/mf6"
echo "RM13_MODFLOW680_RELEASE_BINARY=PASS sha256=33edf988b672a9f282d6773304c079d0f180541f6fe0c6555265d9c71841256e"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fPIC -fopenmp)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/process/mod_tcs1_dcs2_sprinkling_irrigation_process.f90
  src/process/mod_rutter_interception_process.f90
  src/runtime/mod_fmr_hupsel_management_transaction.f90
  src/runtime/mod_fmr_ribasim_management_binding.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/runtime/mod_fmr_top_sensible_boundary_carrier.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/process/mod_drainage_process.f90
  src/process/mod_drainage_tabulated_response.f90
  src/process/mod_drainage_hooghoudt_equivalent_depth.f90
  src/process/mod_drainage_hooghoudt_ipos1_response.f90
  src/process/mod_drainage_hooghoudt_ipos23_response.f90
  src/process/mod_drainage_ernst_ipos45_preparation.f90
  src/process/mod_drainage_ernst_ipos45_response.f90
  src/process/mod_drainage_empirical_interflow_response.f90
  src/process/mod_drainage_multilevel_aggregation.f90
  src/runtime/mod_fmr_drainage_response_binding.f90
  src/solver/mod_b110_smooth_freatic_projection.f90
  src/runtime/mod_fmr_drainage_qbot_directional_binding.f90
  src/process/mod_soil_temperature_contract.f90
  src/process/mod_restricted_soil_temperature.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_default_mvg_directional_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/adapter/mod_reference_richards_accepted_step_directional_service.f90
  src/process/mod_snow_process.f90
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/runtime/mod_fmr_soil_water_application_host.f90
  src/runtime/mod_rossfast_d3r_execution_policy.f90
  src/runtime/mod_rossfast_d3r_model_binding.f90
  src/solver/mod_rossfast_d3r_table_kernel.f90
  src/solver/mod_rossfast_d3r_table_provider.f90
  src/solver/mod_rossfast_d3r_soil_water_solver.f90
  src/runtime/mod_fmr_rossfast_solver_selection_binding.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_groundwater_swap_forcing_adapter.f90
  src/runtime/mod_groundwater_swap_transaction_participant.f90
  src/runtime/mod_fmr_groundwater_head_forcing_adapter.f90
  src/runtime/mod_fmr_groundwater_swap_participant.f90
  src/runtime/mod_groundwater_interface_mass_ledger.f90
  src/runtime/mod_groundwater_tile_aggregation.f90
  src/runtime/mod_groundwater_multiswap_types.f90
  src/runtime/mod_modflow6_swap_predictor_response.f90
  src/runtime/mod_modflow6_swap_prescribed_qbot_bottom_face.f90
  src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90
  src/runtime/mod_modflow6_swap_predictor_origin.f90
  src/runtime/mod_modflow6_swap_predictor_candidate_assembler.f90
  src/runtime/mod_modflow6_multiswap_cell_response.f90
  src/runtime/mod_modflow6_linear_response_backend.f90
  src/runtime/mod_modflow6_api_binding.f90
  src/adapter/mod_modflow6_fgc34_c_bridge.f90
  tests/fgc/support/mod_fgc44_real_swap_c_bridge.f90
  tests/ribasim-management/support/mod_rm13_management_c_bridge.f90
)
objects=()
for source in "${MODULE_SRC[@]}"; do
  obj="$BUILD/bridge/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -O2 -J "$BUILD/bridge" -I "$BUILD/bridge" -c "$source" -o "$obj" || fail "compile $source"
  objects+=("$obj")
done
gfortran -shared -fopenmp -O2 "${objects[@]}" -o "$BUILD/bridge/libfgc44_swap.so" || fail "link F-GC44 shared library"
nm -D "$BUILD/bridge/libfgc44_swap.so" | grep -q 'fgc44_swap_initialize_c' || fail "missing SWAP C ABI"
nm -D "$BUILD/bridge/libfgc44_swap.so" | grep -q 'fgc34_publish_c' || fail "missing F-GC34 publisher C ABI"

RIBASIM_ROOT="${RM13_RIBASIM_ROOT:-$ROOT/.ribasim-product-release}"
RIBASIM_PIN=e7fc8ade52a4bedeec10e508d2065577f33eb76a
test -d "$RIBASIM_ROOT/.git" || fail "Ribasim exact-release checkout missing"
ACTUAL_PIN="$(git -C "$RIBASIM_ROOT" rev-parse HEAD)"
test "$ACTUAL_PIN" = "$RIBASIM_PIN" || fail "Ribasim pin mismatch: $ACTUAL_PIN"
echo "RM13_RIBASIM_PRODUCT_PIN=PASS sha=$ACTUAL_PIN"

MODEL_DIR="$RIBASIM_ROOT/generated_testmodels/swap5_rm13"
(
  cd "$RIBASIM_ROOT"
  pixi run python "$ROOT/tests/ribasim-management/generate_rm13_real_ribasim.py" "$MODEL_DIR"
)

RIBASIM_RELEASE_ZIP="$BUILD/ribasim_linux.zip"
RIBASIM_RELEASE_DIR="$BUILD/ribasim-release"
curl -L --fail --retry 3   https://github.com/Deltares/Ribasim/releases/download/v2026.1.1/ribasim_linux.zip   -o "$RIBASIM_RELEASE_ZIP"
echo "2ebff0f4ed600660640b5828bffee861380a7f41468bff75124ef7a831815139  $RIBASIM_RELEASE_ZIP" |   sha256sum -c - || fail "Ribasim v2026.1.1 release asset hash"
mkdir -p "$RIBASIM_RELEASE_DIR"
unzip -q "$RIBASIM_RELEASE_ZIP" -d "$RIBASIM_RELEASE_DIR"
LIBRIBASIM="$RIBASIM_RELEASE_DIR/ribasim/lib/libribasim.so"
test -f "$LIBRIBASIM" || fail "official v2026.1.1 libribasim missing from release asset"
echo "RM13_RIBASIM_RELEASE_BINARY=PASS sha256=2ebff0f4ed600660640b5828bffee861380a7f41468bff75124ef7a831815139"

LIBMF6="$BUILD/modflow-bin/libmf6.so" \
RM13_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
RM13_RIBASIM_ROOT="$RIBASIM_ROOT" \
RM13_RIBASIM_MODEL="$MODEL_DIR/ribasim.toml" \
RM13_LIBRIBASIM="$LIBRIBASIM" \
python3 tests/ribasim-management/test_rm13_real_three_model_transaction.py | tee "$BUILD/triangle.txt"

for marker in \
  'RM13_RIBASIM_REJECT_REPLAY=PASS' \
  'RM13_MANAGEMENT_REJECT_REPLAY=PASS' \
  'RM13_RICHARDS_MODFLOW_REJECT_REPLAY=PASS' \
  'RM13_SURFACE_WATER_LEDGER=PASS' \
  'RM13_GROUNDWATER_LEDGER=PASS' \
  'RM13_EXACTLY_ONCE_SWAPP_PUBLICATION=PASS' \
  'RM13 REAL SWAP MODFLOW RIBASIM TRIANGLE GATE PASS'; do
  grep -Fq "$marker" "$BUILD/triangle.txt" || fail "missing marker $marker"
done
echo 'RM13_REAL_THREE_MODEL_TRANSACTION_GATE=PASS'
