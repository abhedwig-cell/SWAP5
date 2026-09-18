#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT"

BASE="2189109de15df92d6712b5a3f5b27c1a922edd42"
SOURCE_TREE="d7ef6c045263de821db7800459289efcd8a6420b"
DECISION_COMMIT="f581b112add1ae2c7bf6dcce37557eaa22cf21a7"
DECISION_PATH="docs/publications/decisions/PUB-GC_NATIVE_TIME_REFINEMENT_AFTER_0003.md"
DECISION_BLOB="fb86dc34d092f04942253ed0a6bc2732ba30159a"
SPEC_COMMIT="0879d0038efb0931774744bb26f2be6eea0e29d4"
SPEC_PATH="docs/publications/PUB-GC_MACRO_512_EXTENSION_SPEC.md"
SPEC_BLOB="29ed1643be0d24fab234938e65316d714d052a27"
MANIFEST_COMMIT="ec809e3da580b23a48da2ee7fac624781fd0a62e"
MANIFEST_PATH="docs/publications/manifests/PUB-GC-MACRO-WINDOW-QUAL-0004.yaml"
MANIFEST_BLOB="5900cebf510c33382d15f67da1d0d538483ef8f4"

DIR="tests/publication/pub_gc/macro_window_response"
MODULE="$DIR/mod_pub_gc_macro_window_response.f90"
TEST="$DIR/test_pub_gc_macro_window_response.f90"
RUNNER="$DIR/run_pub_gc_macro_512_qualification.sh"
WORKFLOW=".github/workflows/pub-gc-macro-512-qualification.yml"

fail(){ echo "PUB_GC_MACRO_512_RUN_FAIL $*" >&2; exit 97; }

git cat-file -e "$BASE^{commit}" 2>/dev/null || fail "base unavailable"
git merge-base --is-ancestor "$BASE" HEAD || fail "branch not descended from qualified macro head"
[[ "$(git rev-parse HEAD:src)" == "$SOURCE_TREE" ]] || fail "production source tree drift"
[[ "$(git rev-parse HEAD:$MODULE)" == "0a9461368f536381ca23390b255f8c369cb1e474" ]] || fail "qualified macro module drift"

for dep in \
  tests/publication/pub_gc/gw_a \
  tests/publication/pub_gc/e1_origin \
  tests/publication/pub_gc/e1_primary_engine \
  tests/publication/pub_gc/e2_terminal_comparator \
  tests/publication/pub_gc/gc_ref \
  tests/publication/pub_gc/reference_screening; do
  [[ "$(git rev-parse HEAD:$dep)" == "$(git rev-parse "$BASE:$dep")" ]] || fail "qualified dependency changed: $dep"
done

mapfile -t changed < <(git diff --name-only "$BASE..HEAD")
for changed_path in "${changed[@]}"; do
  case "$changed_path" in
    "$DIR"/*|"$WORKFLOW") ;;
    *) fail "out-of-scope time-coordinate mutation: $changed_path" ;;
  esac
done

git fetch --quiet --no-tags origin refs/heads/work/pub-gc-scientific-contract:refs/remotes/origin/work/pub-gc-scientific-contract
for lock in \
  "$DECISION_COMMIT:$DECISION_PATH:$DECISION_BLOB" \
  "$SPEC_COMMIT:$SPEC_PATH:$SPEC_BLOB" \
  "$MANIFEST_COMMIT:$MANIFEST_PATH:$MANIFEST_BLOB"; do
  IFS=: read -r commit path blob <<< "$lock"
  git cat-file -e "$commit^{commit}" 2>/dev/null || fail "authority commit unavailable: $commit"
  [[ "$(git rev-parse "$commit:$path")" == "$blob" ]] || fail "authority blob drift: $path"
done

grep -Fq "actual_native_dt_day" "$MODULE" || fail "actual duration telemetry missing"
grep -Fq "t1 = macro_t1" "$MODULE" || fail "exact final macro boundary missing"
grep -Fq "same_real_bits(disposable_time,macro_t1)" "$MODULE" || fail "exact final disposable-time guard missing"
grep -Fq "Q2 frozen discrimination floor" "$TEST" || fail "legacy Q2 criterion missing"
grep -Fq "Q3 A Q repeatability" "$TEST" || fail "legacy Q3 criterion missing"
grep -Fq "Q5 temporal history available" "$TEST" || fail "legacy Q5 criterion missing"
grep -Fq "Q8A 16 contribution complete" "$TEST" || fail "Q8A missing"
grep -Fq "Q8B 32 contribution complete" "$TEST" || fail "Q8B missing"
grep -Fq "Q8C shifted 32 contribution complete" "$TEST" || fail "Q8C missing"
grep -Fq "Q9A 64 contribution complete" "$TEST" || fail "Q9A missing"
grep -Fq "Q9B 128 contribution complete" "$TEST" || fail "Q9B missing"
grep -Fq "Q9C shifted 128 contribution complete" "$TEST" || fail "Q9C missing"
grep -Fq "Q10A 256 contribution complete" "$TEST" || fail "Q10A missing"
grep -Fq "Q10B 512 contribution complete" "$TEST" || fail "Q10B missing"
grep -Fq "Q10C shifted 512 contribution complete" "$TEST" || fail "Q10C missing"

echo "PUB_GC_MACRO_512_DECISION_LOCK=PASS:$DECISION_COMMIT:$DECISION_BLOB"
echo "PUB_GC_MACRO_512_SPEC_LOCK=PASS:$SPEC_COMMIT:$SPEC_BLOB"
echo "PUB_GC_MACRO_512_MANIFEST_LOCK=PASS:$MANIFEST_COMMIT:$MANIFEST_BLOB"
echo "PUB_GC_MACRO_512_PRODUCTION_SRC_UNCHANGED=PASS:$SOURCE_TREE"
echo "PUB_GC_MACRO_512_QUALIFIED_DEPENDENCIES_UNCHANGED=PASS"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-gc-macro-time-${GITHUB_RUN_ID:-local}-$$"
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
  src/runtime/mod_fmr_accepted_commit_receipt.f90
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
  src/runtime/mod_fmr_owned_commit_receipt.f90
  src/runtime/mod_fmr_bottom_external_thermal_binding.f90
  src/runtime/mod_fmr_bottom_external_thermal_provider.f90
  src/process/mod_liquid_water_sensible_enthalpy.f90
  src/runtime/mod_fmr_bottom_sensible_energy.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
  "$MODULE"
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
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
  timeout 900s "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "O$opt executable failed"; }

  for marker in \
    PUB_GC_MACRO_QUAL_Q0=PASS \
    PUB_GC_MACRO_QUAL_Q1=PASS \
    PUB_GC_MACRO_QUAL_Q2=PASS \
    PUB_GC_MACRO_QUAL_Q3=PASS \
    PUB_GC_MACRO_QUAL_Q5=PASS \
    PUB_GC_MACRO_QUAL_Q8=PASS \
    PUB_GC_MACRO_QUAL_Q9=PASS \
    PUB_GC_MACRO_QUAL_FAILURE_CONTROLS=PASS \
    PUB_GC_MACRO_PRIMARY_H2_H3_ELIGIBLE=false \
    PUB_GC_MACRO_QUALIFICATION=PASS; do
    grep -Fq "$marker" "$OUT/output.txt" || fail "O$opt missing marker $marker"
  done
  echo "PUB_GC_MACRO_512_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail "O0/O2 scientific output drift"
}
cat "$BUILD/o0/output.txt"
echo "PUB_GC_MACRO_512_O0_O2_IDENTITY=PASS"
echo "PUB_GC_MACRO_512_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo "PUB_GC_MACRO_512_HEAD=$(git rev-parse HEAD)"
echo "PUB_GC_MACRO_512_SOURCE_TREE=$(git rev-parse HEAD:src)"
echo "PUB_GC_MACRO_512_MODULE_BLOB=$(git rev-parse HEAD:$MODULE)"
echo "PUB_GC_MACRO_512_TEST_BLOB=$(git rev-parse HEAD:$TEST)"
echo "PUB_GC_MACRO_512_RUNNER_BLOB=$(git rev-parse HEAD:$RUNNER)"
echo "PUB_GC_MACRO_512_QUALIFICATION=PASS"
