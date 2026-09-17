#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT"

QUALIFIED_POST_HEAD="d2e810649c5deae20bb22f42c92918eb1795d786"
QUALIFIED_ENGINE_EXECUTION_HEAD="98858378c2fcf48acbf1c2b34094056b7fc76c18"
SOURCE_TREE="d7ef6c045263de821db7800459289efcd8a6420b"
BASE_HARNESS="14ee1be3c221c973973a3fb3dcb450ff40d3f96a"
ENGINE="tests/publication/pub_gc/e1_primary_engine/test_pub_gc_e1_primary_engine.f90"
ENGINE_BLOB="7214117cc64591bd4ced071561a19e37aab0de1b"
QUAL_RUNNER="tests/publication/pub_gc/e1_primary_engine/run_pub_gc_e1_primary_engine_qualification.sh"
QUAL_RUNNER_BLOB="1c8914b3b996ed455de91e9c8ffc5f2adf20bac8"
PRIMARY_MANIFEST_COMMIT="c3114e455029ee5dee0d92dbc4814c3fc0923ef6"
PRIMARY_MANIFEST_PATH="docs/publications/manifests/PUB-GC-E1-PRIMARY-0001.yaml"
PRIMARY_MANIFEST_BLOB="abf45b4a83f528eda69024e3d75a38edc4ce713f"
A="-80.0"
B="-102.5"
C="-98.75"
DT="0.03"
SENTINEL="tests/publication/pub_gc/e1_primary_run/EXECUTE_ONCE"
RUNNER="tests/publication/pub_gc/e1_primary_run/run_pub_gc_e1_primary_once.sh"
WORKFLOW=".github/workflows/pub-gc-e1-primary-run.yml"
ORIGIN_DIR="tests/publication/pub_gc/e1_origin"
GW_A_DIR="tests/publication/pub_gc/gw_a"

fail(){ echo "PUB_GC_E1_PRIMARY_EXECUTION_FAIL $*" >&2; exit 61; }

[[ -f "$SENTINEL" ]] || fail "one-time sentinel missing"
declare -A S=()
while IFS="=" read -r k v; do
  [[ -n "$k" ]] || continue
  S["$k"]="$v"
done < "$SENTINEL"

[[ "${S[experiment_id]:-}" == "PUB-GC-E1-PRIMARY-0001" ]] || fail "sentinel experiment id"
[[ -n "${S[execution_authority_commit]:-}" ]] || fail "sentinel authority commit missing"
[[ -n "${S[pretrigger_head]:-}" ]] || fail "sentinel pretrigger head missing"
[[ "${S[primary_manifest_commit]:-}" == "$PRIMARY_MANIFEST_COMMIT" ]] || fail "sentinel primary manifest mismatch"
[[ "${S[engine_blob]:-}" == "$ENGINE_BLOB" ]] || fail "sentinel engine blob mismatch"

[[ "$(git rev-parse HEAD^)" == "${S[pretrigger_head]}" ]] || fail "sentinel parent is not frozen pretrigger head"
mapfile -t trigger_delta < <(git diff --name-only HEAD^ HEAD)
[[ "${#trigger_delta[@]}" -eq 1 && "${trigger_delta[0]}" == "$SENTINEL" ]] || fail "trigger commit changed more than sentinel"

git cat-file -e "$QUALIFIED_POST_HEAD^{commit}" 2>/dev/null || fail "qualified post head unavailable"
git cat-file -e "$QUALIFIED_ENGINE_EXECUTION_HEAD^{commit}" 2>/dev/null || fail "qualified execution head unavailable"
git merge-base --is-ancestor "$QUALIFIED_POST_HEAD" HEAD || fail "primary branch does not descend from qualified engine"
[[ "$(git rev-parse HEAD:src)" == "$SOURCE_TREE" ]] || fail "production source tree drift"
[[ "$(git rev-parse HEAD:$ENGINE)" == "$ENGINE_BLOB" ]] || fail "qualified engine blob drift"
[[ "$(git rev-parse HEAD:$QUAL_RUNNER)" == "$QUAL_RUNNER_BLOB" ]] || fail "qualification runner blob drift"
[[ "$(git rev-parse HEAD:$ORIGIN_DIR)" == "$(git rev-parse "$BASE_HARNESS:$ORIGIN_DIR")" ]] || fail "origin harness drift"
[[ "$(git rev-parse HEAD:$GW_A_DIR)" == "$(git rev-parse "$BASE_HARNESS:$GW_A_DIR")" ]] || fail "GW-A drift"

mapfile -t primary_delta < <(git diff --name-only "$QUALIFIED_POST_HEAD..HEAD")
for path in "${primary_delta[@]}"; do
  case "$path" in
    "$RUNNER"|"$WORKFLOW"|"$SENTINEL") ;;
    *) fail "out-of-scope primary execution mutation: $path" ;;
  esac
done

git fetch --quiet --no-tags origin refs/heads/work/pub-gc-scientific-contract:refs/remotes/origin/work/pub-gc-scientific-contract
git cat-file -e "$PRIMARY_MANIFEST_COMMIT^{commit}" 2>/dev/null || fail "primary manifest authority unavailable"
[[ "$(git rev-parse "$PRIMARY_MANIFEST_COMMIT:$PRIMARY_MANIFEST_PATH")" == "$PRIMARY_MANIFEST_BLOB" ]] || fail "primary manifest blob drift"
manifest_text="$(git show "$PRIMARY_MANIFEST_COMMIT:$PRIMARY_MANIFEST_PATH")"
grep -Fq "A_cm: -80.0" <<<"$manifest_text" || fail "primary A mismatch"
grep -Fq "B_cm: -102.5" <<<"$manifest_text" || fail "primary B mismatch"
grep -Fq "C_cm: -98.75" <<<"$manifest_text" || fail "primary C mismatch"
grep -Fq "coupling_window_days: 0.03" <<<"$manifest_text" || fail "primary dt mismatch"

AUTHORITY_COMMIT="${S[execution_authority_commit]}"
git cat-file -e "$AUTHORITY_COMMIT^{commit}" 2>/dev/null || fail "execution authority commit unavailable"
AUTHORITY_PATH="docs/publications/manifests/PUB-GC-E1-PRIMARY-EXECUTION-0001.yaml"
authority_text="$(git show "$AUTHORITY_COMMIT:$AUTHORITY_PATH")" || fail "execution authority document unavailable"
grep -Fq "pretrigger_head: ${S[pretrigger_head]}" <<<"$authority_text" || fail "authority pretrigger mismatch"
grep -Fq "engine_blob: $ENGINE_BLOB" <<<"$authority_text" || fail "authority engine mismatch"
grep -Fq "primary_manifest_commit: $PRIMARY_MANIFEST_COMMIT" <<<"$authority_text" || fail "authority manifest mismatch"
RUNNER_BLOB="$(git rev-parse HEAD^:$RUNNER)"
WORKFLOW_BLOB="$(git rev-parse HEAD^:$WORKFLOW)"
grep -Fq "runner_blob: $RUNNER_BLOB" <<<"$authority_text" || fail "authority runner mismatch"
grep -Fq "workflow_blob: $WORKFLOW_BLOB" <<<"$authority_text" || fail "authority workflow mismatch"

echo "PUB_GC_E1_PRIMARY_AUTHORITY_LOCK=PASS:$AUTHORITY_COMMIT"
echo "PUB_GC_E1_PRIMARY_MANIFEST_LOCK=PASS:$PRIMARY_MANIFEST_COMMIT:$PRIMARY_MANIFEST_BLOB"
echo "PUB_GC_E1_PRIMARY_PRETRIGGER_HEAD=PASS:${S[pretrigger_head]}"
echo "PUB_GC_E1_PRIMARY_TRIGGER_DELTA_ONLY_SENTINEL=PASS"
echo "PUB_GC_E1_PRIMARY_SOURCE_TREE_LOCK=PASS:$SOURCE_TREE"
echo "PUB_GC_E1_PRIMARY_ENGINE_BLOB_LOCK=PASS:$ENGINE_BLOB"
echo "PUB_GC_E1_PRIMARY_QUAL_RUNNER_BLOB_LOCK=PASS:$QUAL_RUNNER_BLOB"
echo "PUB_GC_E1_PRIMARY_ORIGIN_HARNESS_LOCK=PASS"
echo "PUB_GC_E1_PRIMARY_GW_A_LOCK=PASS"
echo "PUB_GC_E1_PRIMARY_TUPLE=A=$A,B=$B,C=$C,DT=$DT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-gc-e1-primary-${GITHUB_RUN_ID:-local}-$$"
ARTIFACT_DIR="$ROOT/artifacts/PUB-GC-E1-PRIMARY-0001"
mkdir -p "$BUILD" "$ARTIFACT_DIR"
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
)

OUT="$BUILD/o2"
mkdir -p "$OUT"
objects=()
for source in "${MODULE_SRC[@]}"; do
  [[ -f "$source" ]] || fail "missing compile source $source"
  obj="$OUT/$(echo "$source" | tr '/.' '__').o"
  extra=()
  [[ "$source" == "src/solver/mod_soil_water_solver_contract.f90" ]] && extra=(-Wno-error=unused-dummy-argument)
  gfortran "${COMMON[@]}" "${extra[@]}" -O2 -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -O2 -J "$OUT" -I "$OUT" -c "$ENGINE" -o "$OUT/engine.o"
gfortran -fopenmp -O2 "${objects[@]}" "$OUT/engine.o" -o "$OUT/engine"
echo "PUB_GC_E1_PRIMARY_BUILD_O2=PASS"

# Exactly one held-out primary invocation. Do not add a second optimization-mode run.
set +e
timeout 240s "$OUT/engine" "$A" "$B" "$C" "$DT" > "$ARTIFACT_DIR/primary-output.txt" 2>&1
rc=$?
set -e
echo "$rc" > "$ARTIFACT_DIR/exit-code.txt"
if [[ "$rc" -ne 0 ]]; then
  cat "$ARTIFACT_DIR/primary-output.txt" >&2
  echo "PUB_GC_E1_PRIMARY_HELDOUT_INVOCATION=EXECUTION_FAILURE:$rc"
  fail "held-out primary engine invocation failed; frozen values must not be substituted"
fi
echo "PUB_GC_E1_PRIMARY_HELDOUT_INVOCATION=PASS"

for marker in \
  'PUB_GC_E1_ENGINE_SAME_ORIGIN_IDENTITY=PASS' \
  'PUB_GC_E1_ENGINE_ACCEPTED_ORIGIN_UNCHANGED=PASS' \
  'PUB_GC_E1_ENGINE_GW_A_SAME_CHECKPOINT_NO_COMMIT=PASS' \
  'PUB_GC_E1_ENGINE_HISTORY_DIAG_PRODUCTION_VALID=false' \
  'PUB_GC_E1_PRIMARY_ENGINE_ORACLE=PASS'; do
  grep -Fq "$marker" "$ARTIFACT_DIR/primary-output.txt" || fail "missing primary validity marker: $marker"
done
[[ "$(grep -c '^PUB_GC_E1_ENGINE_ROW|' "$ARTIFACT_DIR/primary-output.txt")" -eq 16 ]] || fail "primary SWAP telemetry row count"
[[ "$(grep -c '^PUB_GC_E1_ENGINE_GW_ROW|' "$ARTIFACT_DIR/primary-output.txt")" -eq 16 ]] || fail "primary GW telemetry row count"

cat "$ARTIFACT_DIR/primary-output.txt"
echo "PUB_GC_E1_PRIMARY_OUTPUT_SHA256=$(sha256sum "$ARTIFACT_DIR/primary-output.txt" | awk '{print $1}')"
echo "PUB_GC_E1_PRIMARY_EXECUTION_HEAD=$(git rev-parse HEAD)"
echo "PUB_GC_E1_PRIMARY_PRETRIGGER_HEAD_OBSERVED=$(git rev-parse HEAD^)"
echo "PUB_GC_E1_PRIMARY_ENGINE_BLOB_OBSERVED=$(git rev-parse HEAD:$ENGINE)"
echo "PUB_GC_E1_PRIMARY_RUNNER_BLOB_OBSERVED=$(git rev-parse HEAD:$RUNNER)"
echo "PUB_GC_E1_PRIMARY_WORKFLOW_BLOB_OBSERVED=$(git rev-parse HEAD:$WORKFLOW)"
echo "PUB_GC_E1_PRIMARY_EXECUTION=PASS"
