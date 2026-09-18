#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-gc-e3d2-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/bridge"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "PUB_GC_E3D2_FAIL $*" >&2; exit 1; }

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
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/adapter/mod_reference_richards_accepted_step_directional_service.f90
  src/process/mod_snow_process.f90
  src/solver/mod_b110_root_sink_provider.f90
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
)
objects=()
for source in "${MODULE_SRC[@]}"; do
  obj="$BUILD/bridge/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -O2 -J "$BUILD/bridge" -I "$BUILD/bridge" -c "$source" -o "$obj" || fail "compile $source"
  objects+=("$obj")
done
gfortran -shared -fopenmp -O2 "${objects[@]}" -o "$BUILD/bridge/libfgc44_swap.so" || fail "link F-GC44 shared library"
nm -D "$BUILD/bridge/libfgc44_swap.so" | grep -q 'fgc44_swap_initialize_c' || fail "missing SWAP C ABI"
nm -D "$BUILD/bridge/libfgc44_swap.so" | grep -q 'fgc44_swap_initialize_configured_c' || fail "missing configurable SWAP C ABI"
nm -D "$BUILD/bridge/libfgc44_swap.so" | grep -q 'fgc34_publish_c' || fail "missing F-GC34 publisher C ABI"

OUT="${PUB_GC_EVIDENCE_DIR:-$ROOT/build/pub-gc-e3d2}"
mkdir -p "$OUT"
: > "$OUT/cases.jsonl"
: > "$OUT/case-output.txt"

CASES=(
  "1e-4 3e-5"
  "1e-4 1e-4"
  "1e-3 1e-4"
  "1e-3 3e-4"
  "1e-2 1e-4"
  "1e-2 3e-4"
)

for item in "${CASES[@]}"; do
  read -r window qbot <<< "$item"
  echo "PUB_GC_E3D2_CASE window=$window qbot=$qbot" | tee -a "$OUT/case-output.txt"
  CASE_OUT="$(
    FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
    E3D2_WINDOW_DAY="$window" \
    E3D2_QBOT_CM_PER_DAY="$qbot" \
    python3 tests/publication/test_pub_gc_e3d2_case.py
  )"
  printf '%s\n' "$CASE_OUT" | tee -a "$OUT/case-output.txt"
  JSON_LINE="$(printf '%s\n' "$CASE_OUT" | sed -n 's/^E3D2_JSON=//p' | tail -n 1)"
  test -n "$JSON_LINE" || fail "missing structured diagnostic window=$window qbot=$qbot"
  printf '%s\n' "$JSON_LINE" >> "$OUT/cases.jsonl"
done

python3 - "$OUT" <<'PY'
from __future__ import annotations
import json,sys
from pathlib import Path
out=Path(sys.argv[1])
records=[json.loads(x) for x in (out/"cases.jsonl").read_text().splitlines() if x.strip()]
if len(records)!=6:
    raise SystemExit(f"expected six E3D2 cases, got {len(records)}")
for r in records:
    if r["predictor_ready"]:
        if r["configured_init_status"]!=0 or not r["completed"] or r["result_status"]!=0:
            raise SystemExit(f"invalid ready diagnostic: {r}")
    else:
        if r["configured_init_status"]!=104:
            raise SystemExit(f"boundary failure not stage 104: {r}")

summary={
  "schema":"pub-gc-e3d2-predictor-failure-v1",
  "case_count":len(records),
  "records":records,
}
(out/"PUB_GC_E3D2_RESULT.json").write_text(json.dumps(summary,indent=2,sort_keys=True)+"\n")
print(json.dumps(summary,indent=2,sort_keys=True))
PY

echo "PUB_GC_E3D2_MECHANISM_SCAN_COMPLETE=PASS"
