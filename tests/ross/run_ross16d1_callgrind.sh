#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-f-ross16d1-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "F_ROSS16D1_GATE_FAIL $*" >&2; exit 1; }

PREREG=integration/f-ross/F-ROSS16D1_CALLGRIND_PREREGISTRATION.json
TEST=tests/ross/test_ross16d1_callgrind.f90
[[ -f "$PREREG" && -f "$TEST" ]] || fail "missing D1 inputs"

grep -Fq '"phase": "PREREGISTERED_AFTER_GPROF_REJECTION_BEFORE_CALLGRIND_EXECUTION"' "$PREREG" || fail "preregistration drift"
grep -Fq '"profile_repetitions_per_case": 20' "$PREREG" || fail "repetition drift"
grep -Fq '"expected_total_rossfast_kernel_solves": 756' "$PREREG" || fail "kernel solve count drift"
grep -Fq '"expected_total_candidate_steps": 18144' "$PREREG" || fail "candidate-step count drift"

CURRENT_BASE="$(git merge-base HEAD origin/integration/f-ci-canonical)"
[[ -n "$CURRENT_BASE" ]] || fail "cannot resolve canonical merge-base"
git diff --quiet "$CURRENT_BASE" HEAD -- src reference || fail "F-ROSS16D1 mutated src or reference"
test "$(git rev-parse HEAD:integration/f-ross/F-ROSS16_COST_ATTRIBUTION_RESULT.json)" = "97293cb50821330f889abe67eb1452f0a2b33f46" || fail "parent result drift"

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
  shift
  local flags=("$@")
  mkdir -p "$out"
  local objects=()
  for source in "${MODULE_SRC[@]}"; do
    local obj="$out/$(basename "${source%.*}").o"
    local extra=()
    [[ "$source" == "src/solver/mod_soil_water_solver_contract.f90" ]] && extra=(-Wno-error=unused-dummy-argument)
    gfortran "${COMMON[@]}" "${extra[@]}" "${flags[@]}" -J "$out" -I "$out" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" "${flags[@]}" -J "$out" -I "$out" -c "$TEST" -o "$out/test.o"
  gfortran -fopenmp "${flags[@]}" "${objects[@]}" "$out/test.o" -o "$out/test"
}

run_callgrind() {
  local id="$1"
  local exe="$2"
  local out="$BUILD/callgrind_${id}.out"
  SWAP5_ROSS16D1_ROUTE=ROSSFAST OMP_NUM_THREADS=1     valgrind --quiet --tool=callgrind --collect-jumps=yes --callgrind-out-file="$out" "$exe"     > "$BUILD/${id}_run.txt" 2>&1
  grep -Fq 'F_ROSS16D1_GATE=PASS' "$BUILD/${id}_run.txt" || { cat "$BUILD/${id}_run.txt"; fail "${id} harness failed"; }
  [[ -s "$out" ]] || fail "${id} callgrind output missing"
  callgrind_annotate --show=Ir --inclusive=yes --tree=both --threshold=0.01 "$out" > "$BUILD/${id}_functions.txt"
  callgrind_annotate --show=Ir --inclusive=yes --threshold=0.00 "$out"     "$ROOT/src/solver/mod_rossfast_d3r_table_kernel.f90" > "$BUILD/${id}_source.txt"
}

compile_exe "$BUILD/o2" -O2 -g
run_callgrind o2 "$BUILD/o2/test"

compile_exe "$BUILD/noinline" -O2 -g -fno-inline -fno-inline-functions -fno-inline-small-functions
run_callgrind noinline "$BUILD/noinline/test"

echo '--- F-ROSS16D1 optimized Callgrind RossFast symbols ---'
grep -Ei 'candidate_step|table_face_linearization|factor_and_solve|inverse_capacity|head_from_water_content|run_window|rossfast_d3r_table_kernel_solve|request_contract_is_admitted' "$BUILD/o2_functions.txt" || true
echo '--- F-ROSS16D1 no-inline Callgrind RossFast symbols ---'
grep -Ei 'candidate_step|table_face_linearization|factor_and_solve|inverse_capacity|head_from_water_content|run_window|rossfast_d3r_table_kernel_solve|request_contract_is_admitted' "$BUILD/noinline_functions.txt" || true

OUTDIR="${GITHUB_WORKSPACE:-$ROOT}/F-ROSS16D1_EVIDENCE"
rm -rf "$OUTDIR"
mkdir -p "$OUTDIR"
cp "$BUILD/callgrind_o2.out" "$OUTDIR/"
cp "$BUILD/callgrind_noinline.out" "$OUTDIR/"
cp "$BUILD/o2_functions.txt" "$OUTDIR/"
cp "$BUILD/noinline_functions.txt" "$OUTDIR/"
cp "$BUILD/o2_source.txt" "$OUTDIR/"
cp "$BUILD/noinline_source.txt" "$OUTDIR/"
cp "$BUILD/o2_run.txt" "$OUTDIR/"
cp "$BUILD/noinline_run.txt" "$OUTDIR/"

echo 'F_ROSS16D1_CALLGRIND_GATE=PASS'
