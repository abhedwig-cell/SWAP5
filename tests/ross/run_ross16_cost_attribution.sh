#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-f-ross16-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "F_ROSS16_GATE_FAIL $*" >&2; exit 1; }

PREREG=integration/f-ross/F-ROSS16_COST_ATTRIBUTION_PREREGISTRATION.json
WORK_TEST=tests/ross/test_ross16_work_counts.f90
PROFILE_TEST=tests/ross/test_ross16_profile.f90
SUMMARIZER=tools/performance/f_ross16_work_counts.py

for path in "$PREREG" "$WORK_TEST" "$PROFILE_TEST" "$SUMMARIZER"; do
  [[ -f "$path" ]] || fail "missing $path"
done

grep -Fq '"phase": "PREREGISTERED_BEFORE_DIAGNOSTIC_EXECUTION"' "$PREREG" || fail "preregistration drift"
grep -Fq '"profile_repetitions_per_case": 5000' "$PREREG" || fail "profile repetition drift"
grep -Fq '"expected_structural_rossfast_linear_solves_per_successful_solve": 24' "$PREREG" || fail "work-count hypothesis drift"
grep -Fq '"src_mutation_allowed": false' "$PREREG" || fail "source firewall drift"

CURRENT_BASE="$(git merge-base HEAD origin/integration/f-ci-canonical)"
[[ -n "$CURRENT_BASE" ]] || fail "unable to resolve canonical merge-base"
git diff --quiet "$CURRENT_BASE" HEAD -- src reference || fail "F-ROSS16 mutated src or reference"
echo "F_ROSS16_RECONCILED_BASE=$CURRENT_BASE"

test "$(git rev-parse HEAD:integration/f-ross/F-ROSS15_PERFORMANCE_RESULT.json)" = "8c0224960999ce523fb04c592ddc999c35697862" || fail "F-ROSS15 result authority drift"
test "$(git rev-parse HEAD:tests/ross/test_ross15_reference_vs_rossfast_performance.f90)" = "d9e2cb15317f0c8e19ea4a029c6c6a19d98d03b5" || fail "F-ROSS15 harness authority drift"
test "$(git rev-parse HEAD:src/adapter/mod_reference_richards_legacy_binding.f90)" = "4b545c6fb260e81cd6c8f4d2d65f2beee7281e53" || fail "Reference binding drift"
test "$(git rev-parse HEAD:src/solver/mod_rossfast_d3r_soil_water_solver.f90)" = "dbb441f3529be179d64fb57f9c44336d3d20c540" || fail "RossFast solver drift"
test "$(git rev-parse HEAD:src/solver/mod_rossfast_d3r_table_kernel.f90)" = "034136c193b287bcf9a953a9b89df2a8fb0c97cc" || fail "RossFast kernel drift"
test "$(git rev-parse HEAD:src/runtime/mod_rossfast_d3r_model_binding.f90)" = "5442fd7e7a2f392c9b796cd17c76b17977259f22" || fail "RossFast model binding drift"

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

compile_exe() {
  local out="$1"
  local test_src="$2"
  shift 2
  local flags=("$@")
  mkdir -p "$out"
  local objects=()
  for source in "${MODULE_SRC[@]}"; do
    [[ -f "$source" ]] || fail "missing compile source $source"
    local obj="$out/$(basename "${source%.*}").o"
    local extra=()
    [[ "$source" == "src/solver/mod_soil_water_solver_contract.f90" ]] && extra=(-Wno-error=unused-dummy-argument)
    gfortran "${COMMON[@]}" "${extra[@]}" "${flags[@]}" -J "$out" -I "$out" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" "${flags[@]}" -J "$out" -I "$out" -c "$test_src" -o "$out/test.o"
  gfortran -fopenmp "${flags[@]}" "${objects[@]}" "$out/test.o" -o "$out/test"
}

# Stage 1: exact production-published work counts.
compile_exe "$BUILD/work" "$WORK_TEST" -O2
"$BUILD/work/test" | tee "$BUILD/work_counts.txt"
grep -Fq 'F_ROSS16_WORK_COUNT_GATE=PASS' "$BUILD/work_counts.txt" || fail "work-count gate missing"
python3 "$SUMMARIZER" "$BUILD/work_counts.txt" "$BUILD/F-ROSS16_WORK_COUNTS.json" > "$BUILD/work_count_summary.txt"
grep -Fq 'F_ROSS16_WORK_COUNT_SUMMARY=PASS' "$BUILD/work_count_summary.txt" || fail "work-count summary failed"
cat "$BUILD/work_count_summary.txt"

# Historical gprof stages are intentionally not replayed here.
# Their helper-level attribution was rejected after semantic call-count
# inconsistency and has been superseded by qualified F-ROSS16D1 Callgrind
# evidence. Admission authority is the exact solver-published work-count audit
# plus the separately qualified deterministic D1 result.
D1_RESULT=integration/f-ross/F-ROSS16D1_CALLGRIND_RESULT.json
[[ -f "$D1_RESULT" ]] || fail "qualified F-ROSS16D1 result missing"
grep -Fq '"phase": "QUALIFIED_DETERMINISTIC_INSTRUCTION_ATTRIBUTION"' "$D1_RESULT" || fail "D1 qualification drift"
grep -Fq '"call_counts_match_exact_production_topology": true' "$D1_RESULT" || fail "D1 topology authority drift"
grep -Fq '"candidate_step_fraction_of_solver_solve": 0.9554209675818706' "$D1_RESULT" || fail "D1 optimized attribution drift"

OUTDIR="${GITHUB_WORKSPACE:-$ROOT}/F-ROSS16_EVIDENCE"
rm -rf "$OUTDIR"
mkdir -p "$OUTDIR"
cp "$BUILD/F-ROSS16_WORK_COUNTS.json" "$OUTDIR/"
cp "$BUILD/work_counts.txt" "$OUTDIR/"
cp "$D1_RESULT" "$OUTDIR/"

echo 'F_ROSS16_PROFILE_AUTHORITY=REJECTED_GPROF_SUPERSEDED_BY_F_ROSS16D1'
echo 'F_ROSS16_COST_ATTRIBUTION_GATE=PASS'
