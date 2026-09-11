#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

OLD_CANONICAL=e342f4f9c9d45e2ec2d23a6be6032cc0498d98e2
PROMOTED=14db7be4827e73650da18d494af5cf190e687490
ADMISSION=2decde7d4d2ac3cee040d63b25ff7a97ca6db63e
PROMOTED_TREE=10e5f8fc1038a77bb0fad88249bf8d524858f6a2
REFERENCE_TREE=9d08625217d7c0a7385df9da6a04183bcd9cb9e6
FMR39=87b553094b66980006b69f5ba8b53d70ccd0a8e0
FVQ58=5e81e14ad613cff7a72fc3f9cddcebc6696290d7
BACKEND=src/runtime/mod_fmr_serialized_reference_backend.f90
RESTART=src/runtime/mod_fmr_restart_state_contract.f90
BACKEND_BLOB=07877429f94ccf07c353fa5f8ba969c341ad88dd
RESTART_BLOB=bb2c37efce37a73441181f14d15847c652ab45ea
FMR39_TEST=tests/fmr/test_fmr39_soil_temperature_runtime_composition.f90
FMR39_TEST_BLOB=00a0d30fd4f1f3ef3888dbc03cf71d41770c4fab
FCI45_STATUS=integration/f-ci/F-CI45_STATUS.json
FCI45_STATUS_BLOB=8ed79e93798a8a92f8b4540c6bafa1fba5bde34b
FCI45_EVIDENCE=integration/f-ci/F-CI45_EVIDENCE.json
FCI45_EVIDENCE_BLOB=b9ce85c47141fe1f95dc1b485a3d592e19f52fd8
FCI45_AUDIT=integration/f-ci/F-CI45_ARCHITECTURE_AUDIT.json
FCI45_AUDIT_BLOB=aacd6aa010b0f8711b78d5525685fb84c55cefcf
FCI45_CONTRACT=integration/f-ci/F-CI45_WORK_UNIT_CONTRACT.json
FCI45_CONTRACT_BLOB=7e529ecaebc3fa53ef00f8e89f35e89924fcb1ff
APP_CONTRACT=src/runtime/mod_coupling_application_accuracy_contract.f90
APP_CONTRACT_BLOB=c07d573d21e7d013ab962c0a9d28102ab7b5cdfc
FCI44P_STATUS=integration/f-ci/F-CI44P_STATUS.json
FCI44P_STATUS_BLOB=b29cb2f8b94d6d52614650a513b913f2b20b6a50
EXPECTED_RUNTIME_SHA=cb08b8dc528f9a1dfc11db9ffffad5598fa9c4584b12feada1d129e47a236942
BUILD="${RUNNER_TEMP:-/tmp}/fci45p-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"; mkdir -p "$BUILD/o0" "$BUILD/o2" "$BUILD/fci44-o0" "$BUILD/fci44-o2"
trap 'git worktree remove --force "$BUILD/fvq58" >/dev/null 2>&1 || true; rm -rf "$BUILD"' EXIT
fail(){ echo "FCI45P_GATE_FAIL $*" >&2; exit 45; }
need_commit(){ git cat-file -e "$1^{commit}" 2>/dev/null || git fetch --no-tags origin "$1" >/dev/null 2>&1 || fail "cannot fetch $1"; }
for sha in "$OLD_CANONICAL" "$PROMOTED" "$ADMISSION" "$FMR39" "$FVQ58"; do need_commit "$sha"; done

# Reconciliation applies only while the exact promoted F-CI45 postimage is current canonical.
git fetch --no-tags origin integration/f-ci-canonical >/dev/null 2>&1 || fail 'cannot fetch canonical'
CURRENT="$(git rev-parse origin/integration/f-ci-canonical)"
[[ "$CURRENT" == "$PROMOTED" ]] || fail "canonical moved during F-CI45P: expected $PROMOTED got $CURRENT"
[[ "$(git rev-parse ${PROMOTED}^{tree})" == "$PROMOTED_TREE" ]] || fail 'promoted tree drift'
[[ "$(git rev-parse ${PROMOTED}:reference)" == "$REFERENCE_TREE" ]] || fail 'reference tree drift'
echo 'FCI45P_CURRENT_CANONICAL_PIN=PASS'

# Promotion must be the exact true two-parent merge authorized by the green status head.
read -r merge p1 p2 extra <<<"$(git rev-list --parents -n1 "$PROMOTED")"
[[ "$merge" == "$PROMOTED" && "$p1" == "$OLD_CANONICAL" && "$p2" == "$ADMISSION" && -z "${extra:-}" ]] || \
  fail "invalid promotion parents: $merge $p1 $p2 ${extra:-}"
[[ "$(git rev-parse ${ADMISSION}^{tree})" == "$PROMOTED_TREE" ]] || fail 'admission/promoted tree mismatch'
echo 'FCI45P_TRUE_TWO_PARENT_PROMOTION=PASS'
echo 'FCI45P_ADMISSION_TREE_EQUALS_PROMOTED_TREE=PASS'

# Promoted production delta is exactly the two immutable F-MR39 runtime blobs.
mapfile -t src_delta < <(git diff --name-only "$OLD_CANONICAL".."$PROMOTED" -- src | sort)
printf '%s\n' "${src_delta[@]}" > "$BUILD/src-delta"
printf '%s\n' "$BACKEND" "$RESTART" | sort > "$BUILD/src-expected"
cmp -s "$BUILD/src-delta" "$BUILD/src-expected" || { cat "$BUILD/src-delta" >&2; fail 'unexpected promoted source delta'; }
[[ "$(git rev-parse ${PROMOTED}:$BACKEND)" == "$BACKEND_BLOB" ]] || fail 'promoted backend blob drift'
[[ "$(git rev-parse ${PROMOTED}:$RESTART)" == "$RESTART_BLOB" ]] || fail 'promoted restart blob drift'
[[ "$(git rev-parse ${FMR39}:$BACKEND)" == "$BACKEND_BLOB" ]] || fail 'F-MR39 backend authority drift'
[[ "$(git rev-parse ${FMR39}:$RESTART)" == "$RESTART_BLOB" ]] || fail 'F-MR39 restart authority drift'
git diff --quiet "$PROMOTED"..HEAD -- src || fail 'F-CI45P changed production source'
git diff --quiet "$PROMOTED"..HEAD -- reference || fail 'F-CI45P changed frozen reference tree'
echo 'FCI45P_EXACT_TWO_BLOB_PROMOTED_SOURCE_SCOPE=PASS'
echo 'FCI45P_NO_PRODUCTION_OR_REFERENCE_DELTA=PASS'

# F-CI45 admission authority must be present byte-identically in the promoted postimage.
for spec in \
 "$FCI45_STATUS:$FCI45_STATUS_BLOB" \
 "$FCI45_EVIDENCE:$FCI45_EVIDENCE_BLOB" \
 "$FCI45_AUDIT:$FCI45_AUDIT_BLOB" \
 "$FCI45_CONTRACT:$FCI45_CONTRACT_BLOB"; do
 path="${spec%%:*}"; blob="${spec##*:}"
 [[ "$(git rev-parse ${PROMOTED}:$path)" == "$blob" ]] || fail "F-CI45 metadata drift $path"
done
git show ${PROMOTED}:$FCI45_STATUS | grep -Fq 'QUALIFIED_FMR39_RESTRICTED_SOIL_TEMPERATURE_RUNTIME_FOR_CURRENT_CANONICAL_ADMISSION' || fail 'F-CI45 decision missing'
git show ${PROMOTED}:$FCI45_EVIDENCE | grep -Fq "$EXPECTED_RUNTIME_SHA" || fail 'F-CI45 runtime fingerprint evidence missing'
echo 'FCI45P_FCI45_AUTHORITY_PRESERVED=PASS'

# Previous coupling/application authority remains in the promoted tree.
[[ "$(git rev-parse ${PROMOTED}:$APP_CONTRACT)" == "$APP_CONTRACT_BLOB" ]] || fail 'F-CI44 application contract drift'
[[ "$(git rev-parse ${PROMOTED}:$FCI44P_STATUS)" == "$FCI44P_STATUS_BLOB" ]] || fail 'F-CI44P status drift'
echo 'FCI45P_FCI44P_AUTHORITY_PRESERVED=PASS'

# F-CI45P itself is governance/test-only.
mapfile -t branch_delta < <(git diff --name-only "$PROMOTED"..HEAD | sort)
for path in "${branch_delta[@]}"; do
  case "$path" in
    tests/fci/run_fci45p_current_canonical_postimage_reconciliation.sh|\
    .github/workflows/fci45p-current-canonical-postimage-reconciliation.yml|\
    integration/f-ci/F-CI45P_*.json) ;;
    *) fail "unexpected F-CI45P branch delta: $path" ;;
  esac
done
echo 'FCI45P_RECONCILIATION_SCOPE=PASS'

python3 - <<'PY'
import json
from pathlib import Path
p=Path('integration/f-ci/F-CI45P_ARCHITECTURE_RECONCILIATION.json')
a=json.loads(p.read_text())
assert a['promoted_canonical_head']=='14db7be4827e73650da18d494af5cf190e687490'
assert a['previous_canonical_head']=='e342f4f9c9d45e2ec2d23a6be6032cc0498d98e2'
assert a['admission_authority']=='2decde7d4d2ac3cee040d63b25ff7a97ca6db63e'
inv=a['invariants']
assert len(inv)==30
assert sorted(x['id'] for x in inv)==list(range(1,31))
assert all(x['status'] in {'QUALIFIED_POSTIMAGE','PRESERVED','BOUNDED_NONCLAIM'} for x in inv)
print('FCI45P_ALL_30_ARCHITECTURE_INVARIANTS_RECONCILED=PASS')
PY

git diff --check "$PROMOTED" -- tests/fci integration/f-ci .github/workflows || fail 'diff check failed'
echo 'FCI45P_DIFF_CHECK=PASS'

# Replay the exact F-MR39 runtime oracle against the promoted canonical postimage.
[[ "$(git rev-parse ${FMR39}:$FMR39_TEST)" == "$FMR39_TEST_BLOB" ]] || fail 'F-MR39 runtime oracle drift'
git show ${FMR39}:$FMR39_TEST > "$BUILD/test_fci45p_runtime.f90"
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
 gfortran "${RFLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/test_fci45p_runtime.f90" -o "$OUT/runtime.o"
 gfortran -O"$opt" "${objects[@]}" "$OUT/runtime.o" -o "$OUT/runtime"
 "$OUT/runtime" > "$OUT/runtime.txt" 2>&1 || { cat "$OUT/runtime.txt" >&2; fail "runtime O$opt"; }
 "$OUT/runtime" > "$OUT/runtime-repeat.txt" 2>&1 || fail "runtime repeat O$opt"
 cmp "$OUT/runtime.txt" "$OUT/runtime-repeat.txt" || fail "runtime repeat nondeterminism O$opt"
 for marker in FMR39_ENABLED_WATER_THERMAL_ATOMIC_COMMIT=PASS FMR39_WATER_MASS_AUTHORITY_WITH_THERMAL_ACTIVE=PASS FMR39_THERMAL_FAILURE_ROLLS_BACK_WATER_AND_TEMPERATURE=PASS FMR39_RETRY_FROM_SAME_COMMITTED_STATE=PASS FMR39_SPLIT_RESTART_WATER_THERMAL_IDENTITY=PASS FMR39_MIXED_ENABLED_DISABLED_MULTISWAP_ISOLATION=PASS FMR39_INACTIVE_COLUMN_NO_THERMAL_PHYSICAL_STATE=PASS; do grep -Fq "$marker" "$OUT/runtime.txt" || fail "missing $marker O$opt"; done
 gfortran "${RFLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/test_fmr19_process_restart.f90 -o "$OUT/fmr19.o"
 gfortran -O"$opt" "${objects[@]}" "$OUT/fmr19.o" -o "$OUT/fmr19"
 "$OUT/fmr19" > "$OUT/fmr19.txt" 2>&1 || { cat "$OUT/fmr19.txt" >&2; fail "FMR19 O$opt"; }
 grep -Fq 'FMR19_CONTINUOUS_VS_RESTARTED_ENDPOINT_IDENTITY=PASS' "$OUT/fmr19.txt" || fail "FMR19 preservation O$opt"
 echo "FCI45P_DISABLED_PATH_FMR19_PRESERVATION_O${opt}=PASS"
done
cmp "$BUILD/o0/runtime.txt" "$BUILD/o2/runtime.txt" || fail 'runtime O0/O2 drift'
cmp "$BUILD/o0/fmr19.txt" "$BUILD/o2/fmr19.txt" || fail 'FMR19 O0/O2 drift'
ACTUAL_SHA="$(sha256sum "$BUILD/o0/runtime.txt" | awk '{print $1}')"
[[ "$ACTUAL_SHA" == "$EXPECTED_RUNTIME_SHA" ]] || fail "runtime fingerprint drift $ACTUAL_SHA"
echo "FCI45P_FMR39_RUNTIME_OUTPUT_SHA256=$ACTUAL_SHA"
echo 'FCI45P_RUNTIME_REPEATED_RUN_AND_O0_O2_DETERMINISM=PASS'

# Replay the exact F-VQ58 scientific authority independently.
git worktree add --detach "$BUILD/fvq58" "$FVQ58" >/dev/null
( cd "$BUILD/fvq58" && bash tests/fvq/run_fvq58_restricted_soil_temperature_requalification.sh ) > "$BUILD/fvq58.txt" 2>&1 || { cat "$BUILD/fvq58.txt" >&2; fail 'F-VQ58 replay'; }
grep -Fq 'FVQ58_GATE=PASS' "$BUILD/fvq58.txt" || fail 'F-VQ58 marker missing'
echo 'FCI45P_FVQ58_EXACT_SCIENTIFIC_AUTHORITY_REPLAY=PASS'

# Re-run the small F-CI44 application contract oracle on this promoted postimage.
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
compile_fci44(){
 local opt="$1" dir="$2"
 gfortran "${COMMON[@]}" "$opt" -J "$dir" -I "$dir" -c src/transaction/mod_transaction_reference.f90 -o "$dir/transaction.o"
 gfortran "${COMMON[@]}" "$opt" -J "$dir" -I "$dir" -c src/runtime/mod_canonical_contracts.f90 -o "$dir/contracts.o"
 gfortran "${COMMON[@]}" "$opt" -J "$dir" -I "$dir" -c "$APP_CONTRACT" -o "$dir/app.o"
 gfortran "${COMMON[@]}" "$opt" -J "$dir" -I "$dir" -c tests/fci/test_fci44_application_accuracy_contract_admission.f90 -o "$dir/test.o"
 gfortran "$opt" "$dir/transaction.o" "$dir/contracts.o" "$dir/app.o" "$dir/test.o" -o "$dir/test.exe"
 "$dir/test.exe" > "$dir/output.txt"; "$dir/test.exe" > "$dir/repeat.txt"; cmp "$dir/output.txt" "$dir/repeat.txt" || fail "F-CI44 repeat drift $opt"
}
compile_fci44 -O0 "$BUILD/fci44-o0"
compile_fci44 -O2 "$BUILD/fci44-o2"
cmp "$BUILD/fci44-o0/output.txt" "$BUILD/fci44-o2/output.txt" || fail 'F-CI44 O0/O2 drift'
grep -Fq 'FCI44_APPLICATION_ACCURACY_CONTRACT=PASS' "$BUILD/fci44-o0/output.txt" || fail 'F-CI44 oracle marker missing'
echo 'FCI45P_FCI44_CONTRACT_ORACLE_O0_O2=PASS'

echo 'FCI45P_PARALLEL_THROUGHPUT_CLAIM=NOT_MADE'
echo 'FCI45P_SNOW_PLUS_THERMAL_PROFILE=NOT_ADMITTED'
echo 'FCI45P_FROST_LATENT_HEAT=NOT_ADMITTED'
echo 'FCI45P_PRODUCTION_SWAP_MODFLOW_ADMISSION=NOT_MADE'
echo 'FCI45P_NUMERIC_APPLICATION_ACCURACY_POLICY=NOT_SET'
echo 'FCI45P_MASS_CONSERVATION_RELAXED=NO'
echo 'FCI45P_RB1_REOPENED=NO'
echo 'FCI45P_POSTIMAGE_RECONCILIATION_GATE=PASS'
