#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-p2e16c-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "PUB_P2E16C_GATE_FAIL $*" >&2; exit 1; }

PREREG=docs/publication/P2E16C_REFERENCE_FIXED_STEP_ADJUDICATION_PREREGISTRATION.json
PRIMARY_RESULT=docs/publication/P2E16B_CANDIDATE_BOUNDARY_PRIMARY_RESULT.json
TEST=tests/publication/test_pub_p2e16c_reference_fixed_step_adjudication.f90
PARENT_BASE=5bbd6d9c6d2849550d7121098413fa3f135c2f1e

PREREG_BLOB=2aff99a80e463b59d9223a47dfc9c5487dfae363
TEST_BLOB=67807798c1a5b480c785e56834fa642d3dc154e4
PRIMARY_RESULT_BLOB=8c12656871d2ed2af50d352b07cba7bf59e0cefe
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

[[ -f "$PREREG" ]] || fail 'missing P2E16C preregistration'
[[ -f "$PRIMARY_RESULT" ]] || fail 'missing immutable P2E16B primary result'
[[ -f "$TEST" ]] || fail 'missing P2E16C test'

test "$(git rev-parse HEAD:$PREREG)" = "$PREREG_BLOB" || fail 'P2E16C preregistration drift'
test "$(git rev-parse HEAD:$TEST)" = "$TEST_BLOB" || fail 'P2E16C test drift'
test "$(git rev-parse HEAD:$PRIMARY_RESULT)" = "$PRIMARY_RESULT_BLOB" || fail 'P2E16B primary result drift'

grep -Fq '"phase": "PREREGISTERED_BEFORE_REFERENCE_ADJUDICATION_EXECUTION"' "$PREREG" || fail 'preregistration phase drift'
grep -Fq '"retroactive_upgrade_of_848_of_850_forbidden": true' "$PREREG" || fail 'primary-count firewall missing'
grep -Fq '"rossfast_execution_allowed": false' "$PREREG" || fail 'Reference-only firewall missing'
grep -Fq '"control_retuning_allowed": false' "$PREREG" || fail 'numerical-control firewall missing'
grep -Fq '"step_duration_day": [0.0064,0.0032,0.0016,0.0008,0.0004,0.0002,0.0001]' "$PREREG" || fail 'single-step ladder drift'
grep -Fq '"substep_counts": [1,2,4,8,16]' "$PREREG" || fail 'same-horizon sequence drift'

git merge-base --is-ancestor "$PARENT_BASE" HEAD || fail 'P2E16B result parent is not an ancestor'
git diff --quiet "$PARENT_BASE" HEAD -- src reference || fail 'P2E16C mutated src or reference'
test "$(git rev-parse HEAD:reference)" = "$REFERENCE_TREE" || fail 'reference tree drift'
test "$(git rev-parse HEAD:src/solver/mod_soil_water_solver_contract.f90)" = "$SOLVER_CONTRACT_BLOB" || fail 'solver contract drift'
test "$(git rev-parse HEAD:src/adapter/mod_reference_richards_legacy_binding.f90)" = "$REFERENCE_BINDING_BLOB" || fail 'Reference binding drift'
test "$(git rev-parse HEAD:src/solver/mod_reference_richards_state_binding.f90)" = "$REFERENCE_STATE_BINDING_BLOB" || fail 'Reference state binding drift'
test "$(git rev-parse HEAD:src/solver/mod_b110_default_mvg_provider.f90)" = "$MVG_PROVIDER_BLOB" || fail 'MvG provider drift'
test "$(git rev-parse HEAD:src/solver/mod_fixed_flux_top_boundary_provider.f90)" = "$TOP_PROVIDER_BLOB" || fail 'top-boundary provider drift'
test "$(git rev-parse HEAD:src/solver/mod_b110_source_sink_provider.f90)" = "$SOURCE_SINK_BLOB" || fail 'source/sink provider drift'
test "$(git rev-parse HEAD:src/runtime/mod_rossfast_d3r_model_binding.f90)" = "$MODEL_BINDING_BLOB" || fail 'material/boundary authority drift'
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
)

for forbidden in   src/solver/mod_rossfast_d3r_table_kernel.f90   src/solver/mod_rossfast_d3r_table_provider.f90   src/solver/mod_rossfast_d3r_soil_water_solver.f90   src/runtime/mod_fmr_rossfast_solver_selection_binding.f90; do
  for source in "${MODULE_SRC[@]}"; do
    [[ "$source" != "$forbidden" ]] || fail "RossFast numerical implementation entered Reference-only adjudication: $forbidden"
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
    fail "P2E16C Reference adjudication runtime O$opt"
  fi

  for marker in     'PUB_P2E16C_CASE_COUNT=5'     'PUB_P2E16C_SINGLE_SOLVE_COUNT=35'     'PUB_P2E16C_SEQUENCE_COUNT=25'     'PUB_P2E16C_ROSSFAST_EXECUTED=FALSE'     'PUB_P2E16C_NUMERICAL_CONTROLS_CHANGED=FALSE'     'PUB_P2E16C_PRIMARY_RESULT_CHANGED=FALSE'     'PUB_P2E16C_DIAGNOSTIC_RESULT_IS_CI_FAILURE=FALSE'     'PUB_P2E16C_REFERENCE_FIXED_STEP_ADJUDICATION_GATE=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing O$opt marker $marker"; }
  done

  singles="$(grep -Fc 'PUB_P2E16C_SINGLE|' "$OUT/output.txt")"
  sequences="$(grep -Fc 'PUB_P2E16C_SEQUENCE|' "$OUT/output.txt")"
  [[ "$singles" = "35" ]] || fail "expected 35 single-step records, got $singles"
  [[ "$sequences" = "25" ]] || fail "expected 25 sequence records, got $sequences"

  cat "$OUT/output.txt"
  echo "PUB_P2E16C_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 P2E16C adjudication output drift'
}

echo "PUB_P2E16C_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'PUB_P2E16C_REFERENCE_FIXED_STEP_ADJUDICATION_GATE=PASS'
