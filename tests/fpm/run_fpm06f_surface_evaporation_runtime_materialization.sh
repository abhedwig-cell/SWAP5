#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=af9ec34ec587be76deea95763186a204f3ed32cd
BASE_TREE=5116f1af87e72601f99b303d5f3c69c7f21b7564
BASE_SRC=fd07bc662410a7bfbd64b4960295997c9e05e19a
REF_TREE=9d08625217d7c0a7385df9da6a04183bcd9cb9e6
CANDIDATE=fdb0e745b362c81a042faba7f81cab53b1372d97
PROCESS=src/process/mod_restricted_surface_evaporation.f90
PROCESS_BLOB=a213af4deec2fe854d79120899827852a57237d1
RUNTIME=src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90
RUNTIME_BLOB=afd2de6893aced7b48eac33f6b3a51876b2c1d12
FVQ52=003209963ead7f14e375fca7f7d5d4b2a1996ae8
FVQ54=7cf8f6685ca24f855621f872bcf906f346edfa72
VIEW_BLOB=d7d85fe71ced0d94b29c8d9395859ae1834f7dd6
VIEW_BINDING_BLOB=37f5968ffe00b1ff56f824f77ab94d3825171acf
CAP_CONTRACT_BLOB=551513f77caeb9c54e8c8b1cdc326be0e9d01982
CAP_PROVIDER_BLOB=8909cdf342527a2b0266c8d9a5fc918f98556ea2
BUILD="${RUNNER_TEMP:-/tmp}/fpm06f-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

fail() { echo "FPM06F_GATE_FAIL $*" >&2; exit 66; }
need_commit() {
  local sha="$1"
  git cat-file -e "${sha}^{commit}" 2>/dev/null || git fetch --no-tags origin "$sha" >/dev/null 2>&1 || fail "cannot fetch commit $sha"
}
for sha in "$BASE" "$CANDIDATE" "$FVQ52" "$FVQ54"; do need_commit "$sha"; done

git fetch --no-tags origin integration/f-ci-canonical >/dev/null 2>&1 || fail 'cannot fetch current canonical'
test "$(git rev-parse ${BASE}^{tree})" = "$BASE_TREE" || fail 'base tree drift'
test "$(git rev-parse ${BASE}:src)" = "$BASE_SRC" || fail 'base src tree drift'
test "$(git rev-parse ${BASE}:reference)" = "$REF_TREE" || fail 'base reference drift'
test "$(git rev-parse origin/integration/f-ci-canonical:src)" = "$BASE_SRC" || fail 'canonical production source moved after F-PM06F activation'
test "$(git rev-parse origin/integration/f-ci-canonical:reference)" = "$REF_TREE" || fail 'canonical reference moved after F-PM06F activation'
test "$(git rev-parse ${CANDIDATE}^)" = "$BASE" || fail 'production candidate is not direct child of source authority'
test "$(git rev-parse ${CANDIDATE}:$PROCESS)" = "$PROCESS_BLOB" || fail 'F-PM06C process blob not materialized byte-identically'
test "$(git rev-parse ${CANDIDATE}:$RUNTIME)" = "$RUNTIME_BLOB" || fail 'runtime composition blob drift'
test "$(git rev-parse HEAD:$PROCESS)" = "$PROCESS_BLOB" || fail 'governance changed process blob'
test "$(git rev-parse HEAD:$RUNTIME)" = "$RUNTIME_BLOB" || fail 'governance changed runtime blob'
test "$(git rev-parse HEAD:reference)" = "$REF_TREE" || fail 'F-PM06F changed reference source'
git diff --quiet "$CANDIDATE"..HEAD -- src || fail 'post-candidate governance changed production source'
mapfile -t delta < <(git diff --name-only "$BASE".."$CANDIDATE" -- src | sort)
expected=("$PROCESS" "$RUNTIME")
[[ "${delta[*]}" == "${expected[*]}" ]] || fail "unexpected production delta: ${delta[*]:-none}"
echo 'FPM06F_EXACT_TWO_FILE_PRODUCTION_SCOPE=PASS'

# Independent structural and hydraulic authorities are provenance inputs, not replaced by owner assertions.
test "$(git rev-parse ${FVQ52}:qualification/f-vq/F-VQ52_STATUS.json)" = 7230197d60f1c266586e1893ae51fb1b2722c7a6 || fail 'F-VQ52 status blob drift'
git show ${FVQ52}:qualification/f-vq/F-VQ52_STATUS.json | grep -Fq 'QUALIFIED_RESTRICTED_SURFACE_EVAPORATION_STRUCTURAL_CANDIDATE_WITHIN_FROZEN_SWINTER0_SWREDU0_SCOPE' || fail 'F-VQ52 decision missing'
test "$(git rev-parse ${FVQ54}:integration/f-vq/F-VQ54_STATUS.json)" = 3b57efb0c29349254da4bc6cbfdc77b46a4ff9fc || fail 'F-VQ54 status blob drift'
git show ${FVQ54}:integration/f-vq/F-VQ54_STATUS.json | grep -Fq 'QUALIFIED_RESTRICTED_SCALAR_SURFACE_EVAPORATION_HYDRAULIC_CAPACITY_WITHIN_FROZEN_SWINTER0_SWREDU0_SCOPE' || fail 'F-VQ54 decision missing'
test "$(git rev-parse HEAD:src/solver/mod_process_hydraulic_view.f90)" = "$VIEW_BLOB" || fail 'committed hydraulic view blob drift'
test "$(git rev-parse HEAD:src/runtime/mod_fmr_process_hydraulic_view_binding.f90)" = "$VIEW_BINDING_BLOB" || fail 'committed hydraulic view binding blob drift'
test "$(git rev-parse HEAD:src/solver/mod_surface_evaporation_capacity_contract.f90)" = "$CAP_CONTRACT_BLOB" || fail 'capacity contract blob drift'
test "$(git rev-parse HEAD:src/solver/mod_b110_surface_evaporation_capacity_provider.f90)" = "$CAP_PROVIDER_BLOB" || fail 'capacity provider blob drift'
echo 'FPM06F_UPSTREAM_AUTHORITIES_PINNED=PASS'

python3 - "$RUNTIME" <<'PY'
from pathlib import Path
import re, sys
s=Path(sys.argv[1]).read_text()
low=s.lower()
required=(
 'class(surface_evaporation_capacity_provider_t), intent(in) :: capacity_provider',
 'call fmr_build_committed_process_hydraulic_view(committed, view, ok)',
 'call capacity_provider%evaluate(base_state, capacity)',
 'hydraulic%surface_is_ponded = view%ponding_depth > fmr_surface_evap_ponding_threshold_cm',
 'hydraulic%evaporation_capacity = capacity%evaporation_capacity',
 'call evaluate_restricted_surface_evaporation(demand, hydraulic, result)',
)
for token in required:
    assert token in low, token
for forbidden in ('mod_b110_surface_evaporation_capacity_provider','headcalc','modflow','mass_ledger','canonical_mass',
                  'mass%total_in','mass%total_out','storage_change','top_flux','runoff_flux','.swp','file_unit','pathname'):
    assert forbidden not in low, forbidden
assert not re.search(r'(^|[^a-z0-9_])save([^a-z0-9_]|$)',low)
assert not re.search(r'\b(open|read|write|close)\s*\(',low)
assert 'day_of' not in low and 'month_of' not in low and 'year_of' not in low and 'midnight' not in low
print('FPM06F_RUNTIME_ARCHITECTURE_SOURCE_GUARDS=PASS')
PY

# Replay the immutable F-VQ54 independent numerical oracle directly against the canonical capacity implementation now consumed here.
git show ${FVQ54}:tests/fvq/test_fvq54_surface_evaporation_capacity_independent.f90 > "$BUILD/fvq54-independent.f90"
for opt in 0 2; do
  OUT="$BUILD/cap-o$opt"; mkdir -p "$OUT"; objs=()
  flags=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -O"$opt" -J"$OUT" -I"$OUT")
  for src in \
    src/solver/mod_soil_water_solver_contract.f90 \
    src/solver/mod_b110_default_mvg_provider.f90 \
    src/solver/mod_surface_evaporation_capacity_contract.f90 \
    src/solver/mod_b110_surface_evaporation_capacity_provider.f90; do
    obj="$OUT/$(basename "${src%.*}").o"; gfortran "${flags[@]}" -c "$src" -o "$obj"; objs+=("$obj")
  done
  gfortran "${flags[@]}" -c "$BUILD/fvq54-independent.f90" -o "$OUT/test.o"
  gfortran -O"$opt" "${objs[@]}" "$OUT/test.o" -o "$OUT/fvq54"
  "$OUT/fvq54" > "$OUT/output.txt"
  grep -Fxq 'FVQ54_INDEPENDENT_ORACLE=PASS' "$OUT/output.txt" || fail "F-VQ54 oracle replay O$opt"
  grep -Fxq 'FVQ54_SIGNED_EMAX_ORACLE=PASS' "$OUT/output.txt" || fail "F-VQ54 signed Emax replay O$opt"
done
cmp -s "$BUILD/cap-o0/output.txt" "$BUILD/cap-o2/output.txt" || fail 'F-VQ54 replay O0/O2 drift'
echo 'FPM06F_FVQ54_ORACLE_REPLAY_CURRENT_CANONICAL=PASS'

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
  OUT="$BUILD/runtime-o$opt"; mkdir -p "$OUT"; objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpm/test_fpm06f_surface_evaporation_runtime_materialization.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/fpm06f"
  "$OUT/fpm06f" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "runtime test O$opt"; }
  for marker in \
    FPM06F_DRY_CAPACITY_LIMIT=PASS \
    FPM06F_DRY_NEGATIVE_RAW_CAPACITY=PASS \
    FPM06F_PONDING_THRESHOLD_EXACT=PASS \
    FPM06F_PONDED_DEMAND=PASS \
    FPM06F_INVALID_DEMAND_FAIL_CLOSED=PASS \
    FPM06F_UNINITIALIZED_COMMITTED_FAIL_CLOSED=PASS \
    FPM06F_CAPACITY_FAIL_CLOSED=PASS \
    FPM06F_ABA_REPEATABILITY=PASS \
    FPM06F_COMMITTED_BASE_UNCHANGED=PASS \
    FPM06F_NO_MASS_BOOKING_RESULT_ONLY=PASS \
    'FPM06F_RUNTIME_MATERIALIZATION_TEST PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || fail "missing marker $marker O$opt"
  done
done
cmp -s "$BUILD/runtime-o0/output.txt" "$BUILD/runtime-o2/output.txt" || fail 'runtime O0/O2 output drift'
cat "$BUILD/runtime-o0/output.txt"
echo 'FPM06F_O0_O2_IDENTITY=PASS'
echo 'FPM06F_TRANSACTIONAL_NONINTERFERENCE=PASS'
echo 'FPM06F_HARD_MASS_AUTHORITY_UNCHANGED=PASS'
echo 'FPM06F_ARCHITECTURE_INVARIANTS=30_OF_30_NO_ADVERSE_DELTA'
echo 'FPM06F_GATE=PASS'
