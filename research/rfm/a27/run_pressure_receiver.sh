#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
python3 - "$BUILD/grid_stubs.f90" <<'GRID'
from pathlib import Path
import sys
s=Path('tests/fsi/fsi04_real_headcalc_stubs.f90').read_text()
s=s.replace('numnod = 4','numnod = 10')
s=s.replace('[-0.25d0, -0.75d0, -1.50d0, -2.50d0]','['+','.join(str(-5-10*i)+'d0' for i in range(10))+']')
s=s.replace('[0.50d0, 0.50d0, 1.00d0, 1.00d0]','10.0d0').replace('disnod(numnod+1) = 1.0d0','disnod(numnod+1) = [5.0d0,10.0d0,10.0d0,10.0d0,10.0d0,10.0d0,10.0d0,10.0d0,10.0d0,10.0d0,5.0d0]')
Path(sys.argv[1]).write_text(s)
GRID
MODULE_SRC=(
 "$BUILD/grid_stubs.f90"
 src/solver/mod_soil_water_accepted_step_direction_contract.f90
 src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
 src/runtime/mod_a23bu_worker_execution_context.f90
 src/transaction/mod_accepted_trajectory_directional_publication.f90
 src/transaction/mod_transaction_reference.f90
 src/adapter/mod_fmr_mode7_temporal_head_envelope.f90
 src/transaction/mod_fkt_temporal_indicator_history.f90
 src/runtime/mod_canonical_contracts.f90
 src/runtime/mod_canonical_interval_runtime.f90
 src/kernel/mod_kernel_transactions.f90
 src/kernel/mod_kernel_committed_persistence.f90
 src/runtime/mod_fmr_runtime_core.f90
 src/runtime/mod_fmr_bottom_thermal_carrier.f90
 src/runtime/mod_fmr_top_sensible_boundary_carrier.f90
 src/runtime/mod_fmr_checkpoint_orchestrator.f90
 src/runtime/mod_fmr_soil_water_application_host.f90
 src/runtime/mod_rossfast_d3r_execution_policy.f90
 src/runtime/mod_rossfast_d3r_model_binding.f90
 src/solver/mod_soil_water_solver_contract.f90
 src/solver/mod_reference_richards_state_binding.f90
 src/solver/mod_rossfast_d3r_table_kernel.f90
 src/solver/mod_rossfast_d3r_table_provider.f90
 src/solver/mod_rossfast_d3r_soil_water_solver.f90
 src/runtime/mod_fmr_rossfast_solver_selection_binding.f90
 src/runtime/mod_macropore_continuation_state.f90
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
 src/solver/mod_reference_linear_solver.f90
 src/solver/mod_b110_default_mvg_provider.f90
 src/solver/mod_b110_default_mvg_directional_provider.f90
 src/solver/mod_b110_direct_retention_core.f90
 src/solver/mod_b110_direct_retention_provider.f90
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
 src/adapter/mod_reference_richards_accepted_step_directional_service.f90
 src/adapter/mod_b110_serialized_context_binding.f90
 src/process/macropore/mod_ppa_wu05a6_saturated_exchange_rate.f90
)
for opt in 0 2; do
 OUT="$BUILD/o$opt";mkdir -p "$OUT";objects=()
 for source in "${MODULE_SRC[@]}"; do
  obj="$OUT/$(basename "${source%.*}").o"
  "${FC:-gfortran}" -std=f2008 -ffree-line-length-none -fcheck=all -O"$opt" -J"$OUT" -I"$OUT" -c "$source" -o "$obj"
  objects+=("$obj")
 done
 "${FC:-gfortran}" -std=f2008 -ffree-line-length-none -fcheck=all -O"$opt" -J"$OUT" -I"$OUT" "${objects[@]}" research/rfm/a27/test_pressure_receiver.f90 -o "$OUT/test"
 "$OUT/test" > "$OUT/out.txt"
done
cmp "$BUILD/o0/out.txt" "$BUILD/o2/out.txt"
cat "$BUILD/o2/out.txt"
grep -Fq 'A27_PRESSURE_RECEIVER_SEAM=PASS' "$BUILD/o2/out.txt"
