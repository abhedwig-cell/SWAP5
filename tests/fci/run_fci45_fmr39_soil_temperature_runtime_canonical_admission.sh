#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=e342f4f9c9d45e2ec2d23a6be6032cc0498d98e2
BASE_REF=9d08625217d7c0a7385df9da6a04183bcd9cb9e6
FMR39=87b553094b66980006b69f5ba8b53d70ccd0a8e0
FMR39_CLOSEOUT=843af75b8545b0644aece5cf58b5f499d7b5b600
FMR39_STATUS_BLOB=a8804dee6b839c543a5b8cdaced2338c5b8c4668
FMR39_AUDIT_BLOB=3888f5e5868cde580098cc7deafdebdec8055b6b
FMR39_TEST=tests/fmr/test_fmr39_soil_temperature_runtime_composition.f90
FMR39_TEST_BLOB=00a0d30fd4f1f3ef3888dbc03cf71d41770c4fab
FVQ58=5e81e14ad613cff7a72fc3f9cddcebc6696290d7
BACKEND=src/runtime/mod_fmr_serialized_reference_backend.f90
RESTART=src/runtime/mod_fmr_restart_state_contract.f90
BACKEND_BLOB=07877429f94ccf07c353fa5f8ba969c341ad88dd
RESTART_BLOB=bb2c37efce37a73441181f14d15847c652ab45ea
TEMP_CONTRACT=src/process/mod_soil_temperature_contract.f90
TEMP_PROVIDER=src/process/mod_restricted_soil_temperature.f90
TEMP_CONTRACT_BLOB=baa13df3975de2c699b0ec910477bcfa9b47f15e
TEMP_PROVIDER_BLOB=fa4e1d7b48d3515e6569c9080d497178c25c4e85
HYD_VIEW=src/solver/mod_process_hydraulic_view.f90
HYD_VIEW_BLOB=d7d85fe71ced0d94b29c8d9395859ae1834f7dd6
KERNEL=src/kernel/mod_kernel_transactions.f90
KERNEL_BLOB=f1acff10dd99c308a00f434440d6a9ef14632f0d
TX=src/transaction/mod_transaction_reference.f90
TX_BLOB=2fd932b74dbd0ffc0ec089f49e632b7ac8852df4
APP_CONTRACT=src/runtime/mod_coupling_application_accuracy_contract.f90
APP_CONTRACT_BLOB=c07d573d21e7d013ab962c0a9d28102ab7b5cdfc
FCI44P_STATUS=integration/f-ci/F-CI44P_STATUS.json
FCI44P_STATUS_BLOB=b29cb2f8b94d6d52614650a513b913f2b20b6a50
EXPECTED_OUTPUT_SHA256=cb08b8dc528f9a1dfc11db9ffffad5598fa9c4584b12feada1d129e47a236942
BUILD="${RUNNER_TEMP:-/tmp}/fci45-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"; mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'git worktree remove --force "$BUILD/fvq58" >/dev/null 2>&1 || true; rm -rf "$BUILD"' EXIT

fail(){ echo "FCI45_GATE_FAIL $*" >&2; exit 45; }
need_commit(){ git cat-file -e "$1^{commit}" 2>/dev/null || git fetch --no-tags origin "$1" >/dev/null 2>&1 || fail "cannot fetch $1"; }
for sha in "$BASE" "$FMR39" "$FMR39_CLOSEOUT" "$FVQ58"; do need_commit "$sha"; done

# Fail closed if canonical moved while this admission was being prepared.
git fetch --no-tags origin integration/f-ci-canonical >/dev/null 2>&1 || fail 'cannot fetch canonical'
CURRENT="$(git rev-parse origin/integration/f-ci-canonical)"
[[ "$CURRENT" == "$BASE" ]] || fail "canonical race: expected $BASE got $CURRENT"
test "$(git rev-parse ${BASE}:reference)" = "$BASE_REF" || fail 'canonical reference tree drift'
echo 'FCI45_PREPROMOTION_CANONICAL_RACE_GUARD=PASS'

# Net production source must be exactly the immutable two-file F-MR39 runtime delta.
test "$(git rev-parse HEAD:$BACKEND)" = "$BACKEND_BLOB" || fail 'backend blob differs from F-MR39 authority'
test "$(git rev-parse HEAD:$RESTART)" = "$RESTART_BLOB" || fail 'restart blob differs from F-MR39 authority'
test "$(git rev-parse ${FMR39}:$BACKEND)" = "$BACKEND_BLOB" || fail 'F-MR39 backend donor drift'
test "$(git rev-parse ${FMR39}:$RESTART)" = "$RESTART_BLOB" || fail 'F-MR39 restart donor drift'
mapfile -t src_delta < <(git diff --name-only "$BASE"..HEAD -- src | sort)
printf '%s\n' "${src_delta[@]}" > "$BUILD/src-delta"
printf '%s\n' "$BACKEND" "$RESTART" | sort > "$BUILD/src-expected"
cmp -s "$BUILD/src-delta" "$BUILD/src-expected" || { cat "$BUILD/src-delta" >&2; fail 'unexpected production source delta'; }
test "$(git rev-parse HEAD:reference)" = "$BASE_REF" || fail 'reference tree changed'
echo 'FCI45_EXACT_FMR39_TWO_BLOB_PRODUCTION_SCOPE=PASS'
echo 'FCI45_REFERENCE_IMMUTABLE=PASS'

# Pin the closed donor evidence rather than trusting the moving work branch.
test "$(git rev-parse ${FMR39_CLOSEOUT}:integration/f-mr/F-MR39_QUALIFICATION_STATUS.json)" = "$FMR39_STATUS_BLOB" || fail 'F-MR39 status evidence drift'
test "$(git rev-parse ${FMR39_CLOSEOUT}:integration/f-mr/F-MR39_INVARIANT_AUDIT.json)" = "$FMR39_AUDIT_BLOB" || fail 'F-MR39 invariant evidence drift'
git show ${FMR39_CLOSEOUT}:integration/f-mr/F-MR39_QUALIFICATION_STATUS.json | grep -Fq 'QUALIFIED_RESTRICTED_SOIL_TEMPERATURE_TRANSACTIONAL_RUNTIME_COMPOSITION' || fail 'F-MR39 qualified decision missing'
git show ${FMR39_CLOSEOUT}:integration/f-mr/F-MR39_QUALIFICATION_STATUS.json | grep -Fq '"candidate_source_authority": "87b553094b66980006b69f5ba8b53d70ccd0a8e0"' || fail 'F-MR39 source authority mismatch'
git show ${FMR39_CLOSEOUT}:integration/f-mr/F-MR39_INVARIANT_AUDIT.json | grep -Fq 'PASS_WITH_EXPLICIT_SCOPE_BOUNDARIES' || fail 'F-MR39 invariant audit not qualified'
echo 'FCI45_FMR39_CLOSED_AUTHORITY_PINNED=PASS'

# Qualified science and current-canonical seams must remain unchanged.
for spec in \
 "$TEMP_CONTRACT:$TEMP_CONTRACT_BLOB" \
 "$TEMP_PROVIDER:$TEMP_PROVIDER_BLOB" \
 "$HYD_VIEW:$HYD_VIEW_BLOB" \
 "$KERNEL:$KERNEL_BLOB" \
 "$TX:$TX_BLOB" \
 "$APP_CONTRACT:$APP_CONTRACT_BLOB" \
 "$FCI44P_STATUS:$FCI44P_STATUS_BLOB"; do
 path="${spec%%:*}"; blob="${spec##*:}"; test "$(git rev-parse HEAD:$path)" = "$blob" || fail "canonical seam drift $path";
done
echo 'FCI45_SCIENCE_KERNEL_TRANSACTION_HYDRAULIC_AND_FCI44P_SEAMS_PINNED=PASS'

# Explicit current-canonical architecture reconciliation must cover all 30 invariants.
python3 - <<'PY'
import json
from pathlib import Path
p=Path('integration/f-ci/F-CI45_ARCHITECTURE_AUDIT.json')
a=json.loads(p.read_text())
assert a['canonical_base']=='e342f4f9c9d45e2ec2d23a6be6032cc0498d98e2'
inv=a['invariants']
assert len(inv)==30
assert sorted(x['id'] for x in inv)==list(range(1,31))
assert all(x['status'] in {'QUALIFIED','PRESERVED','BOUNDED_NONCLAIM'} for x in inv)
print('FCI45_ALL_30_ARCHITECTURE_INVARIANTS_EXPLICITLY_RECONCILED=PASS')
PY

# Static transactional/state checks on the recomposed source.
python3 - <<'PY'
from pathlib import Path
b=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text().lower()
r=Path('src/runtime/mod_fmr_restart_state_contract.f90').read_text().lower()
state=b.split('type, extends(canonical_state_t), public :: fmr_b110_physical_state_t',1)[1].split('end type fmr_b110_physical_state_t',1)[0]
model=b.split('type, extends(kernel_model_t) :: fmr_serialized_reference_model_t',1)[1].split('end type fmr_serialized_reference_model_t',1)[0]
storage=b.split('real(real64) function fmr_serialized_storage',1)[1].split('end function fmr_serialized_storage',1)[0]
advance=b.split('subroutine fmr_serialized_advance',1)[1].split('end subroutine fmr_serialized_advance',1)[0]
assert 'type(soil_temperature_state_t), allocatable :: soil_temperature' in state
assert 'type(soil_temperature_workspace_t) :: soil_temperature_workspace' in model
assert 'soil_temperature_workspace' not in state
assert advance.index('call self%solver%solve') < advance.index('call trial_restricted_soil_temperature')
assert 'call commit_soil_temperature_state' in advance
assert 'soil_temperature' not in storage
assert 'process_hydraulic_view_t' in b
assert 'optional_state_layout_id > 0' in r and 'soil_temperature%ready()' in r and 'soil_temperature%node_count()' in r
print('FCI45_TRANSACTIONAL_THERMAL_STATE_ARCHITECTURE=PASS')
print('FCI45_WORKER_LOCAL_THERMAL_SCRATCH=PASS')
print('FCI45_RICHARDS_THEN_THERMAL_ORDER=PASS')
print('FCI45_WATER_STORAGE_EXCLUDES_THERMAL_ENERGY=PASS')
print('FCI45_RESTART_FAIL_CLOSED_THERMAL_SHAPE=PASS')
PY

git diff --check "$BASE" -- src/runtime tests/fci integration/f-ci .github/workflows || fail 'diff check failed'
echo 'FCI45_DIFF_CHECK=PASS'

# Use the exact F-MR39 runtime oracle source, but compile it against this recomposed current-canonical postimage.
test "$(git rev-parse ${FMR39}:$FMR39_TEST)" = "$FMR39_TEST_BLOB" || fail 'F-MR39 runtime oracle drift'
git show ${FMR39}:$FMR39_TEST > "$BUILD/test_fci45_runtime.f90"

RFLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
STRICT=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
 tests/fsi/fsi04_real_headcalc_stubs.f90
 src/runtime/mod_a23bu_worker_execution_context.f90
 src/transaction/mod_transaction_reference.f90
 src/transaction/mod_fkt_temporal_indicator_history.f90
 src/runtime/mod_canonical_contracts.f90
 src/runtime/mod_canonical_interval_runtime.f90
 src/kernel/mod_kernel_transactions.f90
 src/kernel/mod_kernel_committed_persistence.f90
 src/runtime/mod_fmr_runtime_core.f90
 src/runtime/mod_fmr_checkpoint_orchestrator.f90
 src/runtime/mod_fmr_accepted_commit_receipt.f90
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
 src/process/mod_soil_temperature_contract.f90
 src/process/mod_restricted_soil_temperature.f90
 src/runtime/mod_fmr_serialized_reference_backend.f90
 src/runtime/mod_fmr_serialized_multiswap_runtime.f90
 src/runtime/mod_fmr_restart_state_contract.f90
 src/runtime/mod_fmr_committed_restart.f90
 tests/fmr/mod_fmr04_fixed_top_provider.f90
)
for opt in 0 2; do
 OUT="$BUILD/o$opt"; objects=()
 for src in "${MODULE_SRC[@]}"; do
   obj="$OUT/$(basename "${src%.*}").o"; flags=("${RFLAGS[@]}")
   case "$src" in src/process/mod_soil_temperature_contract.f90|src/process/mod_restricted_soil_temperature.f90) flags=("${STRICT[@]}");; esac
   gfortran "${flags[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"; objects+=("$obj")
 done
 gfortran "${RFLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/test_fci45_runtime.f90" -o "$OUT/runtime.o"
 gfortran -O"$opt" "${objects[@]}" "$OUT/runtime.o" -o "$OUT/runtime"
 "$OUT/runtime" > "$OUT/runtime.txt" 2>&1 || { cat "$OUT/runtime.txt" >&2; fail "runtime O$opt"; }
 "$OUT/runtime" > "$OUT/runtime-repeat.txt" 2>&1 || fail "runtime repeat O$opt"
 cmp "$OUT/runtime.txt" "$OUT/runtime-repeat.txt" || fail "repeat nondeterminism O$opt"
 for marker in FMR39_ENABLED_WATER_THERMAL_ATOMIC_COMMIT=PASS FMR39_WATER_MASS_AUTHORITY_WITH_THERMAL_ACTIVE=PASS FMR39_THERMAL_FAILURE_ROLLS_BACK_WATER_AND_TEMPERATURE=PASS FMR39_RETRY_FROM_SAME_COMMITTED_STATE=PASS FMR39_SPLIT_RESTART_WATER_THERMAL_IDENTITY=PASS FMR39_RESTART_USES_EXISTING_POLYMORPHIC_PHYSICAL_STATE=PASS FMR39_MIXED_ENABLED_DISABLED_MULTISWAP_ISOLATION=PASS FMR39_INACTIVE_COLUMN_NO_THERMAL_PHYSICAL_STATE=PASS; do grep -Fq "$marker" "$OUT/runtime.txt" || fail "missing $marker O$opt"; done
 gfortran "${RFLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/test_fmr19_process_restart.f90 -o "$OUT/fmr19.o"
 gfortran -O"$opt" "${objects[@]}" "$OUT/fmr19.o" -o "$OUT/fmr19"
 "$OUT/fmr19" > "$OUT/fmr19.txt" 2>&1 || { cat "$OUT/fmr19.txt" >&2; fail "FMR19 O$opt"; }
 grep -Fq 'FMR19_CONTINUOUS_VS_RESTARTED_ENDPOINT_IDENTITY=PASS' "$OUT/fmr19.txt" || fail "FMR19 preservation O$opt"
 echo "FCI45_DISABLED_PATH_FMR19_PRESERVATION_O${opt}=PASS"
done
cmp "$BUILD/o0/runtime.txt" "$BUILD/o2/runtime.txt" || fail 'runtime O0/O2 drift'
cmp "$BUILD/o0/fmr19.txt" "$BUILD/o2/fmr19.txt" || fail 'FMR19 O0/O2 drift'
ACTUAL_SHA="$(sha256sum "$BUILD/o0/runtime.txt" | awk '{print $1}')"
[[ "$ACTUAL_SHA" == "$EXPECTED_OUTPUT_SHA256" ]] || fail "F-MR39 runtime oracle output drift $ACTUAL_SHA"
echo "FCI45_FMR39_RUNTIME_OUTPUT_SHA256=$ACTUAL_SHA"
echo 'FCI45_REPEATED_RUN_AND_O0_O2_DETERMINISM=PASS'

# Replay exact independent scientific authority as a separate check.
git worktree add --detach "$BUILD/fvq58" "$FVQ58" >/dev/null
( cd "$BUILD/fvq58" && bash tests/fvq/run_fvq58_restricted_soil_temperature_requalification.sh ) > "$BUILD/fvq58.txt" 2>&1 || { cat "$BUILD/fvq58.txt" >&2; fail 'F-VQ58 replay'; }
grep -Fq 'FVQ58_GATE=PASS' "$BUILD/fvq58.txt" || fail 'F-VQ58 gate marker missing'
echo 'FCI45_FVQ58_EXACT_SCIENTIFIC_AUTHORITY_REPLAY=PASS'

echo 'FCI45_PARALLEL_THROUGHPUT_CLAIM=NOT_MADE'
echo 'FCI45_SNOW_PLUS_THERMAL_PROFILE=NOT_ADMITTED'
echo 'FCI45_FROST_LATENT_HEAT=NOT_ADMITTED'
echo 'FCI45_PRODUCTION_SWAP_MODFLOW_ADMISSION=NOT_MADE'
echo 'FCI45_NUMERIC_APPLICATION_ACCURACY_POLICY=NOT_SET'
echo 'FCI45_RB1_REOPENED=NO'
echo 'FCI45_CANONICAL_ADMISSION_GATE=PASS'
