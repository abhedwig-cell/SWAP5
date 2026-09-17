#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-p2e08-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "PUB_P2E08_GATE_FAIL $*" >&2; exit 1; }

TEST=tests/publication/test_pub_p2e08_reference_valid_calibration_domain.f90
PREREG=docs/publication/P2E08_REFERENCE_VALID_CALIBRATION_DOMAIN_PREREGISTRATION.json
CANONICAL_BASE=b142669ddc8c280ef08b31f5af65c120c1cfeaf1
REFERENCE_TREE=684f1e2889b6992e5aedc88f52bb45f4558bb3e4
SOLVER_CONTRACT_BLOB=40a1ddc05fb8e2c1822763de645fd07a094568a3
MODEL_BINDING_BLOB=5442fd7e7a2f392c9b796cd17c76b17977259f22
REFERENCE_BINDING_BLOB=4b545c6fb260e81cd6c8f4d2d65f2beee7281e53
WORKSPACE_BLOB=74f99556005ae39614f9df678467b1e19097bae2
HEADCALC_BLOB=3ff8d5cfd6963dfb7dafb33ec454fbc0df938a55
P2E07_RESULT_BLOB=be60ba751141545e1534f190e709dc5d2b7b83e6

[[ -f "$PREREG" ]] || fail 'missing preregistration'
grep -Fq '"phase": "PREREGISTERED_BEFORE_REFERENCE_DOMAIN_EXECUTION"' "$PREREG" || fail 'preregistration phase missing'
grep -Fq '"rossfast_numerical_solver_execution_allowed": false' "$PREREG" || fail 'RossFast execution firewall missing'
grep -Fq '"physical_case_removal_allowed": false' "$PREREG" || fail 'physical-case retention firewall missing'
grep -Fq '"reference_tolerance_change_allowed": false' "$PREREG" || fail 'Reference tolerance firewall missing'
grep -Fq '"threshold_formula_freezing_allowed": false' "$PREREG" || fail 'threshold formula firewall missing'

git merge-base --is-ancestor "$CANONICAL_BASE" HEAD || fail 'canonical base is not an ancestor'
git diff --quiet "$CANONICAL_BASE" HEAD -- src reference || fail 'P2E08 mutated src or reference'
test "$(git rev-parse HEAD:reference)" = "$REFERENCE_TREE" || fail 'reference tree drift'
test "$(git rev-parse HEAD:src/solver/mod_soil_water_solver_contract.f90)" = "$SOLVER_CONTRACT_BLOB" || fail 'solver contract drift'
test "$(git rev-parse HEAD:src/runtime/mod_rossfast_d3r_model_binding.f90)" = "$MODEL_BINDING_BLOB" || fail 'material-domain binding drift'
test "$(git rev-parse HEAD:src/adapter/mod_reference_richards_legacy_binding.f90)" = "$REFERENCE_BINDING_BLOB" || fail 'Reference binding drift'
test "$(git rev-parse HEAD:src/solver/mod_reference_richards_workspace.f90)" = "$WORKSPACE_BLOB" || fail 'Reference workspace drift'
test "$(git rev-parse HEAD:src/legacy/b1_10_port/headcalc.f90)" = "$HEADCALC_BLOB" || fail 'HeadCalc drift'
test "$(git rev-parse HEAD:docs/publication/P2E07_REFERENCE_CANCELLATION_FLOOR_RESULT.json)" = "$P2E07_RESULT_BLOB" || fail 'P2E07 authority drift'

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
    [[ "$source" != "$forbidden" ]] || fail "RossFast numerical implementation entered Reference-only build: $forbidden"
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
    fail "Reference valid-domain diagnostic O$opt"
  fi

  for marker in     'PUB_P2E08_PHYSICAL_CASE_COUNT=54'     'PUB_P2E08_TEMPORAL_LEVEL_COUNT=5'     'PUB_P2E08_TRIAL_PAIR_COUNT=270'     'PUB_P2E08_ROSSFAST_SOLVER_EXECUTED=FALSE'     'PUB_P2E08_THRESHOLD_FROZEN=FALSE'     'PUB_P2E08_REFERENCE_TOLERANCE_CHANGED=FALSE'     'PUB_P2E08_P2E03_REPAIRED_OR_RECLASSIFIED=FALSE'     'PUB_P2E08_REFERENCE_VALID_CALIBRATION_DOMAIN_GATE=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing O$opt marker $marker"; }
  done

  feasibility_lines="$(grep -Fc 'PUB_P2E08_DT_FEASIBILITY|' "$OUT/output.txt")"
  [[ "$feasibility_lines" = "5" ]] || { cat "$OUT/output.txt" >&2; fail "expected five temporal feasibility summaries"; }

  if grep -Fq 'PUB_P2E08_COMMON_DOMAIN_STATUS=QUALIFIED_COMPLETE_REFERENCE_DOMAIN' "$OUT/output.txt"; then
    grep -Fq 'PUB_P2E08_SELECTED_VALID_CASE_COUNT=54' "$OUT/output.txt" || fail "qualified domain did not retain 54/54 cases"
    selected_lines="$(grep -Fc 'PUB_P2E08_SELECTED_CASE|' "$OUT/output.txt")"
    [[ "$selected_lines" = "54" ]] || fail "qualified domain did not emit 54 selected cases"
  elif grep -Fq 'PUB_P2E08_COMMON_DOMAIN_STATUS=BLOCKED_REFERENCE_COMMON_DOMAIN' "$OUT/output.txt"; then
    grep -Fq 'PUB_P2E08_SCIENTIFIC_OUTCOME=NEGATIVE_COMMON_DOMAIN_NOT_FOUND' "$OUT/output.txt" || fail "blocked domain missing negative-outcome marker"
  else
    cat "$OUT/output.txt" >&2
    fail "missing qualified or blocked scientific outcome"
  fi

  cat "$OUT/output.txt"
  echo "PUB_P2E08_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 Reference valid-domain output drift'
}

echo "PUB_P2E08_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'PUB_P2E08_REFERENCE_VALID_CALIBRATION_DOMAIN_GATE=PASS'
