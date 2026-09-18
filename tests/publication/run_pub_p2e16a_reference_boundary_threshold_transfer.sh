#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-p2e16a-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "PUB_P2E16A_GATE_FAIL $*" >&2; exit 1; }

TEST=tests/publication/test_pub_p2e16a_reference_boundary_threshold_transfer.f90
PREREG=docs/publication/P2E16_ADMISSIBILITY_BOUNDARY_PRIMARY_PREREGISTRATION.json
PARENT_BASE=fe5e34652e5da69c6e97977ca64c82db571e7441
PREREG_BLOB=8c9336594486864d6318e1b52a3e093f774cf2af
TEST_BLOB=6e3642cad1b0fb86c8030ca97e6c0fa368ffb0d7
P2E14_RESULT_BLOB=f9f49ce5f0f239d1c1cdd4575a4da65cd84c0351
P2E15_RESULT_BLOB=2b3a911e6117e8e3af24c633a106e58fa7358a19
REFERENCE_TREE=684f1e2889b6992e5aedc88f52bb45f4558bb3e4

SOLVER_CONTRACT_BLOB=40a1ddc05fb8e2c1822763de645fd07a094568a3
REFERENCE_BINDING_BLOB=4b545c6fb260e81cd6c8f4d2d65f2beee7281e53
REFERENCE_STATE_BINDING_BLOB=a2488ce3a6a6eff665a59d3dd68907d26f8304ec
MVG_PROVIDER_BLOB=fea5a1681b1c3bdefce1cdbb6d48a9396c8266b6
TOP_PROVIDER_BLOB=fb226f133bd48d8ab945f111c76897aeff49facf
SOURCE_SINK_BLOB=d6c57add72387e5c0022a44319fff08046194aac
MODEL_BINDING_BLOB=5442fd7e7a2f392c9b796cd17c76b17977259f22
WORKSPACE_BLOB=74f99556005ae39614f9df678467b1e19097bae2
HEADCALC_BLOB=3ff8d5cfd6963dfb7dafb33ec454fbc0df938a55

[[ -f "$PREREG" ]] || fail 'missing P2E16 preregistration'
[[ -f "$TEST" ]] || fail 'missing P2E16A test'
test "$(git rev-parse HEAD:$PREREG)" = "$PREREG_BLOB" || fail 'P2E16 preregistration drift'
test "$(git rev-parse HEAD:$TEST)" = "$TEST_BLOB" || fail 'P2E16A test drift'

grep -Fq '"phase": "PREREGISTERED_BEFORE_BOUNDARY_REFERENCE_OR_CANDIDATE_EXECUTION"' "$PREREG" || fail 'preregistration phase drift'
grep -Fq '"candidate_execution_allowed": false' "$PREREG" || fail 'Stage A candidate firewall missing'
grep -Fq '"p2e14_threshold_change_allowed": false' "$PREREG" || fail 'P2E14 threshold freeze missing'
grep -Fq '"material_or_state_case_removal_allowed": false' "$PREREG" || fail 'case-retention firewall missing'
grep -Fq '"performance_claim_authorized": false' "$PREREG" || fail 'performance firewall missing'

git merge-base --is-ancestor "$PARENT_BASE" HEAD || fail 'P2E15 parent is not an ancestor'
git diff --quiet "$PARENT_BASE" HEAD -- src reference || fail 'P2E16A mutated src or reference'
test "$(git rev-parse HEAD:reference)" = "$REFERENCE_TREE" || fail 'reference tree drift'
test "$(git rev-parse HEAD:src/solver/mod_soil_water_solver_contract.f90)" = "$SOLVER_CONTRACT_BLOB" || fail 'solver contract drift'
test "$(git rev-parse HEAD:src/adapter/mod_reference_richards_legacy_binding.f90)" = "$REFERENCE_BINDING_BLOB" || fail 'Reference binding drift'
test "$(git rev-parse HEAD:src/solver/mod_reference_richards_state_binding.f90)" = "$REFERENCE_STATE_BINDING_BLOB" || fail 'Reference state binding drift'
test "$(git rev-parse HEAD:src/solver/mod_b110_default_mvg_provider.f90)" = "$MVG_PROVIDER_BLOB" || fail 'MvG provider drift'
test "$(git rev-parse HEAD:src/solver/mod_fixed_flux_top_boundary_provider.f90)" = "$TOP_PROVIDER_BLOB" || fail 'top-boundary provider drift'
test "$(git rev-parse HEAD:src/solver/mod_b110_source_sink_provider.f90)" = "$SOURCE_SINK_BLOB" || fail 'source/sink provider drift'
test "$(git rev-parse HEAD:src/runtime/mod_rossfast_d3r_model_binding.f90)" = "$MODEL_BINDING_BLOB" || fail 'RossFast model-boundary authority drift'
test "$(git rev-parse HEAD:src/solver/mod_reference_richards_workspace.f90)" = "$WORKSPACE_BLOB" || fail 'Reference workspace drift'
test "$(git rev-parse HEAD:src/legacy/b1_10_port/headcalc.f90)" = "$HEADCALC_BLOB" || fail 'HeadCalc drift'
test "$(git rev-parse HEAD:docs/publication/P2E14_REFERENCE_COMMON_MATERIAL_THRESHOLD_FREEZE_RESULT.json)" = "$P2E14_RESULT_BLOB" || fail 'P2E14 threshold authority drift'
test "$(git rev-parse HEAD:docs/publication/P2E15_MATERIAL_EXTENSION_PRIMARY_RESULT.json)" = "$P2E15_RESULT_BLOB" || fail 'P2E15 parent evidence drift'

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

for forbidden in   src/solver/mod_rossfast_d3r_table_kernel.f90   src/solver/mod_rossfast_d3r_table_provider.f90   src/solver/mod_rossfast_d3r_soil_water_solver.f90   src/runtime/mod_fmr_rossfast_solver_selection_binding.f90; do
  for source in "${MODULE_SRC[@]}"; do
    [[ "$source" != "$forbidden" ]] || fail "RossFast numerical implementation entered Reference-only Stage A build: $forbidden"
  done
done

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    [[ -f "$source" ]] || fail "missing compile source $source"
    obj="$OUT/$(basename "${source%.*}").o"
    extra=()
    [[ "$source" == "src/solver/mod_soil_water_solver_contract.f90" ]] && extra=(-Wno-error=unused-dummy-argument)
    gfortran "${COMMON[@]}" "${extra[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/test.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"

  if ! "$OUT/test" > "$OUT/output.txt" 2>&1; then
    cat "$OUT/output.txt" >&2
    fail "P2E16A Reference boundary threshold-transfer diagnostic O$opt"
  fi

  for marker in     'PUB_P2E16A_PHYSICAL_CASE_COUNT=1296'     'PUB_P2E16A_MATERIAL_COUNT=36'     'PUB_P2E16A_SE_LEVEL_COUNT=3'     'PUB_P2E16A_BOUNDARY_AXIS_COUNT=2'     'PUB_P2E16A_RHO_LEVEL_COUNT=6'     'PUB_P2E16A_INSIDE_COUNT=432'     'PUB_P2E16A_BOUNDARY_COUNT=432'     'PUB_P2E16A_OUTSIDE_COUNT=432'     'PUB_P2E16A_ROSSFAST_SOLVER_EXECUTED=FALSE'     'PUB_P2E16A_P2E14_THRESHOLDS_CHANGED=FALSE'     'PUB_P2E16A_SCIENTIFIC_FAILURE_IS_CI_FAILURE=FALSE'     'PUB_P2E16A_REFERENCE_BOUNDARY_THRESHOLD_TRANSFER_GATE=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing O$opt marker $marker"; }
  done

  trial_lines="$(grep -Fc 'PUB_P2E16A_TRIAL|' "$OUT/output.txt")"
  [[ "$trial_lines" = "1296" ]] || { cat "$OUT/output.txt" >&2; fail "expected 1296 P2E16A trial lines, got $trial_lines"; }

  cat "$OUT/output.txt"
  echo "PUB_P2E16A_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 P2E16A scientific output drift'
}

echo "PUB_P2E16A_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'PUB_P2E16A_REFERENCE_BOUNDARY_THRESHOLD_TRANSFER_GATE=PASS'
