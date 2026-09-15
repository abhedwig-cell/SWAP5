#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

fail(){ echo "FCI61_ADMISSION_GATE_FAIL $*" >&2; exit 61; }
RESTART=e7b512cb4d7f400ed8e1d7aeb24f6dfe165ac557
COMPOSITION=c7444233b0f23d4f0a845ef5639287e77099291b
OWNER=52c1a9aebddc435ef3792378f958305a96308ed0
VQ73=ea40e2d850aa9b4b23b25ba6b4a63ffd39811001
PRE=integration/f-ci/F-CI61_PRE_REGISTRATION.json
AUDIT=integration/f-ci/F-CI61_ARCHITECTURE_AUDIT.json
STATUS=integration/f-ci/F-CI61_STATUS.json

for object in "$RESTART" "$COMPOSITION" "$OWNER" "$VQ73"; do git cat-file -e "$object^{commit}"; done
[[ "$(git rev-parse "$COMPOSITION^")" == "$RESTART" ]] || fail 'composition parent is not frozen restart canonical'
git merge-base --is-ancestor "$COMPOSITION" HEAD || fail 'qualification head is not descended from exact production composition'
LIVE_CANONICAL="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$LIVE_CANONICAL" == "$RESTART" ]] || fail "live canonical drift expected=$RESTART actual=$LIVE_CANONICAL"
echo 'FCI61_AUTHORITY_AND_LIVE_CANONICAL_LOCKS=PASS'

declare -A PROD_BLOBS=(
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
  [src/runtime/mod_fmr_serialized_reference_backend.f90]=0f09c0df1559ece894356b146b64d872470c0a32
)
expected="$({ printf '%s\n' "${!PROD_BLOBS[@]}"; } | LC_ALL=C sort)"
actual="$(git diff --name-only "$RESTART..$COMPOSITION" -- src reference | LC_ALL=C sort)"
[[ "$actual" == "$expected" ]] || { printf 'expected:\n%s\nactual:\n%s\n' "$expected" "$actual" >&2; fail 'production composition scope'; }
for p in "${!PROD_BLOBS[@]}"; do
  want="${PROD_BLOBS[$p]}"
  [[ "$(git rev-parse "$COMPOSITION:$p")" == "$want" ]] || fail "composition blob drift $p"
  [[ "$(git rev-parse "HEAD:$p")" == "$want" ]] || fail "qualification source drift $p"
  [[ "$(git rev-parse "$OWNER:$p")" == "$want" ]] || fail "owner blob mismatch $p"
  [[ "$(git rev-parse "$VQ73:$p")" == "$want" ]] || fail "VQ73 blob mismatch $p"
done
[[ -z "$(git diff --name-only "$COMPOSITION..HEAD" -- src reference)" ]] || fail 'qualification branch changes src/reference'
echo 'FCI61_EXACT_11_PRODUCTION_BLOBS_LOCKED=PASS'

allowed=(
  integration/f-ci/F-CI61_PRE_REGISTRATION.json
  integration/f-ci/F-CI61_ARCHITECTURE_AUDIT.json
  integration/f-ci/F-CI61_STATUS.json
  tests/fci/run_fci61_fpm14_drainage_response_runtime_current_canonical_admission.sh
  .github/workflows/fci61-fpm14-drainage-response-runtime-current-canonical-admission.yml
)
mapfile -t changed < <(git diff --name-only "$COMPOSITION..HEAD")
for path in "${changed[@]}"; do
  ok=0
  for candidate in "${allowed[@]}"; do [[ "$path" == "$candidate" ]] && ok=1 && break; done
  [[ "$ok" -eq 1 ]] || fail "qualification scope unexpected path: $path"
done
echo 'FCI61_QUALIFICATION_SCOPE_ALLOWLIST=PASS'

python3 - "$OWNER" "$VQ73" "$PRE" "$AUDIT" "$STATUS" <<'PY'
import json, subprocess, sys, pathlib
owner,vq,pre_path,audit_path,status_path=sys.argv[1:]
def load_at(commit,path):
    return json.loads(subprocess.check_output(['git','show',f'{commit}:{path}'],text=True))
def load(path): return json.loads(pathlib.Path(path).read_text())
pm=load_at(owner,'integration/f-pm/F-PM14_STATUS.json')
pm_a=load_at(owner,'integration/f-pm/F-PM14_ARCHITECTURE_AUDIT.json')
v=load_at(vq,'integration/f-vq/F-VQ73_STATUS.json')
pre=load(pre_path); a=load(audit_path)
assert pm['decision']=='QUALIFIED_FPM14_DRAINAGE_RESPONSE_RUNTIME_OWNER_READY_FOR_INDEPENDENT_VQ'
assert pm['owner_qualified'] is True and pm['preservation_qualified'] is True
assert pm['canonical_admitted'] is False and pm['drainage_v1_100_percent_complete'] is False
assert v['decision']=='QUALIFIED_FPM14_DRAINAGE_RESPONSE_RUNTIME_INDEPENDENTLY'
assert v['independently_qualified'] is True and v['canonical_admitted'] is False
assert v['tested_head']['conclusion']=='success'
assert v['results']['candidate_production_blob_lock']=='PASS_EXACT_11_FILES'
assert v['results']['hard_mass_closure']=='PASS_TOLERANCE_1E-10'
assert v['results']['drainage_transfer_booking']=='PASS_SINGLE_AUTHORITATIVE_TRIAL_LEDGER_BOOKING'
assert v['results']['generic_noncalendar_interval']=='PASS'
assert v['results']['precomputed_DIVDRA_preservation']=='PASS'
assert v['results']['fixed_weir_preservation']=='PASS'
assert v['scope_guards']['production_source_changed_by_F_VQ73'] is False
assert len(pm_a['invariants'])==30 and [x['id'] for x in pm_a['invariants']]==list(range(1,31))
assert all(x['status'] in {'QUALIFIED','PRESERVED'} for x in pm_a['invariants'])
assert pre['production_composition']['sha']=='c7444233b0f23d4f0a845ef5639287e77099291b'
assert pre['scope_guards']['production_source_beyond_exact_fpm14_blobs'] is False
assert len(a['invariants'])==30 and [x['id'] for x in a['invariants']]==list(range(1,31))
assert all(x['fci61_assessment']=='NO_ADVERSE_DELTA' for x in a['invariants'])
assert a['canonical_admission'] is False
if pathlib.Path(status_path).exists():
    s=load(status_path)
    assert s['decision']=='QUALIFIED_F_CI61_READY_FOR_CANONICAL_PROMOTION'
    assert s['ready_for_canonical_promotion'] is True
    assert s['canonical_admission'] is False
    assert s['drainage_v1_100_percent_complete'] is False
print('FCI61_OWNER_VQ73_AND_30_INVARIANT_AUTHORITIES=PASS')
PY

# Replay the independent VQ73 executable oracle against this exact composition.
mkdir -p tests/fvq
for f in run_fvq73_independent_runtime.sh test_fvq73_fpm14_drainage_response_independent.f90; do
  git show "$VQ73:tests/fvq/$f" > "tests/fvq/$f"
done
chmod +x tests/fvq/run_fvq73_independent_runtime.sh
bash tests/fvq/run_fvq73_independent_runtime.sh
echo 'FCI61_VQ73_INDEPENDENT_RUNTIME_REPLAY=PASS'

# Replay the already-admitted precomputed-DIVDRA and fixed-weir routes on the
# composition without importing owner test history into the admission branch.
git show "$OWNER:tests/fpm/run_fpm14_precomputed_divdra_fixed_weir_preservation.sh" > tests/fpm/run_fpm14_precomputed_divdra_fixed_weir_preservation.sh
chmod +x tests/fpm/run_fpm14_precomputed_divdra_fixed_weir_preservation.sh
bash tests/fpm/run_fpm14_precomputed_divdra_fixed_weir_preservation.sh
echo 'FCI61_PRECOMPUTED_DIVDRA_FIXED_WEIR_PRESERVATION_REPLAY=PASS'

git diff --check "$COMPOSITION..HEAD"
echo "FCI61_EXACT_HEAD=$(git rev-parse HEAD)"
echo 'F-CI61 CURRENT-CANONICAL ADMISSION GATE PASS'
