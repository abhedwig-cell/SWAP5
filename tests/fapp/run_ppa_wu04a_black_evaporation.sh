#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ppa-wu04a-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "PPA_WU04A_GATE_FAIL $*" >&2; exit 1; }

python3 - <<'PY'
from pathlib import Path
process = Path("src/process/mod_restricted_surface_evaporation.f90").read_text().lower()
backend = Path("src/runtime/mod_fmr_serialized_reference_backend.f90").read_text().lower()
restart = Path("src/runtime/mod_fmr_restart_state_contract.f90").read_text().lower()
bootstrap = Path("src/runtime/mod_fmr_production_application_bootstrap.f90").read_text().lower()
adapter = Path("src/adapter/mod_ppa_wu04a_black_forcing_adapter.f90").read_text().lower()

for token in (
    "cofred *",
    "sqrt(trial_ldwet + step_duration)",
    "candidate_state%ldwet = trial_ldwet + step_duration",
    "ponded-reset",
):
    assert token in process, token
for token in (
    "fmr_b110_black_evaporation_state_t",
    "fsi_top_mode_dynamic_provider",
    "evaluate_black_evaporation_reduction",
    "same_real_bits(t0, self%black_evaporation_forcing%wetting_event_time)",
    "black_physical%black_evaporation = black_result%candidate_state",
):
    assert token in backend, token
for token in (
    "fmr_optional_state_layout_black_evaporation",
    "fmr_b110_black_evaporation_state_t",
):
    assert token in restart, token
for token in (
    "initial_black_ldwet",
    "fmr_new_b110_black_evaporation_committed_state",
):
    assert token in bootstrap, token
assert "bound_forcing%top_flux = 0.0_real64" in adapter
assert "wetting_reset_event" in adapter
for forbidden in ("open(", "read(", "filename", "pathname", "calendar"):
    assert forbidden not in adapter, forbidden
print("PPA_WU04A_STATIC_SOURCE_BINDING=PASS")
print("PPA_WU04A_NO_HIDDEN_CALENDAR_OR_FILE_IO=PASS")
print("PPA_WU04A_NO_SECOND_MASS_OWNER_STATIC=PASS")
PY

# The candidate is allowed to touch only the preregistered production ownership
# surface. Triple-dot excludes concurrent canonical-only movement.
git fetch origin integration/f-ci-canonical:refs/remotes/origin/integration/f-ci-canonical
mapfile -t source_delta < <(git diff --name-only origin/integration/f-ci-canonical...HEAD -- src | sort)
cat > "$BUILD/expected-src.txt" <<'EOF'
src/adapter/mod_ppa_wu04a_black_forcing_adapter.f90
src/process/mod_restricted_surface_evaporation.f90
src/runtime/mod_fmr_production_application_bootstrap.f90
src/runtime/mod_fmr_restart_state_contract.f90
src/runtime/mod_fmr_runtime_core.f90
src/runtime/mod_fmr_serialized_reference_backend.f90
EOF
printf '%s
' "${source_delta[@]}" > "$BUILD/actual-src.txt"
cmp -s "$BUILD/expected-src.txt" "$BUILD/actual-src.txt" || {
  echo "PPA_WU04A unexpected production delta:" >&2
  cat "$BUILD/actual-src.txt" >&2
  fail "production delta escaped preregistration"
}
echo "PPA_WU04A_PREREGISTERED_PRODUCTION_DELTA=PASS"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fopenmp -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

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
  src/kernel/mod_kernel_committed_persistence.f90
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
  src/solver/mod_b110_adaptive_hydraulic_builder.f90
  src/solver/mod_b110_adaptive_hydraulic_cache.f90
  src/solver/mod_b110_adaptive_hydraulic_provider.f90
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
  src/adapter/mod_ppa_wu03_common_forcing_adapter.f90
  src/adapter/mod_ppa_wu04a_black_forcing_adapter.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/runtime/mod_fmr_restart_state_contract.f90
  src/runtime/mod_fmr_committed_restart.f90
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

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fapp/test_ppa_wu04a_black_process.f90 -o "$OUT/process_test.o" || fail "process test compile O$opt"
  gfortran -fopenmp -O"$opt" "$OUT/mod_restricted_surface_evaporation.o" "$OUT/process_test.o" -o "$OUT/process_test" || fail "process test link O$opt"
  "$OUT/process_test" > "$OUT/process.txt" 2>&1 || { cat "$OUT/process.txt" >&2; fail "process runtime O$opt"; }

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fapp/test_ppa_wu04a_black_runtime.f90 -o "$OUT/runtime_test.o" || fail "runtime test compile O$opt"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/runtime_test.o" -o "$OUT/runtime_test" || fail "runtime test link O$opt"
  "$OUT/runtime_test" > "$OUT/runtime.txt" 2>&1 || { cat "$OUT/runtime.txt" >&2; fail "runtime execution O$opt"; }

  grep -Fq 'PPA-WU04-A BLACK PROCESS TEST PASS' "$OUT/process.txt" || fail "process marker O$opt"
  grep -Fq 'PPA-WU04-A BLACK RUNTIME TEST PASS' "$OUT/runtime.txt" || fail "runtime marker O$opt"

  # Compile the admitted predecessor application tests against the same
  # dependency-complete object graph.  Their standalone shell runners currently
  # carry an older hand-written module order on canonical; preservation here is
  # behavioral, not a historical runner-blob assertion.
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fapp/test_ppa_wu01_production_application_bootstrap.f90 -o "$OUT/wu01_test.o" || fail "WU01 preservation compile O$opt"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/wu01_test.o" -o "$OUT/wu01_test" || fail "WU01 preservation link O$opt"
  "$OUT/wu01_test" > "$OUT/wu01.txt" 2>&1 || { cat "$OUT/wu01.txt" >&2; fail "WU01 preservation runtime O$opt"; }
  grep -Fq 'PPA-WU01 PRODUCTION APPLICATION BOOTSTRAP GATE PASS' "$OUT/wu01.txt" || fail "WU01 preservation marker O$opt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fapp/test_ppa_wu03_common_forcing_adapter.f90 -o "$OUT/wu03_test.o" || fail "WU03 preservation compile O$opt"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/wu03_test.o" -o "$OUT/wu03_test" || fail "WU03 preservation link O$opt"
  "$OUT/wu03_test" > "$OUT/wu03.txt" 2>&1 || { cat "$OUT/wu03.txt" >&2; fail "WU03 preservation runtime O$opt"; }
  grep -Fq 'PPA-WU03 COMMON FORCING OWNER GATE PASS' "$OUT/wu03.txt" || fail "WU03 preservation marker O$opt"
  for marker in     PPA_WU04A_BLACK_SOURCE_EQUATION_ORACLE=PASS     PPA_WU04A_EXPLICIT_WETTING_RESET_ORACLE=PASS     PPA_WU04A_PONDING_RESET_ORACLE=PASS     PPA_WU04A_PRODUCTION_APPLICATION_REACHABLE=PASS     PPA_WU04A_ACTUAL_EVAPORATION_HYDRAULIC_MASS_OWNER=PASS     PPA_WU04A_REJECTED_TRIAL_LDWET_IMMUTABLE=PASS     PPA_WU04A_CHANGED_DT_RETRY_FROM_CHECKPOINT=PASS     PPA_WU04A_RESTART_EXACT_LDWET_ROUNDTRIP=PASS     PPA_WU04A_RESTART_OPTION_LAYOUT_FAIL_CLOSED=PASS     PPA_WU04A_HARD_MASS=PASS; do
    grep -Fq "$marker" "$OUT/process.txt" "$OUT/runtime.txt" || fail "marker $marker O$opt"
  done
  echo "PPA_WU04A_O${opt}=PASS"
done

cmp -s "$BUILD/o0/process.txt" "$BUILD/o2/process.txt" || fail "process O0/O2 output identity"
cmp -s "$BUILD/o0/runtime.txt" "$BUILD/o2/runtime.txt" || fail "runtime O0/O2 output identity"
cmp -s "$BUILD/o0/wu01.txt" "$BUILD/o2/wu01.txt" || fail "WU01 preservation O0/O2 output identity"
cmp -s "$BUILD/o0/wu03.txt" "$BUILD/o2/wu03.txt" || fail "WU03 preservation O0/O2 output identity"
echo 'PPA_WU04A_O0_O2_OUTPUT_IDENTITY=PASS'
echo 'PPA_WU04A_PPA_WU01_PRESERVATION=PASS'
echo 'PPA_WU04A_PPA_WU03_PRESERVATION=PASS'

git diff --check
cat "$BUILD/o0/process.txt"
cat "$BUILD/o0/runtime.txt"
echo 'PPA-WU04-A BLACK EVAPORATION ADMISSION QUALIFICATION PASS'
