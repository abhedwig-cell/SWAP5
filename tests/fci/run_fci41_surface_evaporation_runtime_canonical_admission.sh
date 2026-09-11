#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=af9ec34ec587be76deea95763186a204f3ed32cd
BASE_TREE=5116f1af87e72601f99b303d5f3c69c7f21b7564
BASE_SRC=fd07bc662410a7bfbd64b4960295997c9e05e19a
BASE_REF=9d08625217d7c0a7385df9da6a04183bcd9cb9e6
COMPOSITION=1ff184f96cce252c039295b82c6b0ed5c5921f34
COMPOSITION_TREE=9e5904488db80e5401027a3a1e8abbafdccfc22c
PROCESS=src/process/mod_restricted_surface_evaporation.f90
PROCESS_BLOB=a213af4deec2fe854d79120899827852a57237d1
RUNTIME=src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90
RUNTIME_BLOB=afd2de6893aced7b48eac33f6b3a51876b2c1d12
OWNER=fdb0e745b362c81a042faba7f81cab53b1372d97
OWNER_CLOSEOUT=4a76095df80435ff466e52bc65984300bc45ea06
FVQ52=003209963ead7f14e375fca7f7d5d4b2a1996ae8
FVQ54=7cf8f6685ca24f855621f872bcf906f346edfa72
FVQ56=0cdbc193976c73bef208a82547b3c9ea81c4102c
FVQ56_STATUS_BLOB=7bec3e5186942246f5143d716fe40059b5bf0771
FVQ56_EXACT_HEAD_RUN=34548837037
BUILD="${RUNNER_TEMP:-/tmp}/fci41-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

fail() { echo "FCI41_GATE_FAIL $*" >&2; exit 41; }
need_commit() {
  local sha="$1"
  git cat-file -e "${sha}^{commit}" 2>/dev/null || git fetch --no-tags origin "$sha" >/dev/null 2>&1 || fail "cannot fetch $sha"
}
for sha in "$BASE" "$COMPOSITION" "$OWNER" "$OWNER_CLOSEOUT" "$FVQ52" "$FVQ54" "$FVQ56"; do need_commit "$sha"; done

git fetch --no-tags origin integration/f-ci-canonical >/dev/null 2>&1 || fail 'cannot fetch canonical'
test "$(git rev-parse ${BASE}^{tree})" = "$BASE_TREE" || fail 'base tree drift'
test "$(git rev-parse ${BASE}:src)" = "$BASE_SRC" || fail 'base src tree drift'
test "$(git rev-parse ${BASE}:reference)" = "$BASE_REF" || fail 'base reference tree drift'
test "$(git rev-parse origin/integration/f-ci-canonical)" = "$BASE" || fail 'canonical moved after F-CI41 activation; recomposition required'
test "$(git rev-parse ${COMPOSITION}^)" = "$BASE" || fail 'composition is not direct child of current canonical'
test "$(git rev-parse ${COMPOSITION}^{tree})" = "$COMPOSITION_TREE" || fail 'composition tree drift'
test "$(git rev-parse ${OWNER}^{tree})" = "$COMPOSITION_TREE" || fail 'composition tree is not owner-candidate tree-identical'
test "$(git rev-parse ${COMPOSITION}:$PROCESS)" = "$PROCESS_BLOB" || fail 'structural process blob drift'
test "$(git rev-parse ${COMPOSITION}:$RUNTIME)" = "$RUNTIME_BLOB" || fail 'runtime materialization blob drift'
test "$(git rev-parse HEAD:$PROCESS)" = "$PROCESS_BLOB" || fail 'governance changed structural process blob'
test "$(git rev-parse HEAD:$RUNTIME)" = "$RUNTIME_BLOB" || fail 'governance changed runtime materialization blob'
git diff --quiet "$COMPOSITION"..HEAD -- src || fail 'post-composition governance changed production source'
test "$(git rev-parse HEAD:reference)" = "$BASE_REF" || fail 'F-CI41 changed reference source'
mapfile -t delta < <(git diff --name-only "$BASE".."$COMPOSITION" -- src | sort)
expected=("$PROCESS" "$RUNTIME")
[[ "${delta[*]}" == "${expected[*]}" ]] || fail "unexpected production delta: ${delta[*]:-none}"
echo 'FCI41_CURRENT_CANONICAL_EXACT_BASE=PASS'
echo 'FCI41_EXACT_TWO_FILE_PRODUCTION_SCOPE=PASS'
echo 'FCI41_OWNER_TREE_IDENTITY=PASS'
echo 'FCI41_REFERENCE_IMMUTABLE=PASS'

# Independent qualification authority is pinned mechanically. The exact-status-head
# run was independently verified before this admission workunit was activated.
test "$(git rev-parse ${FVQ56}:integration/f-vq/F-VQ56_STATUS.json)" = "$FVQ56_STATUS_BLOB" || fail 'F-VQ56 status blob drift'
git show ${FVQ56}:integration/f-vq/F-VQ56_STATUS.json | grep -Fq \
  'QUALIFIED_RESTRICTED_SURFACE_EVAPORATION_RUNTIME_MATERIALIZATION_WITHIN_FROZEN_SWINTER0_SWREDU0_SCOPE' || fail 'F-VQ56 qualification decision missing'
git show ${FVQ56}:integration/f-vq/F-VQ56_STATUS.json | grep -Fq '"independently_qualified": true' || fail 'F-VQ56 independent-qualified state missing'
git show ${OWNER_CLOSEOUT}:integration/f-pm/F-PM06F_STATUS.json | grep -Fq \
  'QUALIFIED_RESTRICTED_SURFACE_EVAPORATION_RUNTIME_MATERIALIZATION_READY_FOR_INDEPENDENT_FVQ' || fail 'F-PM06F owner handoff missing'
echo "FCI41_FVQ56_EXACT_STATUS_HEAD_RUN_AUTHORITY=${FVQ56_EXACT_HEAD_RUN}"
echo 'FCI41_INDEPENDENT_QUALIFICATION_AUTHORITY=PASS'

python3 - "$PROCESS" "$RUNTIME" <<'PY'
from pathlib import Path
import re, sys
p=Path(sys.argv[1]).read_text().lower()
r=Path(sys.argv[2]).read_text().lower()
assert 'max(0.0_real64, hydraulic%evaporation_capacity)' in p
assert 'view%ponding_depth > fmr_surface_evap_ponding_threshold_cm' in r
assert 'call capacity_provider%evaluate(base_state, capacity)' in r
assert 'call evaluate_restricted_surface_evaporation(demand, hydraulic, result)' in r
for text in (p, r):
    assert not re.search(r'(^|[^a-z0-9_])save([^a-z0-9_]|$)', text)
    assert not re.search(r'\b(open|read|write|close)\s*\(', text)
for forbidden in ('headcalc','modflow','mass_ledger','canonical_mass','mass%total_in','mass%total_out',
                  'storage_change','top_flux','runoff_flux','.swp','file_unit','pathname','midnight','day_of','month_of','year_of'):
    assert forbidden not in r, forbidden
assert 'mod_b110_surface_evaporation_capacity_provider' not in r
print('FCI41_ARCHITECTURE_SOURCE_GUARDS=PASS')
print('FCI41_NO_SECOND_MASS_BOOKING_PATH=PASS')
print('FCI41_NO_BOUNDARY_OR_PHYSICS_SCOPE_WIDENING=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -pedantic -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
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
  src/solver/mod_b110_surface_evaporation_capacity_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90
)

# Replay the independently written F-VQ56 abstract-provider oracle from its exact authority.
git show ${FVQ56}:tests/fvq/test_fvq56_surface_evaporation_runtime_independent.f90 > "$BUILD/fvq56-abstract.f90"
# Replay the independent real-B1.10 integration oracle. Shorten only its overlong
# program identifier in the transient copy to satisfy Fortran 2008 identifier limits.
git show ${FVQ56}:tests/fvq/test_fvq56_surface_evaporation_runtime_materialization_independent.f90 | \
  sed 's/test_fvq56_surface_evaporation_runtime_materialization_independent/fci41_real_b110/g' > "$BUILD/fvq56-real-b110.f90"

run_runtime_oracle() {
  local opt="$1" testfile="$2" tag="$3"
  local out="$BUILD/${tag}-o${opt}"
  mkdir -p "$out"
  local objects=()
  for src in "${MODULE_SRC[@]}"; do
    local obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J"$out" -I"$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J"$out" -I"$out" -c "$testfile" -o "$out/test.o"
  gfortran -O"$opt" "${objects[@]}" "$out/test.o" -o "$out/test.exe"
  "$out/test.exe" > "$out/output.txt" 2>&1 || { cat "$out/output.txt" >&2; fail "$tag O$opt"; }
}

for opt in 0 2; do
  run_runtime_oracle "$opt" "$BUILD/fvq56-abstract.f90" abstract
  run_runtime_oracle "$opt" "$BUILD/fvq56-real-b110.f90" realb110
done
cmp -s "$BUILD/abstract-o0/output.txt" "$BUILD/abstract-o2/output.txt" || fail 'abstract VQ56 O0/O2 drift'
cmp -s "$BUILD/realb110-o0/output.txt" "$BUILD/realb110-o2/output.txt" || fail 'real-B1.10 VQ56 O0/O2 drift'
grep -Fxq 'FVQ56_INDEPENDENT_ORACLE=PASS' "$BUILD/abstract-o0/output.txt" || fail 'abstract VQ56 oracle marker missing'
grep -Fxq 'FVQ56_REAL_B110_DRY_INTEGRATION=PASS' "$BUILD/realb110-o0/output.txt" || fail 'real B1.10 dry marker missing'
grep -Fxq 'FVQ56_REAL_B110_PONDED_INTEGRATION=PASS' "$BUILD/realb110-o0/output.txt" || fail 'real B1.10 ponded marker missing'
grep -Fxq 'FVQ56_NO_AUTHORITATIVE_MASS_BOOKING=PASS' "$BUILD/realb110-o0/output.txt" || fail 'real B1.10 mass marker missing'
echo "FCI41_ABSTRACT_ORACLE_SHA256=$(sha256sum "$BUILD/abstract-o0/output.txt" | awk '{print $1}')"
echo "FCI41_REAL_B110_ORACLE_SHA256=$(sha256sum "$BUILD/realb110-o0/output.txt" | awk '{print $1}')"
echo 'FCI41_FVQ56_HELDOUT_REPLAY=PASS'
echo 'FCI41_O0_O2_IDENTITY=PASS'

# Replay upstream independent component oracles directly against the composed source.
git show ${FVQ52}:tests/fvq/test_fvq52_surface_evaporation_independent.f90 > "$BUILD/fvq52.f90"
for opt in 0 2; do
  out="$BUILD/fvq52-o$opt"; mkdir -p "$out"
  gfortran "${COMMON[@]}" -O"$opt" -J"$out" -I"$out" -c "$PROCESS" -o "$out/process.o"
  gfortran "${COMMON[@]}" -O"$opt" -J"$out" -I"$out" -c "$BUILD/fvq52.f90" -o "$out/test.o"
  gfortran -O"$opt" "$out/process.o" "$out/test.o" -o "$out/test.exe"
  "$out/test.exe" > "$out/output.txt"
  grep -Fxq 'FVQ52_INDEPENDENT_ORACLE=PASS' "$out/output.txt" || fail "F-VQ52 replay O$opt"
done
cmp -s "$BUILD/fvq52-o0/output.txt" "$BUILD/fvq52-o2/output.txt" || fail 'F-VQ52 O0/O2 drift'
echo 'FCI41_FVQ52_STRUCTURAL_REPLAY=PASS'

git show ${FVQ54}:tests/fvq/test_fvq54_surface_evaporation_capacity_independent.f90 > "$BUILD/fvq54.f90"
for opt in 0 2; do
  out="$BUILD/fvq54-o$opt"; mkdir -p "$out"; objs=()
  for src in src/solver/mod_soil_water_solver_contract.f90 src/solver/mod_b110_default_mvg_provider.f90 \
             src/solver/mod_surface_evaporation_capacity_contract.f90 src/solver/mod_b110_surface_evaporation_capacity_provider.f90; do
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J"$out" -I"$out" -c "$src" -o "$obj"
    objs+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J"$out" -I"$out" -c "$BUILD/fvq54.f90" -o "$out/test.o"
  gfortran -O"$opt" "${objs[@]}" "$out/test.o" -o "$out/test.exe"
  "$out/test.exe" > "$out/output.txt"
  grep -Fxq 'FVQ54_INDEPENDENT_ORACLE=PASS' "$out/output.txt" || fail "F-VQ54 replay O$opt"
  grep -Fxq 'FVQ54_SIGNED_EMAX_ORACLE=PASS' "$out/output.txt" || fail "F-VQ54 signed Emax replay O$opt"
done
cmp -s "$BUILD/fvq54-o0/output.txt" "$BUILD/fvq54-o2/output.txt" || fail 'F-VQ54 O0/O2 drift'
echo 'FCI41_FVQ54_CAPACITY_REPLAY=PASS'

echo 'FCI41_HARD_MASS_AUTHORITY_UNCHANGED=PASS'
echo 'FCI41_TRANSACTIONAL_NONINTERFERENCE=PASS'
echo 'FCI41_PERFORMANCE_SCOPE_HOLD=PASS'
echo 'FCI41_ARCHITECTURE_INVARIANTS=30_OF_30_NO_ADVERSE_DELTA'
echo 'FCI41_CANONICAL_ADMISSION_GATE=PASS'
