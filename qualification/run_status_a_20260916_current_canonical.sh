#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CANON='50346642bd565f79134ea17d5462e544b354998c'
CANON_TREE='3b085d7dea3d3f3fce42ad9d8f259a8350205846'
POST_GC28='3baf2aa135e3bf257942d9e6c5928990c2d1b2e1'
PE11_QUALIFIED_CANON='bf0fb81daf0f0fee53566a426886eaa0d0ad2832'
PE11_CLOSE='00d735939cb4a8da8b027b20b7dd25725cd73526'
FGC28_CLOSE='4c545af6f212fa4e95a27b9444ab3b01c277ff0b'
FVQ65='b1fd9e15a22d4dd68997ec38c074ce343eec0a70'
FVQ71='f2f410bb74ef40c23fcc16048bb54f9301b989db'
FKT15='48336cb7f14e9246b03c23e549fe7354a93f9e6b'
VQ73='ea40e2d850aa9b4b23b25ba6b4a63ffd39811001'
VQ74='60c121a0993993bd79fb30ddfd54e2a9d14f042e'
SNOW_VQ='25d83778dcade34225b4630059fd43142f95193d'

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-status-a-20260916-${GITHUB_RUN_ID:-local}-$$"
rm -rf "$BUILD"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
fail(){ echo "STATUS_A_20260916_FAIL $*" >&2; exit 190; }

compile_manifest() {
  local manifest="$1" out="$2" opt="$3"
  STATUS_A_OBJECTS=()
  mkdir -p "$out"
  while IFS= read -r source; do
    [[ -n "$source" ]] || continue
    local key obj
    key="$(printf '%s' "$source" | sha256sum | cut -c1-16)"
    obj="$out/$key.o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$source" -o "$obj"
    STATUS_A_OBJECTS+=("$obj")
  done < "$manifest"
}

# ---------------------------------------------------------------------------
# A. Exact release boundary, zero production/reference mutation in this workunit.
# ---------------------------------------------------------------------------
LIVE="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$LIVE" == "$CANON" ]] || fail "live canonical drift expected=$CANON actual=$LIVE"
[[ "$(git rev-parse "$CANON^{tree}")" == "$CANON_TREE" ]] || fail 'canonical tree drift'
git merge-base --is-ancestor "$CANON" HEAD || fail 'qualification head is not descended from exact canonical'
git diff --quiet "$CANON"..HEAD -- src reference || fail 'qualification workunit changes production/reference source'
echo 'STATUS_A_REL_001_EXACT_CANONICAL_AND_ZERO_PRODUCTION_DELTA=PASS'

for c in "$PE11_CLOSE" "$FGC28_CLOSE" "$FVQ65" "$FVQ71" "$FKT15" "$VQ73" "$VQ74" "$SNOW_VQ"; do
  git cat-file -e "$c^{commit}" || fail "missing immutable authority $c"
done
echo 'STATUS_A_IMMUTABLE_AUTHORITIES_PRESENT=PASS'

# Since the post-F-GC28 boundary, the only production delta is the admitted
# WOFOST81 PP03 runtime pair. This protects inherited groundwater, transaction,
# restart, drainage, Snow and PE11 evidence from silent dependency drift.
actual_delta="$(git diff --name-only "$POST_GC28".."$CANON" -- src reference | sort)"
expected_delta="$(printf '%s\n' \
  'src/runtime/mod_fmr_wofost81_crop_event_lifecycle.f90' \
  'src/runtime/mod_fmr_wofost81_crop_transaction.f90' | sort)"
[[ "$actual_delta" == "$expected_delta" ]] || {
  printf 'unexpected post-GC28 production/reference delta:\n%s\n' "$actual_delta" >&2
  fail 'post-GC28 dependency surface changed'
}
echo 'STATUS_A_POST_GC28_ONLY_WOFOST81_PP03_PRODUCTION_DELTA=PASS'

# F-GC28 recorded exact admitted groundwater production blobs. Verify those
# immutable locks directly against this release head rather than rerunning an
# unchanged scientific qualification.
python3 - "$FGC28_CLOSE" <<'PY'
import json, subprocess, sys
commit=sys.argv[1]
data=json.loads(subprocess.check_output(
    ['git','show',f'{commit}:integration/f-gc/F-GC28_CLOSEOUT.json'], text=True))
assert data['verdict']=='CLOSED_CANONICAL_ADMITTED'
assert data['qualify']['verdict']=='INDEPENDENTLY_QUALIFIED_GROUNDWATER_COUPLING_V1_COMPLETION_AUDIT'
for path, expected in data['admitted_production_blobs'].items():
    actual=subprocess.check_output(['git','rev-parse',f'HEAD:{path}'], text=True).strip()
    assert actual==expected, (path, expected, actual)
print('STATUS_A_GROUNDWATER_V1_ADMITTED_BLOBS_EXACT=PASS')
PY

# F-PE11 was qualified on PE11_QUALIFIED_CANON and its formal closeout already
# reconciles the later Snow metadata-only delta. Recheck the decisive condition.
git diff --quiet "$PE11_QUALIFIED_CANON".."$CANON" -- src reference || fail 'F-PE11 post-qualification production/reference drift'
python3 - "$PE11_CLOSE" "$CANON" <<'PY'
import json, subprocess, sys
commit,canon=sys.argv[1:]
data=json.loads(subprocess.check_output(
    ['git','show',f'{commit}:integration/f-pe/F-PE11_CLOSE_CHECKPOINT.json'], text=True))
assert data['canonical']['post_close_live_head']==canon
p=data['canonical']['post_close_delta_from_qualified_head']
assert p['production_source_changed'] is False
assert p['reference_source_changed'] is False
assert p['FPE11_relevant_dependency_changed'] is False
assert p['requalification_required'] is False
print('STATUS_A_FPE11_CURRENT_HEAD_PRESERVATION_INHERITED=PASS')
PY

# Snow closed on the exact release head. Lock the three production sources that
# its current-canonical gate qualified. Do not rerun Snow science blindly.
[[ "$(git rev-parse HEAD:src/process/mod_snow_process.f90)" == '54702d71b4c84dce2842813549bd14c57301a383' ]] || fail 'Snow process blob drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == '9b4d6f7d6b63d66fe2e46eb9c46d70d08e32db13' ]] || fail 'Snow serialized backend blob drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_multiswap_runtime.f90)" == '1aa2454048d0e480becaee34f596f20f1a7bd66e' ]] || fail 'Snow serialized MultiSWAP blob drift'
echo 'STATUS_A_SNOW_CURRENT_CANONICAL_SOURCE_LOCKS_EXACT=PASS'

# Permanent testbank authorities remain immutable historical authorities. Their
# old canonical pins are deliberately not rewritten for this new release cut.
[[ "$(git rev-parse HEAD:testbank/runners/run_ftb11_current_source_replays.sh)" == 'fbfd57f20feae026feeea821043787b83ed35a43' ]] || fail 'F-TB11 runner authority drift'
[[ "$(git rev-parse HEAD:testbank/runners/run_ftb12_drainage_v1_permanent_preservation.sh)" == '99c7ad975b137bad5b46df48b3916881350b6bb1' ]] || fail 'F-TB12 runner authority drift'
echo 'STATUS_A_PERMANENT_TESTBANK_AUTHORITIES_IMMUTABLE=PASS'

# ---------------------------------------------------------------------------
# B. Independent transaction and mass fail-closed oracle on current production.
# ---------------------------------------------------------------------------
git show "$FVQ65:tests/fvq/mod_fvq65_mass_attack_support.f90" > "$BUILD/mod_fvq65_mass_attack_support.f90"
git show "$FVQ65:tests/fvq/test_fvq65_mass_fail_closed.f90" > "$BUILD/test_fvq65_mass_fail_closed.f90"
for opt in 0 2; do
  out="$BUILD/mass-o$opt"; mkdir -p "$out"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c src/transaction/mod_transaction_reference.f90 -o "$out/tx.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$BUILD/mod_fvq65_mass_attack_support.f90" -o "$out/support.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$BUILD/test_fvq65_mass_fail_closed.f90" -o "$out/test.o"
  gfortran -O"$opt" "$out/tx.o" "$out/support.o" "$out/test.o" -o "$out/test"
  "$out/test" > "$out/output.txt" 2>&1 || { cat "$out/output.txt" >&2; fail "mass attack O$opt"; }
  for marker in \
    'FVQ65_EXTERNAL_REJECTION_MATRIX_CASES=PASS:14' \
    'FVQ65_CERTIFICATE_REJECTION_MATRIX_CASES=PASS:9' \
    'FVQ65_COMPLETE_EXTERNAL_ACCEPTS=PASS' \
    'FVQ65_COMPLETE_CERTIFICATE_ACCEPTS=PASS' \
    'FVQ65_EXTERNAL_RETRY_RECOVERY_FROM_COMMITTED_ORIGIN=PASS' \
    'FVQ65_CERTIFICATE_RETRY_RECOVERY_FROM_COMMITTED_ORIGIN=PASS' \
    'FVQ65_INDEPENDENT_MASS_COMPLETENESS_ATTACK_MATRIX=PASS'; do
    grep -Fq "$marker" "$out/output.txt" || { cat "$out/output.txt" >&2; fail "mass O$opt missing $marker"; }
  done
done
cmp -s "$BUILD/mass-o0/output.txt" "$BUILD/mass-o2/output.txt" || fail 'mass attack O0/O2 semantic drift'
echo 'STATUS_A_TRANSACTION_MASS_CURRENT_O0_O2=PASS'

# ---------------------------------------------------------------------------
# C. Corrected-reference solver-service composition on current production.
#    Reuse the immutable F-KT15 fixture, but resolve the current module closure.
# ---------------------------------------------------------------------------
git show "$FKT15:tests/fkt/fkt15_reference_model_stubs.f90" > "$BUILD/fkt15_stubs.f90"
git show "$FKT15:tests/fkt/test_fkt15_reference_model_transport.f90" > "$BUILD/fkt15_test.f90"
python3 qualification/status_a_dependency_closure.py \
  --out "$BUILD/reference.manifest" \
  --test "$BUILD/fkt15_test.f90" \
  --support "$BUILD/fkt15_stubs.f90" \
  --force "$BUILD/fkt15_stubs.f90"
for opt in 0 2; do
  out="$BUILD/reference-o$opt"
  compile_manifest "$BUILD/reference.manifest" "$out" "$opt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$BUILD/fkt15_test.f90" -o "$out/test.o"
  gfortran -O"$opt" "${STATUS_A_OBJECTS[@]}" "$out/test.o" -o "$out/test"
  "$out/test" > "$out/output.txt" 2>&1 || { cat "$out/output.txt" >&2; fail "reference composition O$opt"; }
  grep -Fq 'FKT15_REFERENCE_MODEL_TRANSPORT_GATE=PASS' "$out/output.txt" || fail "reference marker O$opt"
done
cmp -s "$BUILD/reference-o0/output.txt" "$BUILD/reference-o2/output.txt" || fail 'reference O0/O2 semantic drift'
echo 'STATUS_A_REFERENCE_LEGACY_CURRENT_O0_O2=PASS'

# ---------------------------------------------------------------------------
# D. Current Restart v1 plus serialized MultiSWAP continuation.
#    Parallel real-physics execution is intentionally outside this denominator.
# ---------------------------------------------------------------------------
python3 qualification/status_a_dependency_closure.py \
  --out "$BUILD/restart.manifest" \
  --test tests/fmr/test_fmr19_process_restart.f90 \
  --support tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --support tests/fmr/mod_fmr04_fixed_top_provider.f90 \
  --support tests/fpm/mod_fpm08d7_optional_state_compat.f90 \
  --force tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --force src/legacy/b1_10_port/headcalc.f90
for opt in 0 2; do
  out="$BUILD/restart-o$opt"
  compile_manifest "$BUILD/restart.manifest" "$out" "$opt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c tests/fmr/test_fmr19_process_restart.f90 -o "$out/test.o"
  gfortran -O"$opt" "${STATUS_A_OBJECTS[@]}" "$out/test.o" -o "$out/test"
  "$out/test" > "$out/output.txt" 2>&1 || { cat "$out/output.txt" >&2; fail "restart O$opt"; }
  grep -Fq 'FMR19_EXACT_INTERVAL_MASS_CONTINUATION=PASS' "$out/output.txt" || fail "restart mass O$opt"
  grep -Fq 'FMR19_CONTINUOUS_VS_RESTARTED_ENDPOINT_IDENTITY=PASS' "$out/output.txt" || fail "restart endpoint O$opt"
  grep -Fq 'FMR19_REAL_HEADCALC_PROCESS_RESTART_TEST PASS' "$out/output.txt" || fail "restart final O$opt"
done
cmp -s "$BUILD/restart-o0/output.txt" "$BUILD/restart-o2/output.txt" || fail 'restart O0/O2 semantic drift'
echo 'STATUS_A_RESTART_SERIALIZED_MULTISWAP_CURRENT_O0_O2=PASS'
echo 'STATUS_A_PARALLEL_REAL_PHYSICS_NOT_IN_DENOMINATOR=PASS_EXCLUDED'

# ---------------------------------------------------------------------------
# E. Atomic accepted surface publication and rejected-trial isolation.
# ---------------------------------------------------------------------------
git show "$FVQ71:tests/fvq/test_fvq71_atomic_surface_publication_independent.f90" > "$BUILD/fvq71_test.f90"
git show "$FVQ71:tests/fvq/fvq71_forbidden_split_surface_publication.f90" > "$BUILD/fvq71_forbidden.f90"
python3 qualification/status_a_dependency_closure.py \
  --out "$BUILD/publication.manifest" \
  --test "$BUILD/fvq71_test.f90" \
  --support tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --support tests/fmr/mod_fmr04_fixed_top_provider.f90 \
  --support tests/fpm/mod_fpm08d7_optional_state_compat.f90 \
  --force tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --force src/legacy/b1_10_port/headcalc.f90
for opt in 0 2; do
  out="$BUILD/publication-o$opt"
  compile_manifest "$BUILD/publication.manifest" "$out" "$opt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$BUILD/fvq71_test.f90" -o "$out/test.o"
  gfortran -O"$opt" "${STATUS_A_OBJECTS[@]}" "$out/test.o" -o "$out/test"
  "$out/test" > "$out/output.txt" 2>&1 || { cat "$out/output.txt" >&2; fail "publication O$opt"; }
  for marker in \
    'FVQ71_FVQ69_CLASS_STALE_ALTERNATE=PASS_CLOSED' \
    'FVQ71_CROSS_LINEAGE_PRECOMMIT=PASS_CLOSED' \
    'FVQ71_NO_MASS_REGRESSION=PASS' \
    'FVQ71_INDEPENDENT_ORACLE=PASS'; do
    grep -Fq "$marker" "$out/output.txt" || { cat "$out/output.txt" >&2; fail "publication O$opt missing $marker"; }
  done
  if gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$BUILD/fvq71_forbidden.f90" -o "$out/forbidden.o" > "$out/forbidden.log" 2>&1; then
    fail "forbidden split publication API compiled at O$opt"
  fi
done
cmp -s "$BUILD/publication-o0/output.txt" "$BUILD/publication-o2/output.txt" || fail 'publication O0/O2 semantic drift'
echo 'STATUS_A_ACCEPTED_PUBLICATION_REJECT_ISOLATION_CURRENT_O0_O2=PASS'

# ---------------------------------------------------------------------------
# F. Drainage v1 current-head replay with immutable independent VQ73/VQ74 tests.
#    Historical F-TB12 pinning is not altered; only the compile closure adapts.
# ---------------------------------------------------------------------------
git show "$VQ73:tests/fvq/test_fvq73_fpm14_drainage_response_independent.f90" > "$BUILD/vq73.f90"
git show "$VQ74:tests/fvq/test_fvq74_drainage_cross_cutting_independent.f90" > "$BUILD/vq74.f90"
[[ "$(git hash-object "$BUILD/vq73.f90")" == 'e7008eda5f29ee2e401cb3eb8a1b1523da3bc25a' ]] || fail 'VQ73 oracle blob drift'
[[ "$(git hash-object "$BUILD/vq74.f90")" == 'dabe53d0714abee8e87b2e90f89c2eed169506e0' ]] || fail 'VQ74 oracle blob drift'
python3 qualification/status_a_dependency_closure.py \
  --out "$BUILD/drainage.manifest" \
  --test "$BUILD/vq73.f90" \
  --test "$BUILD/vq74.f90" \
  --support tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --support tests/fmr/mod_fmr04_fixed_top_provider.f90 \
  --support tests/fpm/mod_fpm08d7_optional_state_compat.f90 \
  --force tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --force src/legacy/b1_10_port/headcalc.f90
for opt in 0 2; do
  out="$BUILD/drainage-o$opt"
  compile_manifest "$BUILD/drainage.manifest" "$out" "$opt"
  for n in 73 74; do
    gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$BUILD/vq${n}.f90" -o "$out/vq${n}.o"
    gfortran -O"$opt" "${STATUS_A_OBJECTS[@]}" "$out/vq${n}.o" -o "$out/vq${n}"
    "$out/vq${n}" > "$out/vq${n}.out" 2>&1 || { cat "$out/vq${n}.out" >&2; fail "drainage VQ$n O$opt"; }
  done
  for marker in \
    'FVQ73_TWO_LEVEL_BINDING_SEPARATION_AND_TANGENT=PASS' \
    'FVQ73_AGGREGATE_DERIVED_VIEW_NOT_TRANSFER=PASS' \
    'FVQ73_TWO_LEVEL_RUNTIME_HARD_MASS_AND_SINGLE_BOOKING=PASS' \
    'FVQ73_GENERIC_NONCALENDAR_INTERVAL=PASS' \
    'FVQ73_INVALID_SECOND_LEVEL_FAIL_CLOSED_ATOMIC=PASS' \
    'FVQ73_FPM14_DRAINAGE_RESPONSE_INDEPENDENT_RUNTIME=PASS'; do
    grep -Fxq "$marker" "$out/vq73.out" || { cat "$out/vq73.out" >&2; fail "VQ73 O$opt missing $marker"; }
  done
  for marker in \
    'FVQ74_MULTISWAP_ACTIVE_PRECOMPUTED_ISOLATION=PASS' \
    'FVQ74_MULTISWAP_ORDER_INDEPENDENCE=PASS' \
    'FVQ74_ACCEPTED_RUNTIME_DIAGNOSTICS=PASS' \
    'FVQ74_RESTART_NO_ADDITIONAL_DRAINAGE_STATE=PASS' \
    'FVQ74_RESTART_CONTINUATION_EQUIVALENCE=PASS' \
    'FVQ74_REJECTED_RUNTIME_DIAGNOSTICS=PASS' \
    'FVQ74_REJECTED_RUNTIME_ATOMICITY=PASS' \
    'FVQ74_DRAINAGE_CROSS_CUTTING_INDEPENDENT=PASS'; do
    grep -Fxq "$marker" "$out/vq74.out" || { cat "$out/vq74.out" >&2; fail "VQ74 O$opt missing $marker"; }
  done
done
cmp -s "$BUILD/drainage-o0/vq73.out" "$BUILD/drainage-o2/vq73.out" || fail 'VQ73 drainage O0/O2 semantic drift'
cmp -s "$BUILD/drainage-o0/vq74.out" "$BUILD/drainage-o2/vq74.out" || fail 'VQ74 drainage O0/O2 semantic drift'
echo 'STATUS_A_DRAINAGE_CURRENT_O0_O2_RUNTIME_MASS_RESTART_MULTISWAP=PASS'

# ---------------------------------------------------------------------------
# G. WOFOST81 is the only production source delta since post-F-GC28, so replay
# its full admitted current contract instead of inheriting it solely by hash.
# ---------------------------------------------------------------------------
bash tests/fwof/pp03/run_fwof_pp03_runtime_activation_gate.sh
bash tests/fwof/pp03/run_fwof38_fwof39_current_contract_preservation.sh
echo 'STATUS_A_WOFOST81_CURRENT_FULL_ADMITTED_SCOPE_REPLAY=PASS'

# ---------------------------------------------------------------------------
# H. Exit race check and qualification worktree integrity.
# ---------------------------------------------------------------------------
LIVE_END="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$LIVE_END" == "$CANON" ]] || fail "canonical moved during qualification expected=$CANON actual=$LIVE_END"
git diff --quiet "$CANON"..HEAD -- src reference || fail 'qualification branch acquired production/reference mutation'
git diff --check "$CANON"..HEAD

echo "STATUS_A_QUALIFIED_CANONICAL_HEAD=$CANON"
echo "STATUS_A_QUALIFIED_CANONICAL_TREE=$CANON_TREE"
echo 'STATUS_A_NO_B_C_D_RELEASE_DENOMINATOR_PRECONDITION=PASS_RECONCILED'
echo 'STATUS_A_20260916_CURRENT_CANONICAL_RELEASE_QUALIFICATION=PASS'
