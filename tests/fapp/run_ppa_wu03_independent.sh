#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ppa-wu03-independent-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "PPA_WU03_GATE_FAIL $*" >&2; exit 1; }

python3 - <<'PY'
from pathlib import Path

adapter = Path("src/adapter/mod_ppa_wu03_common_forcing_adapter.f90").read_text().lower()
test = Path("tests/fapp/test_ppa_wu03_independent_common_forcing_independent.f90").read_text().lower()

for token in [
    "materialize_ppa_wu03_common_forcing",
    "expected_soil",
    "expected_pond",
    "expected_ptra",
    "ppa_wu03_independent_matrix_cases",
]:
    assert token in test, token

assert "fmr_evaluate_reference_et_demand" not in test
assert "evaluate_restricted_reference_et_demand" not in test
assert "mod_fmr_production_application_bootstrap" not in test
assert "open(" not in adapter
assert "readswap" not in adapter
assert "stream_cursor" not in adapter

print("PPA_WU03_INDEPENDENT_ORACLE_SEPARATION_STATIC=PASS")
print("PPA_WU03_INDEPENDENT_NO_OWNER_ORACLE_STATIC=PASS")
PYCOMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fopenmp -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
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
  src/process/mod_reference_et_demand_process.f90
  src/runtime/mod_fmr_reference_et_demand_binding.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_owned_commit_receipt.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/process/mod_liquid_water_sensible_enthalpy.f90
  src/runtime/mod_fmr_bottom_external_thermal_binding.f90
  src/runtime/mod_fmr_bottom_external_thermal_provider.f90
  src/runtime/mod_fmr_bottom_sensible_energy.f90
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
  src/adapter/mod_ppa_wu03_common_forcing_adapter.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
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
  src/runtime/mod_fmr_production_application_bootstrap.f90
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
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fapp/test_ppa_wu03_independent_common_forcing_independent.f90 -o "$OUT/test.o" || fail "compile test O$opt"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test_ppa_wu03_independent" || fail "link O$opt"

  "$OUT/test_ppa_wu03_independent" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "runtime O$opt"
  }
  grep '^PPA_WU03_' "$OUT/output.txt" > "$OUT/stable.txt"
  grep -Fq 'PPA-WU03 INDEPENDENT QUALIFICATION PASS' "$OUT/output.txt" || fail "missing final marker O$opt"
  echo "PPA_WU03_O${opt}=PASS"
done

diff -u "$BUILD/o0/stable.txt" "$BUILD/o2/stable.txt"
cat "$BUILD/o0/output.txt"

git diff --check -- \
  src/adapter/mod_ppa_wu03_common_forcing_adapter.f90 \
  src/runtime/mod_fmr_production_application_bootstrap.f90 \
  tests/fapp/test_ppa_wu03_independent_common_forcing_independent.f90 \
  tests/fapp/run_ppa_wu03_common_forcing_adapter.sh

echo 'PPA_WU03_O0_O2_OUTPUT_IDENTITY=PASS'
echo 'PPA-WU03 INDEPENDENT O0 O2 QUALIFICATION PASS'
