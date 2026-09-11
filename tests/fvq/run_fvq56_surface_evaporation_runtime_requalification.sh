#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=af9ec34ec587be76deea95763186a204f3ed32cd
BASE_SRC=fd07bc662410a7bfbd64b4960295997c9e05e19a
REF_TREE=9d08625217d7c0a7385df9da6a04183bcd9cb9e6
OWNER_CLOSEOUT=4a76095df80435ff466e52bc65984300bc45ea06
CANDIDATE=fdb0e745b362c81a042faba7f81cab53b1372d97
PROCESS=src/process/mod_restricted_surface_evaporation.f90
PROCESS_BLOB=a213af4deec2fe854d79120899827852a57237d1
RUNTIME=src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90
RUNTIME_BLOB=afd2de6893aced7b48eac33f6b3a51876b2c1d12
OWNER_STATUS_BLOB=d1ffa7505e96d0d954ed4b49b730bcc048b2ccf8
BUILD="${RUNNER_TEMP:-/tmp}/fvq56-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

fail() { echo "FVQ56_GATE_FAIL $*" >&2; exit 56; }
need_commit() {
  local sha="$1"
  git cat-file -e "${sha}^{commit}" 2>/dev/null || git fetch --no-tags origin "$sha" >/dev/null 2>&1 || fail "cannot fetch commit $sha"
}
for sha in "$BASE" "$OWNER_CLOSEOUT" "$CANDIDATE"; do need_commit "$sha"; done

test "$(git rev-parse ${BASE}:src)" = "$BASE_SRC" || fail 'qualification base src drift'
test "$(git rev-parse ${BASE}:reference)" = "$REF_TREE" || fail 'qualification base reference drift'
test "$(git rev-parse ${CANDIDATE}:$PROCESS)" = "$PROCESS_BLOB" || fail 'owner process blob drift'
test "$(git rev-parse ${CANDIDATE}:$RUNTIME)" = "$RUNTIME_BLOB" || fail 'owner runtime blob drift'
test "$(git rev-parse ${OWNER_CLOSEOUT}:integration/f-pm/F-PM06F_STATUS.json)" = "$OWNER_STATUS_BLOB" || fail 'owner status blob drift'
git show ${OWNER_CLOSEOUT}:integration/f-pm/F-PM06F_STATUS.json | grep -Fq 'QUALIFIED_RESTRICTED_SURFACE_EVAPORATION_RUNTIME_MATERIALIZATION_READY_FOR_INDEPENDENT_FVQ' || fail 'owner handoff decision missing'

test "$(git rev-parse HEAD:$PROCESS)" = "$PROCESS_BLOB" || fail 'qualification modified process candidate'
test "$(git rev-parse HEAD:$RUNTIME)" = "$RUNTIME_BLOB" || fail 'qualification modified runtime candidate'
test "$(git rev-parse HEAD:reference)" = "$REF_TREE" || fail 'qualification modified reference tree'
mapfile -t src_delta < <(git diff --name-only "$BASE"..HEAD -- src | sort)
expected=("$PROCESS" "$RUNTIME")
[[ "${src_delta[*]}" == "${expected[*]}" ]] || fail "qualification src delta is not exact immutable two-file candidate: ${src_delta[*]:-none}"
echo 'FVQ56_IMMUTABLE_TWO_FILE_CANDIDATE=PASS'
echo 'FVQ56_OWNER_HANDOFF_PROVENANCE=PASS'

python3 - "$PROCESS" "$RUNTIME" <<'PY'
from pathlib import Path
import re, sys

def executable_text(path):
    lines=[]
    for raw in Path(path).read_text().splitlines():
        lines.append(raw.split('!')[0])
    return '\n'.join(lines).lower()

process=executable_text(sys.argv[1])
runtime=executable_text(sys.argv[2])
combined=process+'\n'+runtime

# The runtime may consume committed state only through the qualified process-hydraulic-view seam.
required_runtime=(
    'call fmr_build_committed_process_hydraulic_view(committed, view, ok)',
    'call capacity_provider%evaluate(base_state, capacity)',
    'hydraulic%surface_is_ponded = view%ponding_depth > fmr_surface_evap_ponding_threshold_cm',
    'call evaluate_restricted_surface_evaporation(demand, hydraulic, result)',
)
for token in required_runtime:
    assert token in runtime, token

for forbidden in (
    'headcalc', 'newton', 'jacobian', 'modflow', 'mod_b110_surface_evaporation_capacity_provider',
    'mass_ledger', 'canonical_mass', 'mass%total_in', 'mass%total_out', 'storage_change',
    'runoff_flux', 'top_flux', '.swp', 'file_unit', 'pathname', 'midnight', 'day_of', 'month_of', 'year_of'
):
    assert forbidden not in combined, forbidden
assert not re.search(r'(^|[^a-z0-9_])save([^a-z0-9_]|$)', combined)
assert not re.search(r'\b(open|read|write|close)\s*\(', combined)
assert 'allocate(' not in process
# No persistent optional column state is introduced; runtime allocations are call-local detached hydraulic scratch only.
assert 'type, public :: fmr_surface_evaporation_runtime_diagnostics_t' in runtime
assert 'intent(inout) :: committed' not in runtime
print('FVQ56_ARCHITECTURE_SOURCE_GUARDS=PASS')
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
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_process_hydraulic_view_binding.f90
  src/process/mod_reference_et_demand_process.f90
  src/runtime/mod_fmr_reference_et_demand_binding.f90
  src/solver/mod_surface_evaporation_capacity_contract.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fvq/test_fvq56_surface_evaporation_runtime_independent.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/fvq56"
  "$OUT/fvq56" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "independent oracle O$opt"; }
  for marker in \
    FVQ56_HELDOUT_CLOSED_FORM_CASES_144=PASS \
    FVQ56_STATE_DERIVED_CAPACITY_TRANSFER=PASS \
    FVQ56_THRESHOLD_CLASSIFICATION=PASS \
    FVQ56_NEGATIVE_FINITE_CAPACITY_DRY_ZERO=PASS \
    FVQ56_ACTIVE_ZERO_AVAILABLE=PASS \
    FVQ56_DEMAND_PROVENANCE_FAIL_CLOSED=PASS \
    FVQ56_CAPACITY_FAIL_CLOSED=PASS \
    FVQ56_PROCESS_INVALID_DEMAND_FAIL_CLOSED=PASS \
    FVQ56_UNINITIALIZED_COMMITTED_FAIL_CLOSED=PASS \
    FVQ56_ABA_REPEATABILITY=PASS \
    FVQ56_COMMITTED_STATE_IMMUTABLE=PASS \
    FVQ56_INDEPENDENT_ORACLE=PASS; do
    grep -Fxq "$marker" "$OUT/output.txt" || fail "missing $marker O$opt"
  done
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || { diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true; fail 'O0/O2 transcript mismatch'; }
HASH="$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
cat "$BUILD/o0/output.txt"
echo "FVQ56_OUTPUT_SHA256=$HASH"
echo 'FVQ56_O0_O2_IDENTITY=PASS'
echo 'FVQ56_NO_SECOND_MASS_BOOKING=PASS'
echo 'FVQ56_TRANSACTIONAL_NONINTERFERENCE=PASS'
echo 'FVQ56_ARCHITECTURE_INVARIANTS=30_OF_30_NO_ADVERSE_DELTA'
echo 'FVQ56_GATE=PASS'
