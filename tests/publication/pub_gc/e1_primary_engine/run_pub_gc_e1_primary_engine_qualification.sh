#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT"

BASE="14ee1be3c221c973973a3fb3dcb450ff40d3f96a"
SOURCE_TREE="d7ef6c045263de821db7800459289efcd8a6420b"
PRIMARY_MANIFEST_COMMIT="c3114e455029ee5dee0d92dbc4814c3fc0923ef6"
PRIMARY_MANIFEST_PATH="docs/publications/manifests/PUB-GC-E1-PRIMARY-0001.yaml"
PRIMARY_MANIFEST_BLOB="abf45b4a83f528eda69024e3d75a38edc4ce713f"
QUAL_MANIFEST_COMMIT="bf62fc34ed603bf2fd551e8ea352310a1e823066"
QUAL_MANIFEST_PATH="docs/publications/manifests/PUB-GC-E1-PRIMARY-ENGINE-QUAL-0001.yaml"
QUAL_MANIFEST_BLOB="ea5042e51c61fbd6b11be87ded6198b8bdc44e81"
ORIGIN_DIR="tests/publication/pub_gc/e1_origin"
GW_A_DIR="tests/publication/pub_gc/gw_a"
ENGINE_DIR="tests/publication/pub_gc/e1_primary_engine"
TEST="$ENGINE_DIR/test_pub_gc_e1_primary_engine.f90"
RUNNER="$ENGINE_DIR/run_pub_gc_e1_primary_engine_qualification.sh"
WORKFLOW=".github/workflows/pub-gc-e1-primary-engine-qualification.yml"

fail(){ echo "PUB_GC_E1_PRIMARY_ENGINE_QUAL_FAIL $*" >&2; exit 51; }

git cat-file -e "$BASE^{commit}" 2>/dev/null || fail "missing qualified E1 harness authority"
git merge-base --is-ancestor "$BASE" HEAD || fail "engine head does not descend from qualified E1 harness"
[[ "$(git rev-parse HEAD:src)" == "$SOURCE_TREE" ]] || fail "production source tree drift"
[[ "$(git rev-parse HEAD:$ORIGIN_DIR)" == "$(git rev-parse "$BASE:$ORIGIN_DIR")" ]] || fail "qualified origin harness changed"
[[ "$(git rev-parse HEAD:$GW_A_DIR)" == "$(git rev-parse "$BASE:$GW_A_DIR")" ]] || fail "qualified GW-A changed"

mapfile -t changed < <(git diff --name-only "$BASE..HEAD")
for path in "${changed[@]}"; do
  case "$path" in
    tests/publication/pub_gc/e1_primary_engine/*|.github/workflows/pub-gc-e1-primary-engine-qualification.yml) ;;
    *) fail "out-of-scope engine mutation: $path" ;;
  esac
done

git fetch --quiet --no-tags origin refs/heads/work/pub-gc-scientific-contract:refs/remotes/origin/work/pub-gc-scientific-contract
for commit in "$PRIMARY_MANIFEST_COMMIT" "$QUAL_MANIFEST_COMMIT"; do
  git cat-file -e "$commit^{commit}" 2>/dev/null || fail "manifest authority unavailable: $commit"
done
[[ "$(git rev-parse "$PRIMARY_MANIFEST_COMMIT:$PRIMARY_MANIFEST_PATH")" == "$PRIMARY_MANIFEST_BLOB" ]] || fail "primary manifest blob drift"
[[ "$(git rev-parse "$QUAL_MANIFEST_COMMIT:$QUAL_MANIFEST_PATH")" == "$QUAL_MANIFEST_BLOB" ]] || fail "qualification manifest blob drift"

echo "PUB_GC_E1_ENGINE_PRIMARY_MANIFEST_LOCK=PASS:$PRIMARY_MANIFEST_COMMIT:$PRIMARY_MANIFEST_BLOB"
echo "PUB_GC_E1_ENGINE_QUAL_MANIFEST_LOCK=PASS:$QUAL_MANIFEST_COMMIT:$QUAL_MANIFEST_BLOB"
echo 'PUB_GC_E1_ENGINE_PRODUCTION_SRC_UNCHANGED=PASS'
echo 'PUB_GC_E1_ENGINE_ORIGIN_HARNESS_BYTES_UNCHANGED=PASS'
echo 'PUB_GC_E1_ENGINE_GW_A_BYTES_UNCHANGED=PASS'

for forbidden in '-80.0' '-102.5' '-98.75'; do
  if grep -Fq -- "$forbidden" "$TEST"; then
    fail "primary literal leaked into generic engine source: $forbidden"
  fi
done
if grep -Eq 'fmr_commit_candidate|groundwater_commit_candidate|groundwater_commit_prepared|kernel_reconstruct_committed_state_trusted' "$TEST"; then
  fail "forbidden production publication/reconstruction route in engine"
fi
grep -Fq 'call carriers(j-1)%initialize' "$TEST" || fail "history policy does not use public initialize"
grep -Fq 'groundwater_discard_candidate' "$TEST" || fail "GW-A discard route missing"
grep -Fq 'gw_checkpoint' "$TEST" || fail "shared GW-A checkpoint route missing"
echo 'PUB_GC_E1_ENGINE_STATIC_POLICY=PASS'

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-gc-e1-primary-engine-${GITHUB_RUN_ID:-local}-$$"
BASE_WORKTREE="$BUILD/e1-base"
mkdir -p "$BUILD"
cleanup(){
  git -C "$ROOT" worktree remove --force "$BASE_WORKTREE" >/dev/null 2>&1 || true
  rm -rf "$BUILD"
}
trap cleanup EXIT

git worktree add --detach "$BASE_WORKTREE" "$BASE" >/dev/null
(
  cd "$BASE_WORKTREE"
  bash tests/publication/pub_gc/e1_origin/run_pub_gc_e1_origin_harness_qualification.sh
) > "$BUILD/base-qualification.txt" 2>&1 || {
  cat "$BUILD/base-qualification.txt" >&2
  fail "frozen E1 origin harness requalification failed"
}
grep -Fq 'PUB_GC_E1_ORIGIN_HARNESS_QUALIFICATION=PASS' "$BUILD/base-qualification.txt" || fail "base E1 harness PASS marker missing"
echo 'PUB_GC_E1_ENGINE_BASE_REQUALIFICATION=PASS'

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
)

run_fixture(){
  local exe="$1" fixture="$2" a="$3" b="$4" c="$5" dt="$6" outfile="$7"
  echo "PUB_GC_E1_ENGINE_FIXTURE_BEGIN=$fixture A=$a B=$b C=$c DT=$dt"
  timeout 180s "$exe" "$a" "$b" "$c" "$dt" > "$outfile" 2>&1 || {
    cat "$outfile" >&2
    fail "fixture $fixture executable failed"
  }
  for marker in     'PUB_GC_E1_ENGINE_SAME_ORIGIN_IDENTITY=PASS'     'PUB_GC_E1_ENGINE_ACCEPTED_ORIGIN_UNCHANGED=PASS'     'PUB_GC_E1_ENGINE_GW_A_SAME_CHECKPOINT_NO_COMMIT=PASS'     'PUB_GC_E1_ENGINE_HISTORY_DIAG_PRODUCTION_VALID=false'     'PUB_GC_E1_PRIMARY_ENGINE_ORACLE=PASS'; do
    grep -Fq "$marker" "$outfile" || { cat "$outfile" >&2; fail "fixture $fixture missing marker: $marker"; }
  done
  [[ "$(grep -c '^PUB_GC_E1_ENGINE_ROW|' "$outfile")" -eq 16 ]] || fail "fixture $fixture SWAP row count"
  [[ "$(grep -c '^PUB_GC_E1_ENGINE_GW_ROW|' "$outfile")" -eq 16 ]] || fail "fixture $fixture GW row count"
  [[ "$(grep -c '^PUB_GC_E1_ENGINE_ROW|S[12]|HISTORY_DIAG|' "$outfile")" -eq 8 ]] || fail "fixture $fixture history row count"
  [[ "$(grep -c '^PUB_GC_E1_ENGINE_ROW|S[12]|SAME|' "$outfile")" -eq 8 ]] || fail "fixture $fixture same row count"
  echo "PUB_GC_E1_ENGINE_FIXTURE_END=$fixture"
}

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
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/engine.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/engine.o" -o "$OUT/engine"
  echo "PUB_GC_E1_ENGINE_BUILD_O${opt}=PASS"

  run_fixture "$OUT/engine" Q1 -75.0 -90.0 -60.0 0.005 "$OUT/Q1.txt"
  run_fixture "$OUT/engine" Q2 -75.0 -85.0 -65.0 0.01 "$OUT/Q2.txt"
done

for fixture in Q1 Q2; do
  cmp "$BUILD/o0/$fixture.txt" "$BUILD/o2/$fixture.txt" || {
    diff -u "$BUILD/o0/$fixture.txt" "$BUILD/o2/$fixture.txt" >&2 || true
    fail "O0/O2 scientific output drift for $fixture"
  }
  echo "PUB_GC_E1_ENGINE_${fixture}_O0_O2_IDENTITY=PASS"
  echo "PUB_GC_E1_ENGINE_${fixture}_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/$fixture.txt" | awk '{print $1}')"
done

cat "$BUILD/o0/Q1.txt"
cat "$BUILD/o0/Q2.txt"
echo "PUB_GC_E1_ENGINE_HEAD=$(git rev-parse HEAD)"
echo "PUB_GC_E1_ENGINE_SOURCE_TREE=$(git rev-parse HEAD:src)"
echo "PUB_GC_E1_ENGINE_TEST_BLOB=$(git rev-parse HEAD:$TEST)"
echo "PUB_GC_E1_ENGINE_RUNNER_BLOB=$(git rev-parse HEAD:$RUNNER)"
echo 'PUB_GC_E1_PRIMARY_ENGINE_QUALIFICATION=PASS'
