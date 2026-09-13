#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fpm10-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FPM10_GATE_FAIL $*" >&2; exit 110; }

BASE=4fae08472c053d1b3d43d3d0b4f9b61956e7b646
MATERIALIZER=src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90
PUBLICATION=src/runtime/mod_fmr_surface_evaporation_accepted_publication.f90
PROCESS=src/process/mod_restricted_surface_evaporation.f90

# G01 is deliberately a two-file production remediation. Physics, the process
# kernel, mass booking, solver code and reference source stay frozen.
test "$(git merge-base "$BASE" HEAD)" = "$BASE" || fail 'branch no longer descends from F-PM09 current-canonical authority'
mapfile -t src_delta < <(git diff --name-only "$BASE"..HEAD -- src | sort)
expected=("$MATERIALIZER" "$PUBLICATION")
[[ "${src_delta[*]}" == "${expected[*]}" ]] || fail "unexpected src delta: ${src_delta[*]:-none}"
git diff --quiet "$BASE"..HEAD -- reference || fail 'reference source changed'
test "$(git rev-parse HEAD:$PROCESS)" = a213af4deec2fe854d79120899827852a57237d1 || fail 'restricted surface-evaporation physics drift'
test "$(git rev-parse HEAD:src/runtime/mod_fmr_accepted_commit_receipt.f90)" = 6798b3296b426950bf028814585c3f5de9be950b || fail 'accepted commit receipt authority drift'
echo 'FPM10_EXACT_BOUNDED_PRODUCTION_SCOPE=PASS'

python3 - "$MATERIALIZER" "$PUBLICATION" <<'PY'
from pathlib import Path
import re, sys
m = Path(sys.argv[1]).read_text(encoding='utf-8').lower()
p = Path(sys.argv[2]).read_text(encoding='utf-8').lower()
required_materializer = [
    'type, public :: fmr_candidate_bound_surface_evaporation_t',
    'private',
    'subroutine fmr_materialize_candidate_bound_surface_evaporation',
    'committed%current_lineage_id() /= lineage_id',
    'committed%current_revision() /= origin_revision',
    'bound_result%result_value = process_result',
]
for token in required_materializer:
    if token not in m:
        raise SystemExit(f'missing candidate-bound materializer guard: {token}')
required_publication = [
    'type(fmr_candidate_bound_surface_evaporation_t), intent(in) :: bound_result',
    'if (.not. bound_result%ready()) return',
    'commit_receipt%current_lineage_id() /= prepared%lineage_id',
    'commit_receipt%origin_revision() /= prepared%origin_revision_value',
]
for token in required_publication:
    if token not in p:
        raise SystemExit(f'missing publication provenance guard: {token}')
# The old F-VQ57 attack surface must be structurally absent from publication.
for forbidden in ('surface_evaporation_result_t', 'kernel_candidate_state_t'):
    if forbidden in p:
        raise SystemExit(f'old caller-stamping surface remains in publication module: {forbidden}')
# Attribution is not another mass authority and neither module may introduce I/O
# or calendar assumptions.
for label, text in [('materializer',m),('publication',p)]:
    for forbidden in ('mass%total_in','mass%total_out','canonical_mass_accounting_t','mass_ledger',
                      'day_of','month_of','year_of','midnight','.swp','file_unit','pathname','modflow'):
        if forbidden in text:
            raise SystemExit(f'{label} forbidden token: {forbidden}')
    if re.search(r'\b(open|read|write|close)\s*\(', text):
        raise SystemExit(f'{label} introduced file I/O')
print('FPM10_SOURCE_PROVENANCE_BY_CONSTRUCTION=PASS')
print('FPM10_NO_SECOND_MASS_AUTHORITY=PASS')
print('FPM10_NO_IO_OR_CALENDAR_DEPENDENCY=PASS')
PY

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
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpm/test_fpm10_surface_evaporation_publication_provenance.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "owner oracle O$opt"; }
  for marker in \
    FPM10_REAL_FKT_CANDIDATES_AND_HARD_MASS=PASS \
    FPM10_BOUND_RESULT_POSITIVE_CONTROLS=PASS \
    FPM10_SOURCE_BIND_CROSS_CANDIDATE_REJECTED=PASS \
    FPM10_ACCEPTED_PUBLICATION_A_POSITIVE=PASS \
    FPM10_HN1_CROSS_CANDIDATE_SUBSTITUTION_REJECTED=PASS \
    FPM10_ACCEPTED_PUBLICATION_B_POSITIVE=PASS \
    FPM10_NO_SECOND_MASS_BOOKING=PASS \
    'FPM10_OWNER_PROVENANCE_TEST PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing marker O$opt: $marker"; }
  done
  echo "FPM10_OWNER_ORACLE_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 owner observation drift'
}
cat "$BUILD/o0/output.txt"
echo 'FPM10_OWNER_ORACLE_O0_O2_EXACT_IDENTITY=PASS'

# Existing raw materialization remains available for already-admitted callers.
# Its original entry point and process call must still exist unchanged in role.
grep -Fq 'subroutine fmr_materialize_restricted_surface_evaporation' "$MATERIALIZER" || fail 'existing materialization entry point removed'
grep -Fq 'call evaluate_restricted_surface_evaporation(demand, hydraulic, result)' "$MATERIALIZER" || fail 'existing process route removed'
echo 'FPM10_EXISTING_MATERIALIZATION_PATH_PRESERVED=PASS'

echo 'FPM10_OWNER_GATE=PASS'
