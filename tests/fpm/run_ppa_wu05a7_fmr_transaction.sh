#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/ppa-wu05a7-fmr-transaction-${GITHUB_RUN_ID:-local}-$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail(){ echo "FKT22_FMR_COMPILE_FAIL $*" >&2; exit 1; }

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -fopenmp -ffpe-trap=invalid,zero,overflow)
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
  src/solver/mod_b110_direct_retention_core.f90
  src/solver/mod_b110_direct_retention_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
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
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/runtime/mod_macropore_continuation_state.f90
  src/process/macropore/mod_ppa_wu05a5_top_partition.f90
  src/process/macropore/mod_ppa_wu05a5_multi_domain_process.f90
  src/process/macropore/mod_ppa_wu05a6_sorptivity_rate.f90
  src/process/macropore/mod_ppa_wu05a6_unsat_absorption_rate.f90
  src/process/macropore/mod_ppa_wu05a6_saturated_exchange_rate.f90
  src/process/macropore/mod_ppa_wu05a6_saturated_sources.f90
  src/process/macropore/mod_ppa_wu05a6_rapid_drain_rate.f90
  src/process/macropore/mod_ppa_wu05a6_top_inflow_limiter.f90
  src/process/macropore/mod_ppa_wu05a6_vertical_flux_reconstruction.f90
  src/process/macropore/mod_ppa_wu05a6_sorptivity_history.f90
  src/process/macropore/mod_ppa_wu05a6_rate_bundle.f90
  src/solver/mod_macropore_exchange_overlay_provider.f90
  src/runtime/mod_macropore_single_column_runtime.f90
  src/runtime/mod_fmr_soil_water_application_host.f90
  src/runtime/mod_rossfast_d3r_execution_policy.f90
  src/runtime/mod_rossfast_d3r_model_binding.f90
  src/solver/mod_rossfast_d3r_table_kernel.f90
  src/solver/mod_rossfast_d3r_table_provider.f90
  src/solver/mod_rossfast_d3r_soil_water_solver.f90
  src/runtime/mod_fmr_rossfast_solver_selection_binding.f90
  src/adapter/mod_fmr_mode7_temporal_head_envelope.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_restart_state_contract.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    extra=()
    [[ "$source" == "src/solver/mod_soil_water_solver_contract.f90" ]] && extra=(-Wno-error=unused-dummy-argument)
    gfortran "${COMMON[@]}" "${extra[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj" || fail "compile O$opt $source"
  done
  echo "FKT22_FMR_COMPILE_O${opt}=PASS"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     tests/fpm/test_ppa_wu05a7_fmr_macropore_transaction.f90 -o "$OUT/test_a7_fmr.o" || fail "compile A7 FMR transaction O$opt"
  gfortran -fopenmp -O"$opt" "$OUT"/*.o -o "$OUT/test_a7_fmr" || fail "link A7 FMR transaction O$opt"
  "$OUT/test_a7_fmr" > "$OUT/a7_fmr.txt" 2>&1 || { cat "$OUT/a7_fmr.txt" >&2; fail "runtime A7 FMR transaction O$opt"; }
  cat "$OUT/a7_fmr.txt"
  grep -Fq 'PPA_WU05A7_FMR_MACROPORE_TRANSACTION=PASS' "$OUT/a7_fmr.txt" || fail "missing A7 FMR transaction marker O$opt"
done

cmp "$BUILD/o0/a7_fmr.txt" "$BUILD/o2/a7_fmr.txt" || fail 'A7 FMR transaction O0/O2 drift'

echo 'PPA_WU05A7_FMR_TRANSACTION_GATE=PASS'
