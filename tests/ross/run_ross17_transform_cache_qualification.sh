#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE=79d30219d484acfadde0a22484ca6305a541d868
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-f-ross17-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/baseline" "$BUILD/candidate"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "F_ROSS17_GATE_FAIL $*" >&2; exit 1; }

PREREG=integration/f-ross/F-ROSS17_TRANSFORM_CACHE_PREREGISTRATION.json
STATE_TEST=tests/ross/test_ross17_state_dump.f90
PERF_TEST=tests/ross/test_ross15_reference_vs_rossfast_performance.f90
SCI_COMPARE=tools/performance/f_ross17_scientific_compare.py
PAIR_SCREEN=tools/performance/f_ross17_paired_screen.py
REF_SCREEN=tools/performance/f_ross15_paired_screen.py
KERNEL=src/solver/mod_rossfast_d3r_table_kernel.f90

for p in "$PREREG" "$STATE_TEST" "$PERF_TEST" "$SCI_COMPARE" "$PAIR_SCREEN" "$REF_SCREEN" "$KERNEL"; do
  [[ -f "$p" ]] || fail "missing $p"
done

grep -Fq '"phase": "PREREGISTERED_BEFORE_PRODUCTION_MUTATION"' "$PREREG" || fail "preregistration phase drift"
grep -Fq '"candidate_steps_per_solver_call": 24' "$PREREG" || fail "candidate-step topology drift"
grep -Fq '"certificate_internal_substeps": 8' "$PREREG" || fail "substep topology drift"

git cat-file -e "$BASE^{commit}" || fail "baseline commit unavailable"
test "$(git rev-parse "$BASE:$KERNEL")" = "034136c193b287bcf9a953a9b89df2a8fb0c97cc" || fail "baseline kernel authority drift"
test "$(git rev-parse "$BASE:src/solver/mod_rossfast_d3r_soil_water_solver.f90")" = "dbb441f3529be179d64fb57f9c44336d3d20c540" || fail "baseline solver binding drift"

mapfile -t PROD_DIFF < <(git diff --name-only "$BASE" HEAD -- src reference)
if [[ "${#PROD_DIFF[@]}" -ne 1 || "${PROD_DIFF[0]}" != "$KERNEL" ]]; then
  printf 'F_ROSS17_UNEXPECTED_PRODUCTION_DIFF=%s\n' "${PROD_DIFF[@]:-NONE}" >&2
  fail "production mutation escaped single-kernel scope"
fi

git show "$BASE:$KERNEL" > "$BUILD/baseline/mod_rossfast_d3r_table_kernel.f90"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fopenmp -O2)
MODULES_BEFORE_KERNEL=(
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
)
MODULES_AFTER_KERNEL=(
  src/solver/mod_rossfast_d3r_table_provider.f90
  src/solver/mod_rossfast_d3r_soil_water_solver.f90
)

compile_variant() {
  local out="$1"
  local kernel_src="$2"
  local objects=()
  local source obj
  for source in "${MODULES_BEFORE_KERNEL[@]}"; do
    obj="$out/$(basename "${source%.*}").o"
    extra=()
    [[ "$source" == "src/solver/mod_soil_water_solver_contract.f90" ]] && extra=(-Wno-error=unused-dummy-argument)
    gfortran "${COMMON[@]}" "${extra[@]}" -J "$out" -I "$out" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  obj="$out/mod_rossfast_d3r_table_kernel.o"
  gfortran "${COMMON[@]}" -J "$out" -I "$out" -c "$kernel_src" -o "$obj"
  objects+=("$obj")
  for source in "${MODULES_AFTER_KERNEL[@]}"; do
    obj="$out/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -J "$out" -I "$out" -c "$source" -o "$obj"
    objects+=("$obj")
  done

  gfortran "${COMMON[@]}" -J "$out" -I "$out" -c "$STATE_TEST" -o "$out/state_test.o"
  gfortran -fopenmp -O2 "${objects[@]}" "$out/state_test.o" -o "$out/state_test"

  gfortran "${COMMON[@]}" -J "$out" -I "$out" -c "$PERF_TEST" -o "$out/perf_test.o"
  gfortran -fopenmp -O2 "${objects[@]}" "$out/perf_test.o" -o "$out/perf_test"
}

compile_variant "$BUILD/baseline" "$BUILD/baseline/mod_rossfast_d3r_table_kernel.f90"
compile_variant "$BUILD/candidate" "$KERNEL"

"$BUILD/baseline/state_test" > "$BUILD/baseline_state.txt"
"$BUILD/candidate/state_test" > "$BUILD/candidate_state.txt"
grep -Fq 'F_ROSS17_STATE_DUMP_GATE=PASS' "$BUILD/baseline_state.txt" || fail "baseline scientific harness failed"
grep -Fq 'F_ROSS17_STATE_DUMP_GATE=PASS' "$BUILD/candidate_state.txt" || fail "candidate scientific harness failed"

python3 "$SCI_COMPARE" \
  --baseline "$BUILD/baseline_state.txt" \
  --candidate "$BUILD/candidate_state.txt" \
  --output "$BUILD/F-ROSS17_SCIENTIFIC_RESULT.json" | tee "$BUILD/scientific_summary.txt"
grep -Fq 'F_ROSS17_SCIENTIFIC_GATE=PASS' "$BUILD/scientific_summary.txt" || fail "scientific equivalence failed"

python3 "$PAIR_SCREEN" \
  --baseline "$BUILD/baseline/perf_test" \
  --candidate "$BUILD/candidate/perf_test" \
  --output "$BUILD/F-ROSS17_PERFORMANCE_RESULT.json" | tee "$BUILD/performance_summary.txt"
grep -Fq 'F_ROSS17_PERFORMANCE_GATE=PASS' "$BUILD/performance_summary.txt" || fail "paired performance screen failed"

python3 "$REF_SCREEN" \
  --executable "$BUILD/candidate/perf_test" \
  --output "$BUILD/F-ROSS17_CANDIDATE_VS_REFERENCE.json" | tee "$BUILD/reference_summary.txt"
grep -Fq 'F_ROSS15_SCREENING_GATE=PASS' "$BUILD/reference_summary.txt" || fail "candidate-vs-Reference screen failed"

OUTDIR="${GITHUB_WORKSPACE:-$ROOT}/F-ROSS17_EVIDENCE"
rm -rf "$OUTDIR"; mkdir -p "$OUTDIR"
cp "$BUILD/F-ROSS17_SCIENTIFIC_RESULT.json" "$OUTDIR/"
cp "$BUILD/F-ROSS17_PERFORMANCE_RESULT.json" "$OUTDIR/"
cp "$BUILD/F-ROSS17_CANDIDATE_VS_REFERENCE.json" "$OUTDIR/"
cp "$BUILD/baseline_state.txt" "$OUTDIR/"
cp "$BUILD/candidate_state.txt" "$OUTDIR/"
cp "$BUILD/scientific_summary.txt" "$OUTDIR/"
cp "$BUILD/performance_summary.txt" "$OUTDIR/"
cp "$BUILD/reference_summary.txt" "$OUTDIR/"

echo 'F_ROSS17_QUALIFICATION_GATE=PASS'
