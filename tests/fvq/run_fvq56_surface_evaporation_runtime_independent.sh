#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=af9ec34ec587be76deea95763186a204f3ed32cd
BASE_SRC=fd07bc662410a7bfbd64b4960295997c9e05e19a
BASE_REF=9d08625217d7c0a7385df9da6a04183bcd9cb9e6
OWNER_CANDIDATE=fdb0e745b362c81a042faba7f81cab53b1372d97
OWNER_CLOSEOUT=4a76095df80435ff466e52bc65984300bc45ea06
MATERIALIZATION=50f0955a5b2a4e98e4a325523cfb6b4c1c26be07
PROCESS=src/process/mod_restricted_surface_evaporation.f90
PROCESS_BLOB=a213af4deec2fe854d79120899827852a57237d1
RUNTIME=src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90
RUNTIME_BLOB=afd2de6893aced7b48eac33f6b3a51876b2c1d12
FVQ52=003209963ead7f14e375fca7f7d5d4b2a1996ae8
FVQ54=7cf8f6685ca24f855621f872bcf906f346edfa72
BUILD="${RUNNER_TEMP:-/tmp}/fvq56-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

fail() { echo "FVQ56_GATE_FAIL $*" >&2; exit 56; }
need_commit() {
  local sha="$1"
  git cat-file -e "${sha}^{commit}" 2>/dev/null || git fetch --no-tags origin "$sha" >/dev/null 2>&1 || fail "cannot fetch $sha"
}
for sha in "$BASE" "$OWNER_CANDIDATE" "$OWNER_CLOSEOUT" "$MATERIALIZATION" "$FVQ52" "$FVQ54"; do need_commit "$sha"; done

git fetch --no-tags origin integration/f-ci-canonical >/dev/null 2>&1 || fail 'cannot fetch canonical'
test "$(git rev-parse origin/integration/f-ci-canonical:src)" = "$BASE_SRC" || fail 'canonical production source moved'
test "$(git rev-parse origin/integration/f-ci-canonical:reference)" = "$BASE_REF" || fail 'canonical reference moved'
test "$(git rev-parse ${MATERIALIZATION}^)" = "$BASE" || fail 'materialization is not direct child of canonical source authority'
test "$(git rev-parse ${OWNER_CANDIDATE}^)" = "$BASE" || fail 'owner candidate parent drift'
test "$(git rev-parse ${MATERIALIZATION}^{tree})" = "$(git rev-parse ${OWNER_CANDIDATE}^{tree})" || fail 'materialized tree differs from immutable owner candidate'
test "$(git rev-parse ${MATERIALIZATION}:$PROCESS)" = "$PROCESS_BLOB" || fail 'structural process blob drift'
test "$(git rev-parse ${MATERIALIZATION}:$RUNTIME)" = "$RUNTIME_BLOB" || fail 'runtime composition blob drift'
test "$(git rev-parse HEAD:$PROCESS)" = "$PROCESS_BLOB" || fail 'qualification changed structural process'
test "$(git rev-parse HEAD:$RUNTIME)" = "$RUNTIME_BLOB" || fail 'qualification changed runtime composition'
git diff --quiet "$MATERIALIZATION"..HEAD -- src || fail 'qualification branch contains production repair'
mapfile -t delta < <(git diff --name-only "$BASE".."$MATERIALIZATION" -- src | sort)
expected=("$PROCESS" "$RUNTIME")
[[ "${delta[*]}" == "${expected[*]}" ]] || fail "unexpected materialized production delta: ${delta[*]:-none}"
echo 'FVQ56_CURRENT_CANONICAL_SOURCE_COMPOSITION=PASS'
echo 'FVQ56_IMMUTABLE_OWNER_CANDIDATE_MATERIALIZATION=PASS'
echo 'FVQ56_NO_PRODUCTION_REPAIR=PASS'

# Treat owner closeout as provenance only. Reconstruct scientific behavior below with a held-out oracle.
git show ${OWNER_CLOSEOUT}:integration/f-pm/F-PM06F_STATUS.json | grep -Fq \
  'QUALIFIED_RESTRICTED_SURFACE_EVAPORATION_RUNTIME_MATERIALIZATION_READY_FOR_INDEPENDENT_FVQ' || fail 'owner handoff decision missing'
test "$(git rev-parse ${FVQ52}:qualification/f-vq/F-VQ52_STATUS.json)" = 7230197d60f1c266586e1893ae51fb1b2722c7a6 || fail 'F-VQ52 authority drift'
git show ${FVQ52}:qualification/f-vq/F-VQ52_STATUS.json | grep -Fq \
  'QUALIFIED_RESTRICTED_SURFACE_EVAPORATION_STRUCTURAL_CANDIDATE_WITHIN_FROZEN_SWINTER0_SWREDU0_SCOPE' || fail 'F-VQ52 decision missing'
git show ${FVQ54}:integration/f-vq/F-VQ54_STATUS.json | grep -Fq \
  'QUALIFIED_RESTRICTED_SCALAR_SURFACE_EVAPORATION_HYDRAULIC_CAPACITY_WITHIN_FROZEN_SWINTER0_SWREDU0_SCOPE' || fail 'F-VQ54 decision missing'
echo 'FVQ56_UPSTREAM_INDEPENDENT_AUTHORITIES_PINNED=PASS'

python3 - "$PROCESS" "$RUNTIME" <<'PY'
from pathlib import Path
import re, sys
p=Path(sys.argv[1]).read_text().lower()
r=Path(sys.argv[2]).read_text().lower()
assert 'max(0.0_real64, hydraulic%evaporation_capacity)' in p
assert 'hydraulic%surface_is_ponded' in p
required=(
 'call fmr_build_committed_process_hydraulic_view(committed, view, ok)',
 'call capacity_provider%evaluate(base_state, capacity)',
 'view%ponding_depth > fmr_surface_evap_ponding_threshold_cm',
 'hydraulic%evaporation_capacity = capacity%evaporation_capacity',
 'call evaluate_restricted_surface_evaporation(demand, hydraulic, result)',
)
for token in required: assert token in r, token
for text in (p,r):
    assert not re.search(r'(^|[^a-z0-9_])save([^a-z0-9_]|$)', text)
    assert not re.search(r'\b(open|read|write|close)\s*\(', text)
for forbidden in ('headcalc','modflow','mass_ledger','canonical_mass','mass%total_in','mass%total_out',
                  'storage_change','top_flux','runoff_flux','.swp','file_unit','pathname','midnight','day_of','month_of','year_of'):
    assert forbidden not in r, forbidden
assert 'mod_b110_surface_evaporation_capacity_provider' not in r
print('FVQ56_RUNTIME_PROCESS_ARCHITECTURE_GUARDS=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -pedantic -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
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
TEST=tests/fvq/test_fvq56_surface_evaporation_runtime_independent.f90

for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c "$TEST" -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/fvq56"
  "$OUT/fvq56" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "held-out oracle O$opt"; }
  for marker in \
    FVQ56_EXACT_COMMITTED_BASE_TO_CAPACITY=PASS \
    FVQ56_DRY_POSITIVE_CAPACITY=PASS \
    FVQ56_DRY_ZERO_CAPACITY=PASS \
    FVQ56_SIGNED_NEGATIVE_CAPACITY_PRESERVED_AND_CLAMPED=PASS \
    FVQ56_PONDING_BELOW_EXACT_ABOVE_BOUNDARY=PASS \
    FVQ56_PONDED_ROUTE_INDEPENDENT_OF_SIGNED_CAPACITY=PASS \
    FVQ56_AVAILABLE_NONFINITE_CAPACITY_FAIL_CLOSED=PASS \
    FVQ56_CAPACITY_STATUS_FAIL_CLOSED=PASS \
    FVQ56_REJECTED_DEMAND_SHORT_CIRCUIT=PASS \
    FVQ56_NEGATIVE_ET_DEMAND_PROCESS_FAIL_CLOSED=PASS \
    FVQ56_UNINITIALIZED_COMMITTED_FAIL_CLOSED=PASS \
    FVQ56_ABA_DETERMINISTIC_REPLAY=PASS \
    FVQ56_COMMITTED_STATE_NONMUTATION=PASS \
    FVQ56_HARD_MASS_NONINTERFERENCE=PASS \
    FVQ56_INDEPENDENT_ORACLE=PASS; do
    grep -Fxq "$marker" "$OUT/output.txt" || fail "missing marker $marker O$opt"
  done
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || fail 'O0/O2 output identity drift'
cat "$BUILD/o0/output.txt"
echo "FVQ56_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'FVQ56_O0_O2_IDENTITY=PASS'
echo 'FVQ56_TRANSACTIONAL_NONINTERFERENCE=PASS'
echo 'FVQ56_HARD_MASS_AUTHORITY_UNCHANGED=PASS'
echo 'FVQ56_ARCHITECTURE_INVARIANTS=30_OF_30_NO_ADVERSE_DELTA'
echo 'FVQ56_GATE=PASS'
