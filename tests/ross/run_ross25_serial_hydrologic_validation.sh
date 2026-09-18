#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-f-ross25-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
fail() { echo "F_ROSS25_GATE_FAIL $*" >&2; exit 1; }

SOURCE=b1f23b069f733f1d711699b9d3cd4b8acaec968b
PREREG=integration/f-ross/F-ROSS25_SERIAL_HYDROLOGIC_VALIDATION_PREREGISTRATION.json
TEST=tests/ross/test_ross25_serial_hydrologic_validation.f90
SUMMARY=tools/performance/f_ross25_serial_validation_summary.py
FROSS22_ADMISSION=8875e46b28cf2462948ca1952ed283cb2c7483eb
KERNEL_BLOB=438ee46e012e9eb183b8f2532437e2fe56aa18ed
SOLVER_BLOB=2b134c36097aed2a44a56bfe8e2194b15aa063aa
CONTRACT_BLOB=40a1ddc05fb8e2c1822763de645fd07a094568a3
REFERENCE_BINDING_BLOB=4b545c6fb260e81cd6c8f4d2d65f2beee7281e53
MODEL_BLOB=5442fd7e7a2f392c9b796cd17c76b17977259f22
PROVIDER_BLOB=ac997bf06c56a37080d1c8db69b6d4208f4b75ca
POLICY_BLOB=a39a636d01f373ae6ef0dc3ac0e1e25b6522fda9

for path in "$PREREG" "$TEST" "$SUMMARY"; do [[ -f "$path" ]] || fail "missing $path"; done
grep -Fq '"phase": "DESIGN"' "$PREREG" || fail 'prereg phase drift'
grep -Fq '"trajectory_count": 216' "$PREREG" || fail 'trajectory count drift'
grep -Fq '"intervals_per_trajectory": 32' "$PREREG" || fail 'interval count drift'
grep -Fq '"NO_PRODUCTION_MUTATION"' "$PREREG" || fail 'production firewall drift'
grep -Fq '"NO_DOMAIN_RETUNING_AFTER_RESULTS"' "$PREREG" || fail 'domain firewall drift'

git merge-base --is-ancestor "$FROSS22_ADMISSION" HEAD || fail 'F-ROSS22 admission not ancestor'
git merge-base --is-ancestor "$SOURCE" HEAD || fail 'F-ROSS25 canonical source not ancestor'
# Canonical may advance through unrelated production work. F-ROSS25 validity is
# bound to the exact RossFast/Reference dependency blobs checked below, not a
# repository-wide src/reference freeze.

test "$(git rev-parse HEAD:src/solver/mod_rossfast_d3r_table_kernel.f90)" = "$KERNEL_BLOB" || fail 'admitted tiered kernel drift'
test "$(git rev-parse HEAD:src/solver/mod_rossfast_d3r_soil_water_solver.f90)" = "$SOLVER_BLOB" || fail 'admitted tiered solver drift'
test "$(git rev-parse HEAD:src/solver/mod_soil_water_solver_contract.f90)" = "$CONTRACT_BLOB" || fail 'solver contract drift'
test "$(git rev-parse HEAD:src/adapter/mod_reference_richards_legacy_binding.f90)" = "$REFERENCE_BINDING_BLOB" || fail 'Reference binding drift'
test "$(git rev-parse HEAD:src/runtime/mod_rossfast_d3r_model_binding.f90)" = "$MODEL_BLOB" || fail 'RossFast model binding drift'
test "$(git rev-parse HEAD:src/solver/mod_rossfast_d3r_table_provider.f90)" = "$PROVIDER_BLOB" || fail 'RossFast provider drift'
test "$(git rev-parse HEAD:src/runtime/mod_rossfast_d3r_execution_policy.f90)" = "$POLICY_BLOB" || fail 'RossFast policy drift'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fopenmp)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/transaction/mod_transaction_reference.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
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
  src/adapter/mod_reference_richards_accepted_step_directional_service.f90
  src/adapter/mod_b110_serialized_context_binding.f90
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
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/runtime/mod_fmr_top_sensible_boundary_carrier.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_owned_commit_receipt.f90
  src/runtime/mod_fmr_bottom_external_thermal_binding.f90
  src/runtime/mod_fmr_bottom_external_thermal_provider.f90
  src/process/mod_liquid_water_sensible_enthalpy.f90
  src/runtime/mod_fmr_bottom_sensible_energy.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
)
objects=()
for source in "${MODULE_SRC[@]}"; do
  [[ -f "$source" ]] || fail "missing compile source $source"
  obj="$BUILD/$(basename "${source%.*}").o"
  extra=()
  [[ "$source" == "src/solver/mod_soil_water_solver_contract.f90" ]] && extra=(-Wno-error=unused-dummy-argument)
  gfortran "${COMMON[@]}" "${extra[@]}" -O2 -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -O2 -J "$BUILD" -I "$BUILD" -c "$TEST" -o "$BUILD/test.o"
gfortran -fopenmp -O2 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/f_ross25_validation"

"$BUILD/f_ross25_validation" | tee "$BUILD/raw.txt"
grep -Fq 'F_ROSS25_GATE=PASS' "$BUILD/raw.txt" || fail 'Fortran validation gate missing'
python3 "$SUMMARY" --input "$BUILD/raw.txt" --output "$BUILD/F-ROSS25_SERIAL_VALIDATION_RESULT.json" | tee "$BUILD/summary.txt"
grep -Fq 'F_ROSS25_SUMMARY_GATE=PASS' "$BUILD/summary.txt" || fail 'summary gate missing'
cp "$BUILD/F-ROSS25_SERIAL_VALIDATION_RESULT.json" "${GITHUB_WORKSPACE:-$ROOT}/F-ROSS25_SERIAL_VALIDATION_RESULT.json"
echo 'F_ROSS25_SERIAL_HYDROLOGIC_VALIDATION=PASS'
