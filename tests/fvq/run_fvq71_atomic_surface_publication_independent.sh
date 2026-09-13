#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fvq71-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"; trap 'rm -rf "$BUILD"' EXIT; cd "$ROOT"
fail(){ echo "FVQ71_VERIFIER_FAIL $*" >&2; exit 171; }

CANDIDATE=c8ff545cf720db467389c67ac2f9a595e57277ed
PUB=src/runtime/mod_fmr_surface_evaporation_accepted_publication.f90
MAT=src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90
REC=src/runtime/mod_fmr_accepted_commit_receipt.f90
KER=src/kernel/mod_kernel_transactions.f90

test "$(git merge-base "$CANDIDATE" HEAD)" = "$CANDIDATE" || fail 'not descended from frozen candidate'
git diff --quiet "$CANDIDATE"..HEAD -- src reference || fail 'qualification branch changed production/reference source'
[[ "$(git hash-object "$PUB")" == f0f3ce5c16a66c2058c22a529e176d6b06446649 ]] || fail 'publication blob drift'
[[ "$(git hash-object "$MAT")" == b8ff1fb1d9434e952163b6955305c6373dd8ac82 ]] || fail 'materializer blob drift'
[[ "$(git hash-object "$REC")" == 6798b3296b426950bf028814585c3f5de9be950b ]] || fail 'receipt blob drift'
[[ "$(git hash-object "$KER")" == c7c5b7d3357e4e6739c8f647d6232baca45563e6 ]] || fail 'kernel blob drift'
echo 'FVQ71_FROZEN_SOURCE_BINDING=PASS'
echo 'FVQ71_NO_QUALIFICATION_PRODUCTION_CHANGE=PASS'

python3 - "$PUB" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]).read_text().lower()
req=['public :: fmr_commit_candidate_with_surface_evaporation_publication',
     'call fmr_materialize_candidate_bound_surface_evaporation',
     'call fmr_commit_candidate_with_receipt','call finalize_local_prepared']
for x in req:
    if x not in p: raise SystemExit('missing atomic contract: '+x)
for x in ['public :: fmr_prepare_surface_evaporation_publication','public :: fmr_finalize_surface_evaporation_publication']:
    if x in p: raise SystemExit('historical split API still public: '+x)
for x in ['canonical_mass_accounting_t','mass%total_in','mass%total_out','mass_ledger','execution_provenance_id','candidate_sequence_value','.swp','file_unit','modflow','midnight']:
    if x in p: raise SystemExit('forbidden dependency: '+x)
if re.search(r'\b(open|read|write|close)\s*\(',p): raise SystemExit('file IO introduced')
a=p.index('call fmr_materialize_candidate_bound_surface_evaporation'); b=p.index('call fmr_commit_candidate_with_receipt'); c=p.index('call finalize_local_prepared')
if not a<b<c: raise SystemExit('atomic order not preserved')
print('FVQ71_STATIC_ATOMIC_ORDER=PASS')
print('FVQ71_STATIC_NO_SPLIT_API=PASS')
print('FVQ71_STATIC_NO_SECOND_MASS_AUTHORITY=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SRC=(
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
 O="$BUILD/o$opt"; mkdir -p "$O"; objs=()
 for s in "${SRC[@]}"; do o="$O/$(basename "${s%.*}").o"; gfortran "${COMMON[@]}" -O"$opt" -J "$O" -I "$O" -c "$s" -o "$o"; objs+=("$o"); done
 gfortran "${COMMON[@]}" -O"$opt" -J "$O" -I "$O" -c tests/fvq/test_fvq71_atomic_surface_publication_independent.f90 -o "$O/test.o"
 gfortran -O"$opt" "${objs[@]}" "$O/test.o" -o "$O/test"
 "$O/test" > "$O/out.txt" 2>&1 || { cat "$O/out.txt" >&2; fail "independent oracle O$opt"; }
 for m in FVQ71_AMBIGUOUS_OLD_PROVENANCE_PAIR=REPRODUCED FVQ71_ATOMIC_CROSS_EXECUTOR_POSITIVE=PASS FVQ71_FVQ69_CLASS_STALE_ALTERNATE=PASS_CLOSED FVQ71_CROSS_LINEAGE_PRECOMMIT=PASS_CLOSED FVQ71_NO_MASS_REGRESSION=PASS FVQ71_DECISION=QUALIFIED_ATOMIC_SURFACE_EVAPORATION_ACCEPTED_PUBLICATION FVQ71_INDEPENDENT_ORACLE=PASS; do grep -Fq "$m" "$O/out.txt" || { cat "$O/out.txt" >&2; fail "missing $m O$opt"; }; done
 if gfortran "${COMMON[@]}" -O"$opt" -J "$O" -I "$O" -c tests/fvq/fvq71_forbidden_split_surface_publication.f90 -o "$O/attack.o" >"$O/attack.log" 2>&1; then cat "$O/attack.log" >&2; fail "historical split API externally compiled O$opt"; fi
 test ! -e "$O/attack.o" || fail "attacker object emitted O$opt"
 echo "FVQ71_SPLIT_API_HARD_NEGATIVE_O${opt}=PASS_CLOSED"
done
cmp -s "$BUILD/o0/out.txt" "$BUILD/o2/out.txt" || { diff -u "$BUILD/o0/out.txt" "$BUILD/o2/out.txt" >&2 || true; fail 'O0/O2 drift'; }
cat "$BUILD/o0/out.txt"
echo 'FVQ71_O0_O2_SEMANTIC_IDENTITY=PASS'
echo 'FVQ71_VERIFIER_EXECUTION=PASS'
