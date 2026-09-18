#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-p2e16d1-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
fail(){ echo "PUB_P2E16D1_GATE_FAIL $*" >&2; exit 1; }

PREREG=docs/publication/P2E16D1_REFERENCE_FIXED_STEP_ADJUDICATION_PREREGISTRATION.json
PARENT_RESULT=docs/publication/P2E16B_CANDIDATE_BOUNDARY_PRIMARY_RESULT.json
TEST=tests/publication/test_pub_p2e16d1_reference_fixed_step_adjudication.f90
PREREG_BLOB=dbd77753b5d9a71f6bf45bcba4855d4e94b6898b
TEST_BLOB=6ea73d6552f05f72c0fc256f1b5b52dc66a55a53
PARENT_RESULT_BLOB=faff8f4c961522ebe9ad11902c5cc0d2313734ff
SOLVER_CONTRACT_BLOB=40a1ddc05fb8e2c1822763de645fd07a094568a3
REFERENCE_BINDING_BLOB=4b545c6fb260e81cd6c8f4d2d65f2beee7281e53
MODEL_BINDING_BLOB=5442fd7e7a2f392c9b796cd17c76b17977259f22

test "$(git rev-parse HEAD:$PREREG)" = "$PREREG_BLOB" || fail 'preregistration drift'
test "$(git rev-parse HEAD:$PARENT_RESULT)" = "$PARENT_RESULT_BLOB" || fail 'P2E16B result drift'
test "$(git rev-parse HEAD:$TEST)" = "$TEST_BLOB" || fail 'test drift'
grep -Fq '"RossFast execution"' "$PREREG" || fail 'candidate firewall text missing'
git diff --quiet fe5e34652e5da69c6e97977ca64c82db571e7441 HEAD -- src reference || fail 'P2E16 diagnosis mutated src/reference'
test "$(git rev-parse HEAD:src/solver/mod_soil_water_solver_contract.f90)" = "$SOLVER_CONTRACT_BLOB" || fail 'solver contract drift'
test "$(git rev-parse HEAD:src/adapter/mod_reference_richards_legacy_binding.f90)" = "$REFERENCE_BINDING_BLOB" || fail 'Reference binding drift'
test "$(git rev-parse HEAD:src/runtime/mod_rossfast_d3r_model_binding.f90)" = "$MODEL_BINDING_BLOB" || fail 'model-domain authority drift'

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

for forbidden in src/solver/mod_rossfast_d3r_table_kernel.f90 src/solver/mod_rossfast_d3r_table_provider.f90 src/solver/mod_rossfast_d3r_soil_water_solver.f90; do
 for source in "${MODULE_SRC[@]}"; do [[ "$source" != "$forbidden" ]] || fail "RossFast numerical source entered diagnosis"; done
done

for opt in 0 2; do
 OUT="$BUILD/o$opt"; objects=()
 for source in "${MODULE_SRC[@]}"; do
   obj="$OUT/$(basename "${source%.*}").o"; extra=()
   [[ "$source" == "src/solver/mod_soil_water_solver_contract.f90" ]] && extra=(-Wno-error=unused-dummy-argument)
   gfortran "${COMMON[@]}" "${extra[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
   objects+=("$obj")
 done
 gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/test.o"
 gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
 "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "diagnostic runtime O$opt"; }
 for marker in 'PUB_P2E16D1_CASE_COUNT=5' 'PUB_P2E16D1_ROSSFAST_SOLVER_EXECUTED=FALSE' 'PUB_P2E16D1_THRESHOLDS_CHANGED=FALSE' 'PUB_P2E16D1_REFERENCE_ADJUDICATION_GATE=PASS'; do
   grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing marker $marker"; }
 done
 [[ "$(grep -Fc 'PUB_P2E16D1_CASE|' "$OUT/output.txt")" = "5" ]] || fail 'expected five diagnostic cases'
 cat "$OUT/output.txt"; echo "PUB_P2E16D1_O${opt}=PASS"
done
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || { diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true; fail 'O0/O2 diagnostic drift'; }
echo "PUB_P2E16D1_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'PUB_P2E16D1_REFERENCE_ADJUDICATION_GATE=PASS'
