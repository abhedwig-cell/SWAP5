#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-me-d5-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail(){ echo "PUB_ME_D5_GATE_FAIL $*" >&2; exit 1; }

EXECUTION_BASE=1604b89e6bebf6436dcd2718b8e150bf909d8a01
DESIGN_HEAD=b2ebe5825b3c54d9d4eaefe44c33f4c859fa20aa
DESIGN_BLOB=61f7133f19cc900971aa454b7bdb16a254468eda
DESIGN_PATH=docs/publications/PUB-ME_D1_D6_PREREGISTERED_EXPERIMENT_MATRIX.md
CHECKPOINT=docs/publications/PUB-ME_D5_EXECUTION_CHECKPOINT.md
TEST=tests/publication/test_pub_me_d5_workspace_authority.f90
RUNNER=tests/publication/run_pub_me_d5_workspace_authority.sh

for path in "$CHECKPOINT" "$TEST" "$RUNNER"; do
  [[ -f "$path" ]] || fail "missing D5 workunit file $path"
done

git diff --check "$EXECUTION_BASE"...HEAD -- "$CHECKPOINT" "$TEST" "$RUNNER" || fail 'D5 diff check'
[[ -z "$(git diff --name-only "$EXECUTION_BASE"...HEAD -- src reference)" ]] || fail 'D5 changed production/reference source'

git fetch --quiet --no-tags origin "$DESIGN_HEAD" || fail 'cannot fetch preregistered design authority'
actual_design_blob="$(git rev-parse "$DESIGN_HEAD:$DESIGN_PATH" 2>/dev/null || true)"
[[ "$actual_design_blob" == "$DESIGN_BLOB" ]] || fail "preregistered D1-D6 design blob drift: $actual_design_blob"

echo "PUB_ME_D5_PREREGISTRATION_HEAD=$DESIGN_HEAD"
echo "PUB_ME_D5_PREREGISTRATION_BLOB=$actual_design_blob"
echo 'PUB_ME_D5_PREREGISTRATION_BINDING=PASS'

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
    [[ "$source" != "$forbidden" ]] || fail "RossFast numerical implementation entered D5 build: $forbidden"
  done
done

run_one(){
  local opt="$1" tag="$2" out="$BUILD/$tag"
  local objects=()
  for source in "${MODULE_SRC[@]}"; do
    [[ -f "$source" ]] || fail "missing compile source $source"
    obj="$out/$(basename "${source%.*}").o"
    extra=()
    [[ "$source" == "src/solver/mod_soil_water_solver_contract.f90" ]] && extra=(-Wno-error=unused-dummy-argument)
    gfortran "${COMMON[@]}" "${extra[@]}" -O"$opt" -J "$out" -I "$out" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c "$TEST" -o "$out/test.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$out/test.o" -o "$out/test"

  if ! "$out/test" > "$out/output.txt" 2>&1; then
    cat "$out/output.txt" >&2
    fail "D5 execution $tag"
  fi

  grep -Fq 'PUB_ME_D5_REFERENCE_WORKSPACE_AUTHORITY_EXPERIMENT=PASS' "$out/output.txt" || {
    cat "$out/output.txt" >&2
    fail "missing D5 PASS marker $tag"
  }
  grep -Fq 'PUB_ME_D5_B2_PRE_RETRY_AUTHORITY_DETECTED=T' "$out/output.txt" || {
    cat "$out/output.txt" >&2
    fail "missing D5 B2 detection $tag"
  }
  grep -Eq '^PUB_ME_D5_CLASSIFICATION=(STRUCTURAL_PREVENTION|NO_INCREMENTAL_VALUE|EARLIER_DETECTION|UNIQUE_DETECTION|D5_AUTHORITY_FAILURE)$' "$out/output.txt" || {
    cat "$out/output.txt" >&2
    fail "missing/invalid D5 classification $tag"
  }

  cat "$out/output.txt"
  echo "PUB_ME_D5_${tag^^}=PASS"
}

run_one 0 o0
run_one 2 o2

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'D5 O0/O2 semantic drift'
}

echo "PUB_ME_D5_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'PUB_ME_D5_GATE=PASS'
