#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CANON='50346642bd565f79134ea17d5462e544b354998c'
CANON_TREE='3b085d7dea3d3f3fce42ad9d8f259a8350205846'
FTB11_RUNNER_BLOB='fbfd57f20feae026feeea821043787b83ed35a43'
FVQ73='ea40e2d850aa9b4b23b25ba6b4a63ffd39811001'
FVQ74='60c121a0993993bd79fb30ddfd54e2a9d14f042e'
VQ73_BLOB='e7008eda5f29ee2e401cb3eb8a1b1523da3bc25a'
VQ74_BLOB='dabe53d0714abee8e87b2e90f89c2eed169506e0'
FGC28_CLOSE='4c545af6f212fa4e95a27b9444ab3b01c277ff0b'
FPE11_CLOSE='00d735939cb4a8da8b027b20b7dd25725cd73526'

fail(){ echo "STATUS_A_CURRENT_CANONICAL_FAIL $*" >&2; exit 120; }

LIVE="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$LIVE" == "$CANON" ]] || fail "live canonical drift expected=$CANON actual=$LIVE"
[[ "$(git rev-parse "$CANON^{tree}")" == "$CANON_TREE" ]] || fail 'canonical tree drift'
git merge-base --is-ancestor "$CANON" HEAD || fail 'qualification branch is not descended from pinned canonical'
[[ -z "$(git diff --name-only "$CANON..HEAD" -- src reference)" ]] || fail 'qualification branch changes production/reference source'
echo 'STATUS_A_REL_001=PASS_EXACT_LIVE_CANONICAL_ZERO_PRODUCTION_REFERENCE_DELTA'

# All divergent immutable authority objects are fetched by the workflow. Verify
# the exact commits are locally available before the executable replay begins.
for c in "$FVQ73" "$FVQ74" "$FGC28_CLOSE" "$FPE11_CLOSE"; do
  git cat-file -e "$c^{commit}" || fail "missing immutable authority commit $c"
done

WT="${RUNNER_TEMP:-/tmp}/status-a-canonical-${GITHUB_RUN_ID:-local}-$$"
BUILD="${RUNNER_TEMP:-/tmp}/status-a-build-${GITHUB_RUN_ID:-local}-$$"
cleanup(){ git -C "$ROOT" worktree remove --force "$WT" >/dev/null 2>&1 || true; rm -rf "$WT" "$BUILD"; }
trap cleanup EXIT
rm -rf "$WT" "$BUILD"; mkdir -p "$BUILD"
git worktree add --detach "$WT" "$CANON" >/dev/null
cd "$WT"
[[ "$(git rev-parse HEAD)" == "$CANON" ]] || fail 'detached canonical worktree mismatch'

# ---------------------------------------------------------------------------
# 1. Current-source permanent core replay.
#    Reuse the exact F-TB11 runner already stored on current canonical, changing
#    only its historical worktree target to this declared Status-A head. The
#    original script bytes are reconstructed after reversing that one allowed
#    substitution.
# ---------------------------------------------------------------------------
FTB11='testbank/runners/run_ftb11_current_source_replays.sh'
[[ "$(git rev-parse "HEAD:$FTB11")" == "$FTB11_RUNNER_BLOB" ]] || fail 'F-TB11 replay runner blob drift'
GEN_FTB11='testbank/runners/.status_a_current_ftb11.sh'
python3 - "$FTB11" "$GEN_FTB11" "$CANON" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text()
out=Path(sys.argv[2]); canon=sys.argv[3]
old='CANON=379afd11e9a1d7fbef5ec74c9e05b0ec55884f4b\n'
new=f'CANON={canon}\n'
if src.count(old) != 1:
    raise SystemExit('STATUS_A_CURRENT_CANONICAL_FAIL unexpected F-TB11 CANON anchor')
adapted=src.replace(old,new,1)
if adapted.replace(new,old,1) != src:
    raise SystemExit('STATUS_A_CURRENT_CANONICAL_FAIL F-TB11 adaptation is not one-line reversible')
out.write_text(adapted)
PY
chmod +x "$GEN_FTB11"
bash "$GEN_FTB11" 2>&1 | tee "$BUILD/ftb11-current.log"
rm -f "$GEN_FTB11"
for marker in \
  'FTB11-TXN-001=PASS_QUALIFIED_FVQ65_CURRENT_SOURCE_ORACLE' \
  'FTB11-MASS-001=PASS' \
  'FTB11-RST-001=PASS_EXECUTABLE_CURRENT_SOURCE_REPLAY' \
  'FTB11-MSW-001=PASS_EXECUTABLE_CURRENT_SOURCE_REPLAY' \
  'FTB11-REJECT-001=PASS_FVQ71_PRECOMMIT_IMMUTABILITY' \
  'FTB11-ETPUB-001=PASS' \
  'FTB11_CURRENT_SOURCE_SEMANTIC_REPLAYS=PASS'; do
  grep -Fq "$marker" "$BUILD/ftb11-current.log" || fail "missing F-TB11 current marker: $marker"
done
echo 'STATUS_A_CORE_CURRENT_SOURCE_REPLAY=PASS'

# ---------------------------------------------------------------------------
# 2. Drainage current-head scientific/numerical replay.
#    The independent VQ73/VQ74 test programs are immutable. They are rebuilt
#    unchanged against the exact current production dependency closure.
# ---------------------------------------------------------------------------
for pair in \
  "$FVQ73:tests/fvq/test_fvq73_fpm14_drainage_response_independent.f90:$BUILD/test73.f90:$VQ73_BLOB" \
  "$FVQ74:tests/fvq/test_fvq74_drainage_cross_cutting_independent.f90:$BUILD/test74.f90:$VQ74_BLOB"; do
  commit="${pair%%:*}"; rest="${pair#*:}"; path="${rest%%:*}"; rest="${rest#*:}"; out="${rest%%:*}"; blob="${rest##*:}"
  git show "$commit:$path" > "$out" || fail "cannot materialize immutable drainage oracle $path"
  [[ "$(git hash-object "$out")" == "$blob" ]] || fail "immutable drainage oracle blob mismatch: $path"
done
echo 'STATUS_A_DRAINAGE_IMMUTABLE_VQ73_VQ74_ORACLES=PASS'

declare -A DRAIN_BLOBS=(
  [src/process/mod_drainage_empirical_interflow_response.f90]=eb53096b678d08b76d3fb1adb2247bc2a58ee748
  [src/process/mod_drainage_ernst_ipos45_preparation.f90]=fa1d5d400bb32be42e78889c0ff2a3bcab335142
  [src/process/mod_drainage_ernst_ipos45_response.f90]=b00ef0ae1f10182af2d0a8ea636d10b196e93379
  [src/process/mod_drainage_hooghoudt_equivalent_depth.f90]=6b7b2bb1fd259879d3f26c46abfc071ea2b2f108
  [src/process/mod_drainage_hooghoudt_ipos1_response.f90]=89f26e2d2b77bef5bdd0c5fdb2ce9ca1f03206fa
  [src/process/mod_drainage_hooghoudt_ipos23_response.f90]=5637ddb4d33141f00b4ebf737d1c7f7fe1824164
  [src/process/mod_drainage_multilevel_aggregation.f90]=70d35512ef7c5958f7e4bf284cba104a7b641fdb
  [src/process/mod_drainage_process.f90]=dbacd49da3bb0b94f822f9ee0478d15183e9c0fa
  [src/process/mod_drainage_tabulated_response.f90]=738f57c334910ab73bc8870e3aa8dda1c1a48c7a
  [src/runtime/mod_fmr_drainage_response_binding.f90]=76c2a2ea569a4e85e490ebd2e7fb89c28d8b3fb5
)
for p in "${!DRAIN_BLOBS[@]}"; do
  [[ "$(git rev-parse "HEAD:$p")" == "${DRAIN_BLOBS[$p]}" ]] || fail "qualified drainage production blob drift: $p"
done
echo 'STATUS_A_DRAINAGE_QUALIFIED_SOURCE_BLOBS_EXACT=PASS'

python3 "$ROOT/qualification/status_a_dependency_closure.py" \
  --out "$BUILD/drainage-module-sources.txt" \
  --test "$BUILD/test73.f90" \
  --test "$BUILD/test74.f90" \
  --support tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --support tests/fmr/mod_fmr04_fixed_top_provider.f90 \
  --force src/legacy/b1_10_port/headcalc.f90
mapfile -t DRAIN_SRC < "$BUILD/drainage-module-sources.txt"
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/drainage-o$opt"; mkdir -p "$OUT"; objects=()
  for source in "${DRAIN_SRC[@]}"; do
    obj="$OUT/$(printf '%s' "$source" | sha256sum | cut -c1-16).o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  for testno in 73 74; do
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/test${testno}.f90" -o "$OUT/test${testno}.o"
    gfortran -O"$opt" "${objects[@]}" "$OUT/test${testno}.o" -o "$OUT/test${testno}"
    "$OUT/test${testno}" > "$OUT/output${testno}.txt" 2>&1 || { cat "$OUT/output${testno}.txt" >&2; fail "drainage VQ${testno} O$opt execution"; }
  done
  for marker in \
    'FVQ73_TWO_LEVEL_BINDING_SEPARATION_AND_TANGENT=PASS' \
    'FVQ73_AGGREGATE_DERIVED_VIEW_NOT_TRANSFER=PASS' \
    'FVQ73_TWO_LEVEL_RUNTIME_HARD_MASS_AND_SINGLE_BOOKING=PASS' \
    'FVQ73_GENERIC_NONCALENDAR_INTERVAL=PASS' \
    'FVQ73_INVALID_SECOND_LEVEL_FAIL_CLOSED_ATOMIC=PASS' \
    'FVQ73_FPM14_DRAINAGE_RESPONSE_INDEPENDENT_RUNTIME=PASS'; do
    grep -Fxq "$marker" "$OUT/output73.txt" || fail "missing VQ73 O$opt marker: $marker"
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
    grep -Fxq "$marker" "$OUT/output74.txt" || fail "missing VQ74 O$opt marker: $marker"
  done
done
cmp -s "$BUILD/drainage-o0/output73.txt" "$BUILD/drainage-o2/output73.txt" || fail 'VQ73 current-head O0/O2 output drift'
cmp -s "$BUILD/drainage-o0/output74.txt" "$BUILD/drainage-o2/output74.txt" || fail 'VQ74 current-head O0/O2 output drift'
echo "STATUS_A_VQ73_OUTPUT_SHA256=$(sha256sum "$BUILD/drainage-o0/output73.txt" | awk '{print $1}')"
echo "STATUS_A_VQ74_OUTPUT_SHA256=$(sha256sum "$BUILD/drainage-o0/output74.txt" | awk '{print $1}')"
echo 'STATUS_A_DRAINAGE_CURRENT_HEAD_O0_O2_INDEPENDENT_REPLAY=PASS'

# ---------------------------------------------------------------------------
# 3. Inherited capability authorities: prove dependency locks on this exact head.
# ---------------------------------------------------------------------------
python3 - "$FGC28_CLOSE" "$FPE11_CLOSE" "$CANON" <<'PY'
import json, subprocess, sys
fgc28,fpe11,canon=sys.argv[1:]
def show_json(commit,path):
    return json.loads(subprocess.check_output(['git','show',f'{commit}:{path}'],text=True))
def blob(path):
    return subprocess.check_output(['git','rev-parse',f'HEAD:{path}'],text=True).strip()

g=show_json(fgc28,'integration/f-gc/F-GC28_CLOSEOUT.json')
assert g['verdict']=='CLOSED_CANONICAL_ADMITTED'
assert g['production_mutations_in_fgc28']==[]
for path,expected in g['admitted_production_blobs'].items():
    actual=blob(path)
    assert actual==expected,(path,expected,actual)
print('STATUS_A_FGC28_ALL_ADMITTED_PRODUCTION_BLOBS_EXACT=PASS')

w=json.loads(open('integration/f-ci/F-CI89_STATUS.json').read())
assert w['phase']=='CLOSE' and w['state']=='CANONICALLY_CLOSED'
assert w['admission_qualification']['verdict']=='PASS'
for item in w['production_postimage']:
    actual=blob(item['path'])
    assert actual==item['blob'],(item['path'],item['blob'],actual)
print('STATUS_A_WOFOST81_CLOSED_POSTIMAGE_EXACT=PASS')

s=json.loads(open('integration/f-pm/F-PM02_CURRENT_CANONICAL_CLOSE.json').read())
assert s['status']=='CLOSED_CURRENT_CANONICAL_RESTRICTED_SNOW_CAPABILITY'
assert s['closure_verdict']['missing_admission_gate_remaining'] is False
assert s['closure_verdict']['production_change_required_for_closure'] is False
locks=s['current_canonical_source_lock']
paths={
 'snow_process_blob':'src/process/mod_snow_process.f90',
 'serialized_reference_backend_blob':'src/runtime/mod_fmr_serialized_reference_backend.f90',
 'serialized_multiswap_runtime_blob':'src/runtime/mod_fmr_serialized_multiswap_runtime.f90',
}
for key,path in paths.items():
    actual=blob(path)
    assert actual==locks[key],(path,locks[key],actual)
print('STATUS_A_SNOW_CURRENT_CANONICAL_SOURCE_LOCK_EXACT=PASS')

p=show_json(fpe11,'integration/f-pe/F-PE11_CLOSE_CHECKPOINT.json')
assert p['phase']=='CLOSE'
assert p['final_verdict']=='FPE11_CURRENT_CANONICAL_PERFORMANCE_ADMISSION_VALID_ALREADY_REALIZED_AND_CLOSED'
post=p['canonical']['post_close_delta_from_qualified_head']
assert p['canonical']['post_close_live_head']==canon
assert post['production_source_changed'] is False
assert post['reference_source_changed'] is False
assert post['FPE11_relevant_dependency_changed'] is False
assert post['requalification_required'] is False
assert p['admit']['action']=='NO_OP' and p['admit']['canonical_mutation_performed'] is False
print('STATUS_A_FPE11_CURRENT_HEAD_INHERITANCE_EXACT=PASS')
PY

echo 'STATUS_A_INHERITED_AUTHORITIES_AND_DEPENDENCY_LOCKS=PASS'

# Static cleanliness and exit race check.
git diff --check "$CANON..HEAD"
cd "$ROOT"
[[ -z "$(git diff --name-only "$CANON..HEAD" -- src reference)" ]] || fail 'production/reference delta appeared during qualification'
LIVE_END="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$LIVE_END" == "$CANON" ]] || fail "canonical moved during qualification expected=$CANON actual=$LIVE_END"
echo "STATUS_A_QUALIFICATION_HEAD=$(git rev-parse HEAD)"
echo "STATUS_A_QUALIFIED_CANONICAL=$CANON"
echo 'STATUS_A_CURRENT_CANONICAL_QUALIFICATION=PASS'
