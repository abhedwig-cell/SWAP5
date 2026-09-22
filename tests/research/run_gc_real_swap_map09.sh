#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-gc-map09-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/modflow-bin" "$BUILD/downloads" "$BUILD/bridge"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "PUB_GC_E3_FAIL $*" >&2; exit 1; }

python3 - <<PY
from pathlib import Path
from flopy.utils.get_modflow import run_main
bindir=Path("$BUILD/modflow-bin")
downloads=Path("$BUILD/downloads")
run_main(bindir,owner="MODFLOW-ORG",repo="modflow6",release_id="6.8.0",
         subset={"mf6","libmf6.so"},downloads_dir=downloads,force=True,quiet=False)
PY
ARCHIVE="$BUILD/downloads/modflow6-6.8.0-linux.zip"
echo "33edf988b672a9f282d6773304c079d0f180541f6fe0c6555265d9c71841256e  $ARCHIVE" | sha256sum -c - || fail "MODFLOW asset hash"
test -f "$BUILD/modflow-bin/libmf6.so" || fail "missing libmf6.so"

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
  tests/research/support/mod_gc_map09_active_drainage_bridge.f90
)
objects=()
for source in "${MODULE_SRC[@]}"; do
  obj="$BUILD/bridge/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -O2 -J "$BUILD/bridge" -I "$BUILD/bridge" -c "$source" -o "$obj" || fail "compile $source"
  objects+=("$obj")
done
gfortran -shared -fopenmp -O2 "${objects[@]}" -o "$BUILD/bridge/libgc_map09_swap.so" || fail "link MAP09 shared library"
nm -D "$BUILD/bridge/libgc_map09_swap.so" | grep -q 'pub_gc_e6_swap_initialize_c' || fail "missing MAP09 SWAP C ABI"
nm -D "$BUILD/bridge/libgc_map09_swap.so" | grep -q 'pub_gc_e6_corrector_diagnostics_c' || fail "missing MAP09 corrector diagnostics C ABI"
nm -D "$BUILD/bridge/libgc_map09_swap.so" | grep -q 'fgc34_publish_c' || fail "missing F-GC34 publisher C ABI"

MAP09_SWAP_LIB="$BUILD/bridge/libgc_map09_swap.so" \
  python3 tests/research/test_gc_real_swap_map09_active_drainage.py | tee "$BUILD/map09.txt"

MAP09_SWAP_LIB="$BUILD/bridge/libgc_map09_swap.so" \
  python3 tests/research/test_gc_real_swap_map09a_decomposition.py | tee "$BUILD/map09a.txt"

for marker in \
  'GC_MAP09A_PARENT_ACTIVATION=PASS' \
  'GC_MAP09A_SYMMETRIC_PAIR_FIXED=PASS' \
  'GC_MAP09A_BOTH_TRIALS_MASS_COMPLETE=PASS' \
  'GC_MAP09A_STORAGE_LEDGER_IDENTITY=PASS' \
  'GC_MAP09A_DERIVATIVES_FINITE=PASS' \
  'GC_MAP09A_ZERO_AUTHORITY_MUTATION=PASS' \
  'GC_MAP09A_LIVE_GATE=PASS'; do
  grep -Fq "$marker" "$BUILD/map09a.txt" || fail "missing MAP09A marker $marker"
done

for marker in \
  'GC_MAP09_E6_PREDICTOR_IDENTITY=PASS' \
  'GC_MAP09_REFERENCE_CORRECTOR_ADMITTED=PASS' \
  'GC_MAP09_REFERENCE_MASS_CLOSURE=PASS' \
  'GC_MAP09_ZERO_AUTHORITY_MUTATION=PASS' \
  'GC_MAP09_CHARACTERIZATION_RECORDED=PASS' \
  'GC_MAP09_LIVE_GATE=PASS'; do
  grep -Fq "$marker" "$BUILD/map09.txt" || fail "missing marker $marker"
done

git diff --check -- tests/research/test_gc_real_swap_map09_active_drainage.py \
  tests/research/run_gc_real_swap_map09.sh \
  integration/research/GC_REAL_SWAP_MAP09_PREREGISTRATION.json \
  integration/research/GC_REAL_SWAP_MAP09A_PREREGISTRATION.json \
  integration/research/GC_REAL_SWAP_MAP09_RESULT.json \
  tests/research/test_gc_real_swap_map09a_decomposition.py

echo 'GC REAL SWAP MAP09 MAP09A ACTIVE DRAINAGE DECOMPOSITION PASS'


# G12's preregistered all-regime groundwater href-calibration gate was
# falsified. G12A then qualified the failure mechanism as one-shot bias anchoring.
# Preserve both; neither is rerun as a moving acceptance gate.
echo 'GC_FIXED_INTERFACE_G12_EXECUTION=FALSIFIED_PRESERVED'
echo 'GC_FIXED_INTERFACE_G12A_DIAGNOSTIC=QUALIFIED_PRESERVED'

# G12B canonical active-drainage replay. G12 remains falsified; G12B uses the
# independently qualified G12A local groundwater authorities without bias retuning.
LIBMF6="$BUILD/modflow-bin/libmf6.so" \
MAP09_SWAP_LIB="$BUILD/bridge/libgc_map09_swap.so" \
  python3 tests/research/test_gc_fixed_interface_map09_local_groundwater_g12b.py \
  | tee "$BUILD/g12b-active-drainage-local-groundwater.txt"

grep -Fq 'GC_FIXED_INTERFACE_G12B_EXECUTION=PASS' "$BUILD/g12b-active-drainage-local-groundwater.txt" || {
  echo "GC_G12B_FAIL missing canonical active-drainage local-groundwater replay gate" >&2
  exit 1
}


# G14 research-only fused trial observation for the active-drainage carrier.
MAP09_SWAP_LIB="$BUILD/bridge/libgc_map09_swap.so" \
  python3 tests/research/test_gc_fixed_interface_g14_fused_map09.py \
  | tee "$BUILD/map09-g14-fused.txt"

grep -Fq 'GC_FIXED_INTERFACE_G14_MAP09_FUSED_EQUIVALENCE=PASS' "$BUILD/map09-g14-fused.txt" || {
  echo "GC_MAP09_G14_FAIL missing fused-observation equivalence gate" >&2
  exit 1
}
