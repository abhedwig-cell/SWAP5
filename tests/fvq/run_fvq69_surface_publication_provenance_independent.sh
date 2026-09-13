#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fvq69-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FVQ69_VERIFIER_ERROR $*" >&2; exit 169; }

CANDIDATE=c6ebf7bec2cbe39c984d266e01142d11cf0b1540
MATERIALIZER=src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90
PUBLICATION=src/runtime/mod_fmr_surface_evaporation_accepted_publication.f90

test "$(git merge-base "$CANDIDATE" HEAD)" = "$CANDIDATE" || fail 'qualification branch does not descend from frozen F-PM10 head'
git diff --quiet "$CANDIDATE"..HEAD -- src reference || fail 'independent branch changed production or reference source'
test "$(git rev-parse HEAD:$MATERIALIZER)" = b8ff1fb1d9434e952163b6955305c6373dd8ac82 || fail 'materializer candidate blob drift'
test "$(git rev-parse HEAD:$PUBLICATION)" = 13d264cc905a0acf5082b9bfeba018e4ee25183e || fail 'publication candidate blob drift'
echo 'FVQ69_FROZEN_CANDIDATE_SOURCE=PASS'
echo 'FVQ69_INDEPENDENT_BRANCH_NO_PRODUCTION_CHANGE=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/process/mod_soil_temperature_contract.f90
  src/process/mod_restricted_soil_temperature.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/process/mod_restricted_fixed_weir_surface_water.f90
  tests/fpm/mod_fpm08d7_optional_state_compat.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_process_hydraulic_view_binding.f90
  src/process/mod_reference_et_demand_process.f90
  src/runtime/mod_fmr_reference_et_demand_binding.f90
  src/solver/mod_surface_evaporation_capacity_contract.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_surface_evaporation_accepted_publication.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fvq/test_fvq69_same_provenance_attack.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"

  set +e
  "$OUT/test" > "$OUT/output.txt" 2>&1
  rc=$?
  set -e
  cat "$OUT/output.txt"
  test $rc -ne 0 || fail "HN5 unexpectedly did not trip verifier at O$opt"
  grep -Fq 'FVQ69_SAME_PUBLIC_PROVENANCE_TWO_CANDIDATES=PASS' "$OUT/output.txt" || fail "candidate setup missing O$opt"
  grep -Fq 'FVQ69_DISTINCT_RESULTS_WITH_SAME_PUBLIC_PROVENANCE=PASS' "$OUT/output.txt" || fail "distinct-result setup missing O$opt"
  grep -Fq 'FVQ69_POSITIVE_A_WITH_RECEIPT_A=PASS' "$OUT/output.txt" || fail "positive control missing O$opt"
  grep -Fq 'FVQ69_HN5_SAME_PROVENANCE_DISTINCT_CANDIDATE_SUBSTITUTION=FAIL_OPEN' "$OUT/output.txt" || fail "decisive fail-open marker missing O$opt"
  grep -Fq 'FVQ69_DECISION=NOT_QUALIFIED_EXACT_CANDIDATE_PROVENANCE_NOT_PROVEN' "$OUT/output.txt" || fail "negative decision marker missing O$opt"
  grep '^FVQ69_' "$OUT/output.txt" > "$OUT/markers.txt"
  echo "FVQ69_HN5_REPRODUCED_O${opt}=PASS"
done

cmp -s "$BUILD/o0/markers.txt" "$BUILD/o2/markers.txt" || {
  diff -u "$BUILD/o0/markers.txt" "$BUILD/o2/markers.txt" >&2 || true
  fail 'O0/O2 independent semantic marker drift'
}
echo 'FVQ69_HN5_O0_O2_SEMANTIC_IDENTITY=PASS'

# Independent structural check of the retired historical API. This is not the
# decisive negative, but confirms that F-PM10 did remove the exact old raw
# result + caller candidate prepare signature attacked by F-VQ57.
cat > "$BUILD/legacy_api_probe.f90" <<'F90'
program legacy_api_probe
  use mod_kernel_transactions, only: kernel_candidate_state_t
  use mod_restricted_surface_evaporation, only: surface_evaporation_result_t
  use mod_fmr_surface_evaporation_accepted_publication, only: &
       fmr_prepared_surface_evaporation_publication_t, fmr_prepare_surface_evaporation_publication
  implicit none
  type(surface_evaporation_result_t) :: raw
  type(kernel_candidate_state_t) :: candidate
  type(fmr_prepared_surface_evaporation_publication_t) :: prepared
  integer :: status
  call fmr_prepare_surface_evaporation_publication(raw, candidate, prepared, status)
end program legacy_api_probe
F90
if gfortran "${COMMON[@]}" -O0 -J "$BUILD/o0" -I "$BUILD/o0" -c "$BUILD/legacy_api_probe.f90" -o "$BUILD/legacy_api_probe.o" > "$BUILD/legacy_probe.log" 2>&1; then
  fail 'historical raw-result plus candidate stamping API still compiled'
fi
echo 'FVQ69_HISTORICAL_FVQ57_RAW_STAMPING_API_REMOVED=PASS'

echo 'FVQ69_DECISIVE_DISPOSITION=NOT_QUALIFIED_ROUTE_BACK_TO_OWNER_FOR_EXACT_CANDIDATE_OR_ATTEMPT_PROVENANCE'
echo 'FVQ69_VERIFIER_EXECUTION=PASS_NEGATIVE_QUALIFICATION'
