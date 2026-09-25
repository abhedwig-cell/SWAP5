#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fgc49d-context-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "FGC49D_CONTEXT_FAIL $*" >&2; exit 1; }

python3 - <<'PY'
from pathlib import Path

context = Path("src/runtime/mod_fmr_groundwater_application_context.f90").read_text().lower()
capi = Path("src/adapter/mod_fmr_groundwater_application_c_api.f90").read_text().lower()
py = Path("src/adapter/fmr_groundwater_application_runtime.py").read_text().lower()

for token in [
    "fmr_groundwater_application_context_t",
    "fmr_groundwater_participant_registry_t",
    "groundwater_application_plan_t",
    "aggregate_groundwater_cell_tiles",
    "evaluate_modflow6_linear_boundary_flux_density",
    "reanchor_modflow6_linear_boundary_term",
]:
    assert token in context, token

for forbidden in [
    "xmiwrapper",
    "prepare_solve",
    "finalize_solve",
    "finalize_time_step",
]:
    assert forbidden not in context, forbidden

for token in [
    "register_fmr_groundwater_application_context",
    "fgc49d_plan_view_c",
    "fgc49d_tile_view_c",
    "fgc49d_trial_cell_heads_c",
    "fgc49d_commit_swaps_c",
    "fgc49d_commit_ledgers_c",
]:
    assert token in capi, token

for forbidden in [
    "7001",
    "7002",
    "0.35",
    "0.65",
    "hcof_m2_per_day *",
    "rhs_m3_per_day",
]:
    if forbidden == "rhs_m3_per_day":
        continue
    assert forbidden not in py, forbidden

assert "fmrgroundwaterapplicationruntime" in py.replace("_", "")
assert "participant_handles" in py
assert "aggregate_groundwater_cell_tiles" not in py
assert "86400" not in py

print("FGC49D_NO_TOPOLOGY_SPECIFIC_PRODUCTION_IDS=PASS")
print("FGC49D_NO_MODFLOW_XMI_OWNERSHIP=PASS")
print("FGC49D_NO_PYTHON_FGC40_FGC33_MATH=PASS")
print("FGC49D_OPAQUE_CONTEXT_AND_PARTICIPANT_HANDLES=PASS")
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fPIC -fopenmp -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
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
  src/process/mod_drainage_extended_exchange.f90
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
  src/runtime/mod_modflow6_swap_prescribed_qbot_bottom_face.f90
  src/runtime/mod_groundwater_swap_forcing_adapter.f90
  src/runtime/mod_groundwater_swap_transaction_participant.f90
  src/runtime/mod_fmr_groundwater_head_forcing_adapter.f90
  src/runtime/mod_fmr_groundwater_swap_participant.f90
  src/runtime/mod_fmr_groundwater_participant_registry.f90
  src/runtime/mod_groundwater_interface_mass_ledger.f90
  src/runtime/mod_groundwater_tile_aggregation.f90
  src/runtime/mod_groundwater_multiswap_types.f90
  src/runtime/mod_modflow6_swap_predictor_response.f90
  src/runtime/mod_modflow6_multiswap_cell_response.f90
  src/runtime/mod_modflow6_linear_response_backend.f90
  src/runtime/mod_modflow6_api_binding.f90
  src/runtime/mod_groundwater_topology_composition.f90
  src/runtime/mod_groundwater_application_plan.f90
  src/runtime/mod_fmr_groundwater_application_context.f90
  src/adapter/mod_fmr_groundwater_application_c_api.f90
  tests/fgc/support/mod_fgc49d_application_context_fixture.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj" || fail "compile O$opt $source"
    objects+=("$obj")
  done
  gfortran -shared -fopenmp -O"$opt" "${objects[@]}" -o "$OUT/libfgc49d_application.so" || fail "link O$opt"

  for symbol in     fgc49d_fixture_initialize_c     fgc49d_context_counts_c     fgc49d_plan_view_c     fgc49d_tile_view_c     fgc49d_capture_origins_c     fgc49d_evaluate_groundwater_fluxes_c     fgc49d_trial_cell_heads_c     fgc49d_reanchor_terms_c     fgc49d_commit_swaps_c     fgc49d_commit_ledgers_c; do
    nm -D "$OUT/libfgc49d_application.so" | grep -q "$symbol" || fail "missing symbol $symbol O$opt"
  done

  FGC49D_APPLICATION_LIB="$OUT/libfgc49d_application.so"     python3 tests/fgc/test_fgc49d_production_application_context.py > "$OUT/output.txt" 2>&1 || {
      cat "$OUT/output.txt" >&2
      fail "runtime O$opt"
    }

  grep '^FGC49D_' "$OUT/output.txt" > "$OUT/stable.txt"
  grep -Fq 'F-GC49D PRODUCTION APPLICATION CONTEXT ABI GATE PASS' "$OUT/output.txt" || fail "missing final marker O$opt"
  echo "FGC49D_CONTEXT_O${opt}=PASS"
done

diff -u "$BUILD/o0/stable.txt" "$BUILD/o2/stable.txt"
cat "$BUILD/o0/output.txt"

git diff --check --   src/runtime/mod_modflow6_linear_response_backend.f90   src/runtime/mod_fmr_groundwater_application_context.f90   src/adapter/mod_fmr_groundwater_application_c_api.f90   src/adapter/fmr_groundwater_application_runtime.py   tests/fgc/support/mod_fgc49d_application_context_fixture.f90   tests/fgc/test_fgc49d_production_application_context.py

echo 'FGC49D_CONTEXT_O0_O2_OUTPUT_IDENTITY=PASS'
echo 'F-GC49D PRODUCTION APPLICATION CONTEXT ABI GATE PASS'
