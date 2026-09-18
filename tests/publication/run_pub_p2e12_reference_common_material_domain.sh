#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-p2e12-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "PUB_P2E12_GATE_FAIL $*" >&2; exit 1; }

TEST=tests/publication/test_pub_p2e12_reference_common_material_domain.f90
PREREG=docs/publication/P2E12_REFERENCE_COMMON_MATERIAL_DOMAIN_PREREGISTRATION.json
CANONICAL_BASE=f2d472cb0e4d935ef39f002d6f21c8d90acf4dd8
REFERENCE_TREE=684f1e2889b6992e5aedc88f52bb45f4558bb3e4
SOLVER_CONTRACT_BLOB=40a1ddc05fb8e2c1822763de645fd07a094568a3
MODEL_BINDING_BLOB=5442fd7e7a2f392c9b796cd17c76b17977259f22
REFERENCE_BINDING_BLOB=4b545c6fb260e81cd6c8f4d2d65f2beee7281e53
WORKSPACE_BLOB=74f99556005ae39614f9df678467b1e19097bae2
HEADCALC_BLOB=3ff8d5cfd6963dfb7dafb33ec454fbc0df938a55
FREEZE_BLOB=601cfc1b2f41c335f8a74be57fa373b057c49b75
PREREG_BLOB=97210b5e1c1dab7d53f32ed0716eb8eced311baa
TEST_BLOB=d8c88d8b45e30ae0ebf7283a1584ebd80832eed4
FROSS13_RESULT_BLOB=4be26de45d9fe75825bb482580ce6a9b098dedf0
P2E09_RESULT_BLOB=1a82511cb13a4c39235292de83dc626478bfb6a6
P2E10_RESULT_BLOB=83864f6379279725fa97d24d57936f590d3c2174

[[ -f "$PREREG" ]] || fail 'missing domain-map preregistration'
grep -Fq '"phase": "PREREGISTERED_SUPPORTING_DOMAIN_CONSTRUCTION_AFTER_P2E11_NEGATIVE_RESULT"' "$PREREG" || fail 'domain-map preregistration phase missing'
grep -Fq '"rossfast_numerical_solver_execution_allowed": false' "$PREREG" || fail 'RossFast execution firewall missing'
grep -Fq '"threshold_freezing_allowed": false' "$PREREG" || fail 'threshold-freeze firewall missing'
grep -Fq '"timestep_search_allowed": false' "$PREREG" || fail 'fixed-timestep firewall missing'
grep -Fq '"post_run_scan_level_insertion_allowed": false' "$PREREG" || fail 'scan-grid freeze missing'

git merge-base --is-ancestor "$CANONICAL_BASE" HEAD || fail 'canonical base is not an ancestor'
git diff --quiet "$CANONICAL_BASE" HEAD -- src reference || fail 'P2E12 mutated src or reference'
test "$(git rev-parse HEAD:reference)" = "$REFERENCE_TREE" || fail 'reference tree drift'
test "$(git rev-parse HEAD:src/solver/mod_soil_water_solver_contract.f90)" = "$SOLVER_CONTRACT_BLOB" || fail 'solver contract drift'
test "$(git rev-parse HEAD:src/runtime/mod_rossfast_d3r_model_binding.f90)" = "$MODEL_BINDING_BLOB" || fail 'material-domain binding drift'
test "$(git rev-parse HEAD:src/adapter/mod_reference_richards_legacy_binding.f90)" = "$REFERENCE_BINDING_BLOB" || fail 'Reference binding drift'
test "$(git rev-parse HEAD:src/solver/mod_reference_richards_workspace.f90)" = "$WORKSPACE_BLOB" || fail 'Reference workspace drift'
test "$(git rev-parse HEAD:src/legacy/b1_10_port/headcalc.f90)" = "$HEADCALC_BLOB" || fail 'HeadCalc drift'
test "$(git rev-parse HEAD:$PREREG)" = "$PREREG_BLOB" || fail 'domain-map preregistration drift'
test "$(git rev-parse HEAD:$TEST)" = "$TEST_BLOB" || fail 'domain-map oracle drift'
test "$(git rev-parse HEAD:docs/publication/P2E11_REFERENCE_MATERIAL_EXTENSION_CALIBRATION_RESULT.json)" = "0d186a17c5b48f8287fde0d01c8a668aab064c1d" || fail 'P2E11 parent result drift'
test "$(git rev-parse HEAD:docs/publication/P2E11D1_REFERENCE_EXTENSION_FAILURE_ADJUDICATION_RESULT.json)" = "1be7d63e82eac9d1f846c9715fabf80a5700bdf8" || fail 'P2E11D1 diagnosis drift'
test "$(git rev-parse HEAD:integration/f-ross/F-ROSS13_TRANSIENT_36_MATERIAL_QUALIFICATION_RESULT.json)" = "$FROSS13_RESULT_BLOB" || fail 'F-ROSS13 authority drift'

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
    fail "Reference common-material domain map O$opt"
  fi

  for marker in     'PUB_P2E12_PHYSICAL_CASE_COUNT=300'     'PUB_P2E12_TEMPORAL_LEVEL_COUNT=1'     'PUB_P2E12_TRIAL_PAIR_COUNT=300'     'PUB_P2E12_ROSSFAST_SOLVER_EXECUTED=FALSE'     'PUB_P2E12_THRESHOLD_FROZEN=FALSE'     'PUB_P2E12_REFERENCE_TOLERANCE_CHANGED=FALSE'     'PUB_P2E12_P2E03_REPAIRED_OR_RECLASSIFIED=FALSE'     'PUB_P2E12_REFERENCE_COMMON_MATERIAL_DOMAIN_GATE=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing O$opt marker $marker"; }
  done

  feasibility_lines="$(grep -Fc 'PUB_P2E12_DT_FEASIBILITY|' "$OUT/output.txt")"
  [[ "$feasibility_lines" = "1" ]] || { cat "$OUT/output.txt" >&2; fail "expected one frozen temporal feasibility summary"; }

  se_lines="$(grep -Fc 'PUB_P2E12_SE_FEASIBILITY|' "$OUT/output.txt")"
  [[ "$se_lines" = "5" ]] || { cat "$OUT/output.txt" >&2; fail "expected five preregistered Se feasibility rows"; }
  trial_lines="$(grep -Fc 'PUB_P2E12_TRIAL|' "$OUT/output.txt")"
  [[ "$trial_lines" = "300" ]] || { cat "$OUT/output.txt" >&2; fail "expected all 300 preregistered domain-map cases"; }
  grep -Fq 'PUB_P2E12_DOMAIN_MAP_STATUS=COMPLETE' "$OUT/output.txt" || fail 'domain map not complete'
  grep -Fq 'PUB_P2E12_REFERENCE_COMMON_MATERIAL_DOMAIN_GATE=PASS' "$OUT/output.txt" || fail 'domain-map gate missing'

  cat "$OUT/output.txt" >&2
    fail "missing qualified or blocked scientific outcome"
  fi

  cat "$OUT/output.txt"
  echo "PUB_P2E12_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 Reference common-material domain output drift'
}

echo "PUB_P2E12_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'PUB_P2E12_REFERENCE_COMMON_MATERIAL_DOMAIN_GATE=PASS'
