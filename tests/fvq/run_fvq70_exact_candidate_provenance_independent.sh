#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fvq70-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FVQ70_VERIFIER_FAIL $*" >&2; exit 170; }

CANDIDATE=c25eb87f979f4c341713de8fdc890beb0ea3e35f
KERNEL=src/kernel/mod_kernel_transactions.f90
RECEIPT=src/runtime/mod_fmr_accepted_commit_receipt.f90
MATERIALIZER=src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90
PUBLICATION=src/runtime/mod_fmr_surface_evaporation_accepted_publication.f90

test "$(git merge-base "$CANDIDATE" HEAD)" = "$CANDIDATE" || fail 'qualification branch does not descend from frozen F-KT20 candidate'
git diff --quiet "$CANDIDATE"..HEAD -- src reference || fail 'independent qualification modified production or reference source'
[[ "$(git hash-object "$KERNEL")" == "9eec425476687ed383678c8afc43108faec316b5" ]] || fail 'kernel blob drift'
[[ "$(git hash-object "$RECEIPT")" == "76e110278435b48422236dd2aa4e1b290fa79928" ]] || fail 'receipt blob drift'
[[ "$(git hash-object "$MATERIALIZER")" == "72faabd7c74dbddecfc778dac8d24b48b423fc62" ]] || fail 'materializer blob drift'
[[ "$(git hash-object "$PUBLICATION")" == "b08c0a7f334238228096939a5e93baafe1cd5751" ]] || fail 'publication blob drift'
echo 'FVQ70_FROZEN_CANDIDATE_SOURCE=PASS'
echo 'FVQ70_INDEPENDENT_BRANCH_NO_PRODUCTION_CHANGE=PASS'

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
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fvq/test_fvq70_exact_candidate_provenance_independent.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "independent oracle O$opt did not execute cleanly"; }
  for marker in \
    FVQ70_SAME_OLD_TUPLE_DISTINCT_EXACT_ATTEMPTS=PASS \
    FVQ70_POSITIVE_EXACT_PUBLICATION=PASS \
    FVQ70_FVQ69_HN5=PASS_CLOSED \
    FVQ70_CROSS_DOMAIN_COMMIT=PASS_CLOSED \
    FVQ70_GENERIC_FKT_SURFACE_PUBLICATION=PASS_CLOSED \
    FVQ70_DUPLICATE_DOMAIN_EXACT_TOKEN_COLLISION=REPRODUCED \
    FVQ70_NO_MASS_REGRESSION=PASS \
    FVQ70_INDEPENDENT_ORACLE=PASS; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing marker O$opt: $marker"; }
  done
  if grep -Fq 'FVQ70_HN_DUPLICATE_EXECUTION_DOMAIN=FAIL_OPEN' "$OUT/output.txt"; then
    grep -Fq 'FVQ70_DECISION=NOT_QUALIFIED_RUNTIME_EXECUTION_DOMAIN_UNIQUENESS_NOT_ENFORCED' "$OUT/output.txt" || fail 'negative disposition missing'
    echo "FVQ70_COLLISION_DISPOSITION_O${opt}=NOT_QUALIFIED"
  elif grep -Fq 'FVQ70_HN_DUPLICATE_EXECUTION_DOMAIN=PASS_CLOSED' "$OUT/output.txt"; then
    grep -Fq 'FVQ70_DECISION=QUALIFIED_EXACT_CANDIDATE_ATTEMPT_PROVENANCE' "$OUT/output.txt" || fail 'positive disposition missing'
    echo "FVQ70_COLLISION_DISPOSITION_O${opt}=QUALIFIED"
  else
    cat "$OUT/output.txt" >&2
    fail 'duplicate-domain disposition missing'
  fi
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 semantic observation drift'
}
cat "$BUILD/o0/output.txt"
echo 'FVQ70_O0_O2_SEMANTIC_IDENTITY=PASS'
if grep -Fq 'FVQ70_HN_DUPLICATE_EXECUTION_DOMAIN=FAIL_OPEN' "$BUILD/o0/output.txt"; then
  echo 'FVQ70_DECISIVE_DISPOSITION=NOT_QUALIFIED_ROUTE_TO_RUNTIME_DOMAIN_UNIQUENESS_ENFORCEMENT'
else
  echo 'FVQ70_DECISIVE_DISPOSITION=QUALIFIED_EXACT_CANDIDATE_ATTEMPT_PROVENANCE'
fi
echo 'FVQ70_VERIFIER_EXECUTION=PASS'
