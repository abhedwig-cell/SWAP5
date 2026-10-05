#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/ppa-wu05a7-real-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "PPA_WU05A7_REAL_FAIL $*" >&2; exit 1; }

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
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
  src/process/mod_snow_process.f90
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/process/macropore/mod_ppa_wu05a5_top_partition.f90
  src/process/macropore/mod_ppa_wu05a5_multi_domain_process.f90
  src/process/macropore/mod_macropore_dynamic_shrinkage.f90
  src/process/macropore/mod_ppa_wu05a6_sorptivity_rate.f90
  src/process/macropore/mod_ppa_wu05a6_unsat_absorption_rate.f90
  src/process/macropore/mod_ppa_wu05a6_saturated_exchange_rate.f90
  src/process/macropore/mod_ppa_wu05a6_saturated_sources.f90
  src/process/macropore/mod_ppa_wu05a6_rapid_drain_rate.f90
  src/process/macropore/mod_ppa_wu05a6_top_inflow_limiter.f90
  src/process/macropore/mod_ppa_wu05a6_vertical_flux_reconstruction.f90
  src/process/macropore/mod_ppa_wu05a6_sorptivity_history.f90
  src/process/macropore/mod_ppa_wu05a6_rate_bundle.f90
  src/process/macropore/mod_ppa_wu05a15_exchange_derivative.f90
  src/process/macropore/mod_macropore_standard_storage.f90
  src/runtime/mod_macropore_standard_rate_adapter.f90
  src/runtime/mod_fmr_macropore_top_input.f90
  src/process/macropore/mod_macropore_covering_layer_input.f90
  src/solver/mod_macropore_exchange_overlay_provider.f90
  src/process/macropore/mod_ppa_wu05_perch19_reduction_controller.f90
  src/runtime/mod_ppa_wu05a16_inner_macropore_provider.f90
  src/runtime/mod_macropore_single_column_runtime.f90
  src/runtime/mod_fmr_macropore_configuration.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_restart_state_contract.f90
)
# Additive C3A backend prerequisites; existing gate semantics stay fixed.
mapfile -t MODULE_SRC < <(python3 tests/support/augment_bartholomeus_backend_sources.py "${MODULE_SRC[@]}")

for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj" || fail "compile O$opt $source"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     tests/fpm/test_ppa_wu05a7_real_richards_runtime.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" | tee "$OUT/out.txt"
  grep -Fq 'PPA_WU05A7_REAL_RICHARDS_RUNTIME=PASS' "$OUT/out.txt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     tests/fpm/test_ppa_wu05a8_fmr_macropore_trial.f90 -o "$OUT/test_fmr_macro.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test_fmr_macro.o" -o "$OUT/test_fmr_macro"
  "$OUT/test_fmr_macro" | tee "$OUT/fmr_macro.txt"
  grep -Fq 'PPA_WU05A8_FMR_MACRO_TRIAL=PASS' "$OUT/fmr_macro.txt"
done
cmp "$BUILD/o0/out.txt" "$BUILD/o2/out.txt"
cmp "$BUILD/o0/fmr_macro.txt" "$BUILD/o2/fmr_macro.txt"
echo "PPA_WU05A8_REAL_RICHARDS_GATE=PASS"
