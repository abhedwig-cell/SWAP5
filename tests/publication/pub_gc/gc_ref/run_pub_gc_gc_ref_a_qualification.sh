#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT"

BASE="188c863f560d8adacf255edb4f6f83edcac798f3"
SOURCE_TREE="d7ef6c045263de821db7800459289efcd8a6420b"
SPEC_COMMIT="c95d67c70dc16126797c6613affe641537e3655e"
SPEC_PATH="docs/publications/PUB-GC_GC-REF_SPECIFICATION.md"
SPEC_BLOB="73ac1fc61d71feaa2826fe3e03c8e69b8e9879f6"
MANIFEST_COMMIT="abb9d7b5a397abef1987ed8b6872064a13788c9b"
MANIFEST_PATH="docs/publications/manifests/PUB-GC-GC-REF-A-QUAL-0001.yaml"
MANIFEST_BLOB="f4e1143d03b6c197ed2f4a95c2da449c88b1f79d"

GW_A_DIR="tests/publication/pub_gc/gw_a"
E1_ORIGIN_DIR="tests/publication/pub_gc/e1_origin"
E1_ENGINE_DIR="tests/publication/pub_gc/e1_primary_engine"
E2_DIR="tests/publication/pub_gc/e2_terminal_comparator"
DIR="tests/publication/pub_gc/gc_ref"
MODULE="$DIR/mod_pub_gc_gc_ref.f90"
TEST="$DIR/test_pub_gc_gc_ref_a.f90"
RUNNER="$DIR/run_pub_gc_gc_ref_a_qualification.sh"
WORKFLOW=".github/workflows/pub-gc-gc-ref-a-qualification.yml"

fail(){ echo "PUB_GC_GC_REF_A_QUAL_FAIL $*" >&2; exit 81; }

git cat-file -e "$BASE^{commit}" 2>/dev/null || fail "base unavailable"
git merge-base --is-ancestor "$BASE" HEAD || fail "branch does not descend from frozen E2-qualified base"
[[ "$(git rev-parse HEAD:src)" == "$SOURCE_TREE" ]] || fail "production source tree drift"

for dep in "$GW_A_DIR" "$E1_ORIGIN_DIR" "$E1_ENGINE_DIR" "$E2_DIR"; do
  [[ "$(git rev-parse HEAD:$dep)" == "$(git rev-parse "$BASE:$dep")" ]] || fail "qualified dependency changed: $dep"
done

mapfile -t changed < <(git diff --name-only "$BASE..HEAD")
for changed_path in "${changed[@]}"; do
  case "$changed_path" in
    "$DIR"/*|"$WORKFLOW") ;;
    *) fail "out-of-scope GC-REF mutation: $changed_path" ;;
  esac
done

git fetch --quiet --no-tags origin refs/heads/work/pub-gc-scientific-contract:refs/remotes/origin/work/pub-gc-scientific-contract
for commit in "$SPEC_COMMIT" "$MANIFEST_COMMIT"; do
  git cat-file -e "$commit^{commit}" 2>/dev/null || fail "documentation authority unavailable: $commit"
done
[[ "$(git rev-parse "$SPEC_COMMIT:$SPEC_PATH")" == "$SPEC_BLOB" ]] || fail "GC-REF specification blob drift"
[[ "$(git rev-parse "$MANIFEST_COMMIT:$MANIFEST_PATH")" == "$MANIFEST_BLOB" ]] || fail "GC-REF qualification manifest blob drift"

if grep -Eiq 'newton|broyden|aitken|secant|tangent|dQ.?/.?dh|dh.?/.?dq' "$MODULE" "$TEST"; then
  fail "response/derivative acceleration leaked into GC-REF oracle"
fi
if grep -Eiq 'fmr_commit_candidate|groundwater_commit_candidate|groundwater_commit_prepared|kernel_reconstruct_committed_state_trusted' "$MODULE" "$TEST"; then
  fail "production publication/reconstruction route leaked into qualification oracle"
fi
grep -Fq 'gc_ref_bisect' "$MODULE" || fail "bisection oracle missing"
grep -Fq 'bottom_outward_exchange_native' "$TEST" || fail "whole-window exchange missing"
grep -Fq 'groundwater_trial_from_checkpoint' "$TEST" || fail "GW-A same-origin trial missing"
grep -Fq 'fmr_discard_candidate' "$TEST" || fail "SWAP candidate discard missing"

echo "PUB_GC_GC_REF_SPEC_LOCK=PASS:$SPEC_COMMIT:$SPEC_BLOB"
echo "PUB_GC_GC_REF_MANIFEST_LOCK=PASS:$MANIFEST_COMMIT:$MANIFEST_BLOB"
echo "PUB_GC_GC_REF_PRODUCTION_SRC_UNCHANGED=PASS:$SOURCE_TREE"
echo "PUB_GC_GC_REF_DEPENDENCY_BYTES_UNCHANGED=PASS"
echo "PUB_GC_GC_REF_DERIVATIVE_ACCELERATION_ABSENT=PASS"
echo "PUB_GC_GC_REF_PRODUCTION_COMMIT_ABSENT=PASS"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-gc-gc-ref-a-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

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
  src/adapter/mod_reference_richards_accepted_step_directional_service.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/runtime/mod_fmr_soil_water_application_host.f90
  src/runtime/mod_rossfast_d3r_execution_policy.f90
  src/runtime/mod_rossfast_d3r_model_binding.f90
  src/solver/mod_rossfast_d3r_table_kernel.f90
  src/solver/mod_rossfast_d3r_table_provider.f90
  src/solver/mod_rossfast_d3r_soil_water_solver.f90
  src/runtime/mod_fmr_rossfast_solver_selection_binding.f90
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/runtime/mod_fmr_top_sensible_boundary_carrier.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_owned_commit_receipt.f90
  src/runtime/mod_fmr_bottom_external_thermal_binding.f90
  src/runtime/mod_fmr_bottom_external_thermal_provider.f90
  src/process/mod_liquid_water_sensible_enthalpy.f90
  src/runtime/mod_fmr_bottom_sensible_energy.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_groundwater_exchange_service_contract.f90
  tests/publication/pub_gc/gw_a/mod_pub_gc_gw_a.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
  "$MODULE"
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    [[ -f "$source" ]] || fail "missing compile source $source"
    obj="$OUT/$(echo "$source" | tr '/.' '__').o"
    extra=()
    [[ "$source" == "src/solver/mod_soil_water_solver_contract.f90" ]] && extra=(-Wno-error=unused-dummy-argument)
    gfortran "${COMMON[@]}" "${extra[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/test.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  timeout 240s "$OUT/test" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "O$opt GC-REF-A oracle"
  }

  for marker in     'PUB_GC_GC_REF_SYNTHETIC_KNOWN_ROOT=PASS'     'PUB_GC_GC_REF_INVALID_BRACKET=PASS'     'PUB_GC_GC_REF_STABLE_REFINEMENT=PASS'     'PUB_GC_GC_REF_UNSTABLE_REFINEMENT_REJECTED=PASS'     'PUB_GC_GC_REF_SAME_ORIGIN_REPEATABILITY=PASS'     'PUB_GC_GC_REF_REAL_BRACKET_ROOT=PASS'     'PUB_GC_GC_REF_FINAL_RECONSTRUCTION=PASS'     'PUB_GC_GC_REF_ACTION_REACTION=PASS'     'PUB_GC_GC_REF_ACCEPTED_ORIGINS_UNCHANGED=PASS'     'PUB_GC_GC_REF_NO_H2_H3_PRIMARY_INFERENCE=true'     'PUB_GC_GC_REF_A_QUALIFICATION_ORACLE=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "O$opt missing marker $marker"; }
  done
  echo "PUB_GC_GC_REF_A_O$opt=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail "O0/O2 scientific output drift"
}

cat "$BUILD/o0/output.txt"
echo "PUB_GC_GC_REF_A_O0_O2_IDENTITY=PASS"
echo "PUB_GC_GC_REF_A_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo "PUB_GC_GC_REF_A_HEAD=$(git rev-parse HEAD)"
echo "PUB_GC_GC_REF_A_MODULE_BLOB=$(git rev-parse HEAD:$MODULE)"
echo "PUB_GC_GC_REF_A_TEST_BLOB=$(git rev-parse HEAD:$TEST)"
echo "PUB_GC_GC_REF_A_RUNNER_BLOB=$(git rev-parse HEAD:$RUNNER)"
echo "PUB_GC_GC_REF_A_QUALIFICATION=PASS"
