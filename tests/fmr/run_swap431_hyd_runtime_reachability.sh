#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap431-hyd-runtime-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

python3 tests/fmr/_apply_fmr44r_serialized_qbot_runtime_patch.py

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/kernel/mod_kernel_committed_persistence.f90
  src/runtime/mod_fmr_runtime_core.f90
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
  src/process/mod_soil_temperature_contract.f90
  src/process/mod_restricted_soil_temperature.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b111_legacy_hydraulic_provider.f90
  src/solver/mod_b111_extended_hydraulic_provider.f90
  src/solver/mod_b111_conductivity_power_tail.f90
  src/solver/mod_b111_linear_table_provider.f90
  src/solver/mod_b111_hysteresis_state.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_restart_state_contract.f90
  src/runtime/mod_fmr_committed_restart.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
)
mapfile -t MODULE_SRC < <(python3 tests/support/augment_bartholomeus_backend_sources.py "${MODULE_SRC[@]}")

for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/test_swap431_hyd_runtime_reachability.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt"; exit 1; }
  grep -Fq 'SW431_HYD_RUNTIME_REACHABILITY=PASS' "$OUT/output.txt"
  for model in 2 3 5 6 7 8 9 10 11; do
    grep -Fq "SW431_HYD_MODEL_RUNTIME_PASS=$model" "$OUT/output.txt"
  done
  for model in 8 9 10 11; do
    grep -Fq "SW431_HYD_PDI_VAPOR_RUNTIME_PASS=$model" "$OUT/output.txt"
  done
  grep -Fq 'SW431_HYD_POWER_RUNTIME_PASS' "$OUT/output.txt"
  grep -Fq 'SW431_HYD_LINEAR_TABLE_RUNTIME_PASS' "$OUT/output.txt"
  grep -Fq 'SW431_HYST_RUNTIME_RESTART_PASS=1' "$OUT/output.txt"
  grep -Fq 'SW431_HYST_RUNTIME_RESTART_PASS=2' "$OUT/output.txt"
  grep -Fq 'SW431_HYST_ROLLBACK_PASS=1' "$OUT/output.txt"
  grep -Fq 'SW431_HYST_ROLLBACK_PASS=2' "$OUT/output.txt"
  cat "$OUT/output.txt"
done
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo SW431_HYD_RUNTIME_O0_O2=PASS
