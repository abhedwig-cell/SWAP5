#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-f-ross15-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "F_ROSS15_GATE_FAIL $*" >&2; exit 1; }

PREREG=integration/f-ross/F-ROSS15_PERFORMANCE_PREREGISTRATION.json
TEST=tests/ross/test_ross15_reference_vs_rossfast_performance.f90
RUNNER=tools/performance/f_ross15_paired_screen.py

P2E10_RESULT_BLOB=83864f6379279725fa97d24d57936f590d3c2174
SOLVER_CONTRACT_BLOB=40a1ddc05fb8e2c1822763de645fd07a094568a3
REFERENCE_BINDING_BLOB=4b545c6fb260e81cd6c8f4d2d65f2beee7281e53
ROSSFAST_SOLVER_BLOB=dbb441f3529be179d64fb57f9c44336d3d20c540
ROSSFAST_MODEL_BINDING_BLOB=5442fd7e7a2f392c9b796cd17c76b17977259f22
ROSSFAST_EXECUTION_POLICY_BLOB=a39a636d01f373ae6ef0dc3ac0e1e25b6522fda9
ROSSFAST_TABLE_PROVIDER_BLOB=ac997bf06c56a37080d1c8db69b6d4208f4b75ca
ISOLATED_READINESS_BLOB=44634b56c14022278938fc53b181b741e29c07aa

for path in "$PREREG" "$TEST" "$RUNNER"; do
  [[ -f "$path" ]] || fail "missing $path"
done

grep -Fq '"phase": "PREREGISTERED_BEFORE_TIMING_EXECUTION"' "$PREREG" || fail 'preregistration phase drift'
grep -Fq '"paired_valid_case_count": 36' "$PREREG" || fail '36-case authority drift'
grep -Fq '"measured_pairs": 12' "$PREREG" || fail 'pair count drift'
grep -Fq '"inner_repetitions_per_case": 200' "$PREREG" || fail 'repetition count drift'
grep -Fq '"target_resolution_relative": 0.05' "$PREREG" || fail 'resolution target drift'
grep -Fq '"qualified_speedup_claim_allowed_on_github_hosted_runner": false' "$PREREG" || fail 'host claim firewall drift'

CURRENT_BASE="$(git merge-base HEAD origin/integration/f-ci-canonical)"
[[ -n "$CURRENT_BASE" ]] || fail 'unable to resolve canonical merge-base'
git diff --quiet "$CURRENT_BASE" HEAD -- src reference || fail 'F-ROSS15 mutated src or reference'
echo "F_ROSS15_RECONCILED_BASE=$CURRENT_BASE"

test "$(git rev-parse HEAD:docs/publication/P2E10_E0_BROAD_PAIRED_MATRIX_RESULT.json)" = "$P2E10_RESULT_BLOB" || fail 'P2E10 result authority drift'
test "$(git rev-parse HEAD:src/solver/mod_soil_water_solver_contract.f90)" = "$SOLVER_CONTRACT_BLOB" || fail 'solver contract drift'
test "$(git rev-parse HEAD:src/adapter/mod_reference_richards_legacy_binding.f90)" = "$REFERENCE_BINDING_BLOB" || fail 'Reference binding drift'
test "$(git rev-parse HEAD:src/solver/mod_rossfast_d3r_soil_water_solver.f90)" = "$ROSSFAST_SOLVER_BLOB" || fail 'RossFast solver drift'
test "$(git rev-parse HEAD:src/runtime/mod_rossfast_d3r_model_binding.f90)" = "$ROSSFAST_MODEL_BINDING_BLOB" || fail 'RossFast model binding drift'
test "$(git rev-parse HEAD:src/runtime/mod_rossfast_d3r_execution_policy.f90)" = "$ROSSFAST_EXECUTION_POLICY_BLOB" || fail 'RossFast execution policy drift'
test "$(git rev-parse HEAD:src/solver/mod_rossfast_d3r_table_provider.f90)" = "$ROSSFAST_TABLE_PROVIDER_BLOB" || fail 'RossFast table provider drift'
test "$(git rev-parse HEAD:benchmarks/performance/isolated-runner-readiness.json)" = "$ISOLATED_READINESS_BLOB" || fail 'isolated-host readiness drift'

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
  src/runtime/mod_rossfast_d3r_execution_policy.f90
  src/runtime/mod_rossfast_d3r_model_binding.f90
  src/solver/mod_rossfast_d3r_table_kernel.f90
  src/solver/mod_rossfast_d3r_table_provider.f90
  src/solver/mod_rossfast_d3r_soil_water_solver.f90
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
gfortran -fopenmp -O2 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/f_ross15_benchmark"

python3 "$RUNNER" --executable "$BUILD/f_ross15_benchmark" --output "$BUILD/F-ROSS15_SCREENING_RESULT.json" | tee "$BUILD/output.txt"

for marker in \
  'F_ROSS15_SCREENING_OUTCOME=' \
  'F_ROSS15_MEAN_RELATIVE_DELTA=' \
  'F_ROSS15_MDE=' \
  'F_ROSS15_MEAN_SPEEDUP=' \
  'F_ROSS15_FORMAL_SPEEDUP_CLAIM=FALSE' \
  'F_ROSS15_SCREENING_GATE=PASS'; do
  grep -Fq "$marker" "$BUILD/output.txt" || fail "missing marker $marker"
done

cp "$BUILD/F-ROSS15_SCREENING_RESULT.json" "${GITHUB_WORKSPACE:-$ROOT}/F-ROSS15_SCREENING_RESULT.json"
echo 'F_ROSS15_PERFORMANCE_SCREEN=PASS'
