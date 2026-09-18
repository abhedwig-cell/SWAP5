#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-p2e16d-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"; trap 'rm -rf "$BUILD"' EXIT; cd "$ROOT"
fail(){ echo "PUB_P2E16D_GATE_FAIL $*" >&2; exit 1; }

PREREG=docs/publication/P2E16D_REFERENCE_ITERATION_BUDGET_SENSITIVITY_PREREGISTRATION.json
PARENT_RESULT=docs/publication/P2E16C_REFERENCE_FIXED_STEP_ADJUDICATION_RESULT.json
TEST=tests/publication/test_pub_p2e16d_reference_iteration_budget_sensitivity.f90
PARENT_BASE=7751ad0c37857dd4bbe8f79b0113bd3da6c87c9f
PREREG_BLOB=4e027f5417b67e2285dfbe76f0142814e122efc8
TEST_BLOB=c14014debcf23aba894e6f4ea950e188f8f9c480
PARENT_RESULT_BLOB=fd7f51df015c141e3eca488f391cd095e98a57a4

[[ -f "$PREREG" && -f "$PARENT_RESULT" && -f "$TEST" ]] || fail 'missing authority'
test "$(git rev-parse HEAD:$PREREG)" = "$PREREG_BLOB" || fail 'prereg drift'
test "$(git rev-parse HEAD:$TEST)" = "$TEST_BLOB" || fail 'test drift'
test "$(git rev-parse HEAD:$PARENT_RESULT)" = "$PARENT_RESULT_BLOB" || fail 'parent result drift'
grep -Fq '"fixed_step_duration_day":0.0016' "$PREREG" || fail 'dt drift'
grep -Fq '"max_iterations":[16,24,32,48,64]' "$PREREG" || fail 'budget drift'
grep -Fq '"max_backtracking":8' "$PREREG" || fail 'backtracking drift'
grep -Fq '"candidate_execution_allowed":false' "$PREREG" || fail 'Reference-only firewall missing'
git merge-base --is-ancestor "$PARENT_BASE" HEAD || fail 'parent not ancestor'
git diff --quiet "$PARENT_BASE" HEAD -- src reference || fail 'src/reference mutated'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -fopenmp -ffpe-trap=invalid,zero,overflow)
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
)

for opt in 0 2; do
 OUT="$BUILD/o$opt"; objects=()
 for source in "${MODULE_SRC[@]}"; do
   obj="$OUT/$(basename "${source%.*}").o"; extra=()
   [[ "$source" == "src/solver/mod_soil_water_solver_contract.f90" ]] && extra=(-Wno-error=unused-dummy-argument)
   gfortran "${COMMON[@]}" "${extra[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"; objects+=("$obj")
 done
 gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/test.o"
 gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
 if ! "$OUT/test" > "$OUT/output.txt" 2>&1; then cat "$OUT/output.txt" >&2; fail "runtime O$opt"; fi
 for marker in    'PUB_P2E16D_CASE_COUNT=25'    'PUB_P2E16D_ROSSFAST_EXECUTED=FALSE'    'PUB_P2E16D_DT_CHANGED=FALSE'    'PUB_P2E16D_BACKTRACK_CHANGED=FALSE'    'PUB_P2E16D_PRIMARY_RESULT_CHANGED=FALSE'    'PUB_P2E16D_DIAGNOSTIC_RESULT_IS_CI_FAILURE=FALSE'    'PUB_P2E16D_REFERENCE_ITERATION_SENSITIVITY_GATE=PASS'; do
   grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing marker $marker"; }
 done
 [[ "$(grep -Fc 'PUB_P2E16D_TRIAL|' "$OUT/output.txt")" = "25" ]] || fail 'expected 25 trials'
 cat "$OUT/output.txt"; echo "PUB_P2E16D_O${opt}=PASS"
done
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || { diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true; fail 'O0/O2 drift'; }
echo "PUB_P2E16D_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'PUB_P2E16D_REFERENCE_ITERATION_SENSITIVITY_GATE=PASS'
