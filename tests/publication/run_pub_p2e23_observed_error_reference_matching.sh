#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-p2e23-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "PUB_P2E23_GATE_FAIL $*" >&2; exit 1; }

PREREG=docs/publication/P2E23_OBSERVED_ERROR_REFERENCE_MATCHING_PREREGISTRATION.json
PARENT_RESULT=docs/publication/P2E22_EQUAL_ERROR_REFERENCE_MIGRATION_RESULT.json
TEST=tests/publication/test_pub_p2e23_observed_error_reference_matching.f90
PARENT_BASE=dac6e7b7896f44baa8467eb0b34ba119f5bd2631

PREREG_BLOB=3bba18b556662c44813cbfe0686b0bb9913c24c7
TEST_BLOB=a80da1aa8d994dbd16129e22a4694528778f05a2
P2E22_RESULT_BLOB=60b08f4b953e1f5330d7db9fc2a5729f924de12e

REFERENCE_TREE=684f1e2889b6992e5aedc88f52bb45f4558bb3e4
SOLVER_CONTRACT_BLOB=40a1ddc05fb8e2c1822763de645fd07a094568a3
REFERENCE_BINDING_BLOB=4b545c6fb260e81cd6c8f4d2d65f2beee7281e53
REFERENCE_STATE_BINDING_BLOB=a2488ce3a6a6eff665a59d3dd68907d26f8304ec
MVG_PROVIDER_BLOB=fea5a1681b1c3bdefce1cdbb6d48a9396c8266b6
TOP_PROVIDER_BLOB=fb226f133bd48d8ab945f111c76897aeff49facf
SOURCE_SINK_BLOB=d6c57add72387e5c0022a44319fff08046194aac
ROSSFAST_SOLVER_BLOB=dbb441f3529be179d64fb57f9c44336d3d20c540
ROSSFAST_MODEL_BINDING_BLOB=5442fd7e7a2f392c9b796cd17c76b17977259f22
ROSSFAST_EXECUTION_POLICY_BLOB=a39a636d01f373ae6ef0dc3ac0e1e25b6522fda9
ROSSFAST_TABLE_PROVIDER_BLOB=ac997bf06c56a37080d1c8db69b6d4208f4b75ca
ROSSFAST_TABLE_KERNEL_BLOB=034136c193b287bcf9a953a9b89df2a8fb0c97cc
WORKSPACE_BLOB=74f99556005ae39614f9df678467b1e19097bae2
HEADCALC_BLOB=3ff8d5cfd6963dfb7dafb33ec454fbc0df938a55

[[ -f "$PREREG" && -f "$PARENT_RESULT" && -f "$TEST" ]] || fail 'missing P2E23 authority'
test "$(git rev-parse HEAD:$PREREG)" = "$PREREG_BLOB" || fail 'P2E23 preregistration drift'
test "$(git rev-parse HEAD:$TEST)" = "$TEST_BLOB" || fail 'P2E23 test drift'
test "$(git rev-parse HEAD:$PARENT_RESULT)" = "$P2E22_RESULT_BLOB" || fail 'P2E22 result drift'

grep -Fq '"phase":"PREREGISTERED_BEFORE_OBSERVED_ERROR_REFERENCE_MATCHING"' "$PREREG" || fail 'phase drift'
grep -Fq '"outer_segments":"all integers 1 through 32 inclusive"' "$PREREG" || fail 'dense Reference ladder drift'
grep -Fq '"reference_configuration_count":1152' "$PREREG" || fail 'Reference configuration count drift'
grep -Fq '"outer_segments":1' "$PREREG" || fail 'RossFast N1 anchor drift'
grep -Fq '"timing_calls_allowed":false' "$PREREG" || fail 'timing firewall missing'
grep -Fq '"closest_error_ratio_used_for_selection":false' "$PREREG" || fail 'selection firewall missing'
grep -Fq '"scientific_outcome_is_not_ci_failure":true' "$PREREG" || fail 'scientific outcome firewall missing'

if grep -Eiq '\b(cpu_time|system_clock)\b' "$TEST"; then
  fail 'timing call detected in untimed P2E23 harness'
fi

git merge-base --is-ancestor "$PARENT_BASE" HEAD || fail 'P2E22 result parent is not an ancestor'
git diff --quiet "$PARENT_BASE" HEAD -- src reference || fail 'P2E23 mutated src or reference'
test "$(git rev-parse HEAD:reference)" = "$REFERENCE_TREE" || fail 'reference tree drift'
test "$(git rev-parse HEAD:src/solver/mod_soil_water_solver_contract.f90)" = "$SOLVER_CONTRACT_BLOB" || fail 'solver contract drift'
test "$(git rev-parse HEAD:src/adapter/mod_reference_richards_legacy_binding.f90)" = "$REFERENCE_BINDING_BLOB" || fail 'Reference binding drift'
test "$(git rev-parse HEAD:src/solver/mod_reference_richards_state_binding.f90)" = "$REFERENCE_STATE_BINDING_BLOB" || fail 'Reference state binding drift'
test "$(git rev-parse HEAD:src/solver/mod_b110_default_mvg_provider.f90)" = "$MVG_PROVIDER_BLOB" || fail 'MvG provider drift'
test "$(git rev-parse HEAD:src/solver/mod_fixed_flux_top_boundary_provider.f90)" = "$TOP_PROVIDER_BLOB" || fail 'top-boundary provider drift'
test "$(git rev-parse HEAD:src/solver/mod_b110_source_sink_provider.f90)" = "$SOURCE_SINK_BLOB" || fail 'source/sink provider drift'
test "$(git rev-parse HEAD:src/solver/mod_rossfast_d3r_soil_water_solver.f90)" = "$ROSSFAST_SOLVER_BLOB" || fail 'RossFast solver drift'
test "$(git rev-parse HEAD:src/runtime/mod_rossfast_d3r_model_binding.f90)" = "$ROSSFAST_MODEL_BINDING_BLOB" || fail 'RossFast model binding drift'
test "$(git rev-parse HEAD:src/runtime/mod_rossfast_d3r_execution_policy.f90)" = "$ROSSFAST_EXECUTION_POLICY_BLOB" || fail 'RossFast execution policy drift'
test "$(git rev-parse HEAD:src/solver/mod_rossfast_d3r_table_provider.f90)" = "$ROSSFAST_TABLE_PROVIDER_BLOB" || fail 'RossFast table provider drift'
test "$(git rev-parse HEAD:src/solver/mod_rossfast_d3r_table_kernel.f90)" = "$ROSSFAST_TABLE_KERNEL_BLOB" || fail 'RossFast table kernel drift'
test "$(git rev-parse HEAD:src/solver/mod_reference_richards_workspace.f90)" = "$WORKSPACE_BLOB" || fail 'Reference workspace drift'
test "$(git rev-parse HEAD:src/legacy/b1_10_port/headcalc.f90)" = "$HEADCALC_BLOB" || fail 'HeadCalc drift'

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
  src/solver/mod_rossfast_d3r_table_kernel.f90
  src/solver/mod_rossfast_d3r_table_provider.f90
  src/solver/mod_rossfast_d3r_soil_water_solver.f90
)

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
    fail "P2E23 runtime O$opt"
  fi

  for marker in \
    'PUB_P2E23_CASE_COUNT=36' \
    'PUB_P2E23_REF_HIGH_COUNT=36' \
    'PUB_P2E23_ROSS_ANCHOR_COUNT=36' \
    'PUB_P2E23_REFERENCE_CONFIG_COUNT=1152' \
    'PUB_P2E23_TIMING_EXECUTED=FALSE' \
    'PUB_P2E23_CLOSEST_RATIO_USED_FOR_SELECTION=FALSE' \
    'PUB_P2E23_CONTROL_LEVELS_CHANGED=FALSE' \
    'PUB_P2E23_CASE_POPULATION_CHANGED=FALSE' \
    'PUB_P2E23_SCIENTIFIC_RESULT_IS_CI_FAILURE=FALSE' \
    'PUB_P2E23_OBSERVED_ERROR_REFERENCE_MATCHING_GATE=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing marker $marker"; }
  done

  [[ "$(grep -Fc 'PUB_P2E23_REF_HIGH|' "$OUT/output.txt")" = "36" ]] || fail 'expected 36 REF-HIGH records'
  [[ "$(grep -Fc 'PUB_P2E23_ROSS|' "$OUT/output.txt")" = "36" ]] || fail 'expected 36 Ross anchor records'
  [[ "$(grep -Fc 'PUB_P2E23_REF_CONFIG|' "$OUT/output.txt")" = "1152" ]] || fail 'expected 1152 Reference configuration records'
  [[ "$(grep -Fc 'PUB_P2E23_MATCH|' "$OUT/output.txt")" = "36" ]] || fail 'expected 36 match records'
  [[ "$(grep -Fc 'PUB_P2E23_THRESHOLD|' "$OUT/output.txt")" = "3" ]] || fail 'expected 3 threshold records'

  bracketed="$(grep 'PUB_P2E23_BRACKETED_COUNT=' "$OUT/output.txt" | tail -1 | cut -d= -f2)"
  left="$(grep 'PUB_P2E23_LEFT_CENSORED_COUNT=' "$OUT/output.txt" | tail -1 | cut -d= -f2)"
  gap="$(grep 'PUB_P2E23_UPPER_ONLY_ROUTE_GAP_COUNT=' "$OUT/output.txt" | tail -1 | cut -d= -f2)"
  n32="$(grep 'PUB_P2E23_MATCH_ONLY_AT_N32_COUNT=' "$OUT/output.txt" | tail -1 | cut -d= -f2)"
  unresolved="$(grep 'PUB_P2E23_UNRESOLVED_COUNT=' "$OUT/output.txt" | tail -1 | cut -d= -f2)"
  [[ $((bracketed + left + gap + n32 + unresolved)) -eq 36 ]] || fail 'match classifications do not sum to 36'

  cat "$OUT/output.txt"
  echo "PUB_P2E23_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 P2E23 scientific output drift'
}

echo "PUB_P2E23_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'PUB_P2E23_OBSERVED_ERROR_REFERENCE_MATCHING_GATE=PASS'
