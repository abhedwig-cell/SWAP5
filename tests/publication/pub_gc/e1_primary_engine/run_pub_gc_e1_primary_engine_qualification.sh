#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT"

BASE_HARNESS="14ee1be3c221c973973a3fb3dcb450ff40d3f96a"
PRIMARY_FREEZE="c3114e455029ee5dee0d92dbc4814c3fc0923ef6"
PRIMARY_MANIFEST="docs/publications/manifests/PUB-GC-E1-PRIMARY-0001.yaml"
PRIMARY_MANIFEST_BLOB="abf45b4a83f528eda69024e3d75a38edc4ce713f"
ORIGIN_TEST="tests/publication/pub_gc/e1_origin/test_pub_gc_e1_origin_harness.f90"
ORIGIN_TEST_BLOB="687525b578eb0a28692dd666a87ddefe18b37c96"
ORIGIN_RUNNER="tests/publication/pub_gc/e1_origin/run_pub_gc_e1_origin_harness_qualification.sh"
ORIGIN_RUNNER_BLOB="8585a54e6ad46a9a3b9f5e3b72e5688c5c7e7a56"
GW_A_DIR="tests/publication/pub_gc/gw_a"
ENGINE="tests/publication/pub_gc/e1_primary_engine/test_pub_gc_e1_primary_engine.f90"
RUNNER="tests/publication/pub_gc/e1_primary_engine/run_pub_gc_e1_primary_engine_qualification.sh"
WORKFLOW=".github/workflows/pub-gc-e1-primary-engine-qualification.yml"

fail() { echo "PUB_GC_E1_ENGINE_GATE_FAIL $*" >&2; exit 41; }

git cat-file -e "$BASE_HARNESS^{commit}" 2>/dev/null || fail "missing qualified harness authority"
git cat-file -e "$PRIMARY_FREEZE^{commit}" 2>/dev/null || fail "missing frozen primary manifest authority"
[[ "$(git rev-parse "$PRIMARY_FREEZE:$PRIMARY_MANIFEST")" == "$PRIMARY_MANIFEST_BLOB" ]] || fail "primary manifest blob drift"
[[ "$(git rev-parse HEAD:src)" == "$(git rev-parse "$BASE_HARNESS:src")" ]] || fail "production source tree changed"
[[ "$(git rev-parse HEAD:$ORIGIN_TEST)" == "$ORIGIN_TEST_BLOB" ]] || fail "qualified origin test changed"
[[ "$(git rev-parse HEAD:$ORIGIN_RUNNER)" == "$ORIGIN_RUNNER_BLOB" ]] || fail "qualified origin runner changed"
[[ "$(git rev-parse HEAD:$GW_A_DIR)" == "$(git rev-parse "$BASE_HARNESS:$GW_A_DIR")" ]] || fail "qualified GW-A bytes changed"

mapfile -t changed < <(git diff --name-only "$BASE_HARNESS..HEAD")
for path in "${changed[@]}"; do
  case "$path" in
    "$ENGINE"|"$RUNNER"|"$WORKFLOW") ;;
    *) fail "out-of-scope research mutation: $path" ;;
  esac
done

echo 'PUB_GC_E1_ENGINE_RESEARCH_ONLY_SCOPE=PASS'
echo 'PUB_GC_E1_ENGINE_PRODUCTION_SRC_UNCHANGED=PASS'
echo 'PUB_GC_E1_ENGINE_ORIGIN_HARNESS_BYTES_UNCHANGED=PASS'
echo 'PUB_GC_E1_ENGINE_GW_A_BYTES_UNCHANGED=PASS'
echo "PUB_GC_E1_ENGINE_PRIMARY_FREEZE=PASS:$PRIMARY_FREEZE:$PRIMARY_MANIFEST_BLOB"

for forbidden in '-80.0' '-102.5' '-98.75'; do
  if grep -Fq -- "$forbidden" "$ENGINE"; then
    fail "held-out primary head embedded in generic engine: $forbidden"
  fi
done

if grep -Eq 'fmr_commit_candidate|%commit_candidate|kernel_reconstruct_committed_state_trusted' "$ENGINE"; then
  fail "generic engine contains forbidden publication/reconstruction route"
fi
grep -Fq 'call carriers(j-1)%initialize' "$ENGINE" || fail "recursive history initialize route missing"
grep -Fq 'states(j-1)%state' "$ENGINE" || fail "recursive history state chaining missing"
grep -Fq 'PUB_GC_E1_ENGINE_HISTORY_DIAG_PRODUCTION_VALID=false' "$ENGINE" || fail "invalid-for-production marker missing"

echo 'PUB_GC_E1_ENGINE_PUBLIC_API_ONLY_STATIC=PASS'
echo 'PUB_GC_E1_ENGINE_NO_PRODUCTION_COMMIT_STATIC=PASS'

QA='-61.0'
QB='-76.5'
QC='-69.25'
QDT='0.013'
echo "PUB_GC_E1_ENGINE_QUAL_FIXTURE=$QA,$QB,$QC,$QDT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-gc-e1-engine-${GITHUB_RUN_ID:-local}-$$"
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
  tests/fmr/mod_fmr04_fixed_top_provider.f90
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_groundwater_exchange_service_contract.f90
  tests/publication/pub_gc/gw_a/mod_pub_gc_gw_a.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    [[ -f "$source" ]] || fail "missing compile source $source"
    obj="$OUT/$(basename "${source%.*}").o"
    extra=()
    [[ "$source" == "src/solver/mod_soil_water_solver_contract.f90" ]] && extra=(-Wno-error=unused-dummy-argument)
    gfortran "${COMMON[@]}" "${extra[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$ENGINE" -o "$OUT/test.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  timeout 120s "$OUT/test" "$QA" "$QB" "$QC" "$QDT" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "generic primary engine O$opt"
  }

  for marker in     'PUB_GC_E1_ENGINE_SAME_ORIGIN_IDENTITY=PASS'     'PUB_GC_E1_ENGINE_ACCEPTED_ORIGIN_UNCHANGED=PASS'     'PUB_GC_E1_ENGINE_GW_A_SAME_CHECKPOINT_NO_COMMIT=PASS'     'PUB_GC_E1_ENGINE_HISTORY_DIAG_PRODUCTION_VALID=false'     'PUB_GC_E1_PRIMARY_ENGINE_ORACLE=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || {
      cat "$OUT/output.txt" >&2
      fail "missing O$opt marker: $marker"
    }
  done

  [[ "$(grep -c '^PUB_GC_E1_ENGINE_ROW|' "$OUT/output.txt")" -eq 16 ]] || fail "O$opt candidate telemetry row count"
  [[ "$(grep -c '^PUB_GC_E1_ENGINE_GW_ROW|' "$OUT/output.txt")" -eq 16 ]] || fail "O$opt GW-A telemetry row count"

  for spec in     'S1|SAME|1|A|' 'S1|SAME|2|B|' 'S1|SAME|3|A|' 'S1|SAME|4|C|'     'S2|SAME|1|A|' 'S2|SAME|2|C|' 'S2|SAME|3|A|' 'S2|SAME|4|B|'     'S1|HISTORY_DIAG|1|A|' 'S1|HISTORY_DIAG|2|B|' 'S1|HISTORY_DIAG|3|A|' 'S1|HISTORY_DIAG|4|C|'     'S2|HISTORY_DIAG|1|A|' 'S2|HISTORY_DIAG|2|C|' 'S2|HISTORY_DIAG|3|A|' 'S2|HISTORY_DIAG|4|B|'; do
    grep -Fq "PUB_GC_E1_ENGINE_ROW|$spec" "$OUT/output.txt" || fail "O$opt missing sequence row $spec"
  done
  echo "PUB_GC_E1_PRIMARY_ENGINE_O$opt=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail "O0/O2 engine oracle drift"
}

cp "$BUILD/o0/output.txt" "$BUILD/primary-engine-qualification-output.txt"
cat "$BUILD/o0/output.txt"
echo 'PUB_GC_E1_PRIMARY_ENGINE_O0_O2_IDENTITY=PASS'
echo "PUB_GC_E1_PRIMARY_ENGINE_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo "PUB_GC_E1_PRIMARY_ENGINE_HEAD=$(git rev-parse HEAD)"
echo "PUB_GC_E1_PRIMARY_ENGINE_SOURCE_TREE=$(git rev-parse HEAD:src)"
echo "PUB_GC_E1_PRIMARY_ENGINE_TEST_BLOB=$(git rev-parse HEAD:$ENGINE)"
echo "PUB_GC_E1_PRIMARY_ENGINE_RUNNER_BLOB=$(git rev-parse HEAD:$RUNNER)"
echo 'PUB_GC_E1_PRIMARY_ENGINE_QUALIFICATION=PASS'
