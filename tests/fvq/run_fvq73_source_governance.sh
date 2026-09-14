#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
fail(){ echo "FVQ73_SOURCE_GOVERNANCE_FAIL $*" >&2; exit 73; }

CANONICAL='e7b512cb4d7f400ed8e1d7aeb24f6dfe165ac557'
CANDIDATE='52c1a9aebddc435ef3792378f958305a96308ed0'
STATUS='integration/f-pm/F-PM14_STATUS.json'
AUDIT='integration/f-pm/F-PM14_ARCHITECTURE_AUDIT.json'

git merge-base --is-ancestor "$CANONICAL" "$CANDIDATE" || fail 'owner candidate is not descended from pinned canonical'
git merge-base --is-ancestor "$CANDIDATE" HEAD || fail 'VQ branch is not descended from exact owner-closeout candidate'
[[ "$(git rev-parse "$CANDIDATE:$STATUS")" == 'b31714551ccd3f934d540d94c164d6eea822f6c1' ]] || fail 'F-PM14 status blob drift'
[[ "$(git rev-parse "$CANDIDATE:$AUDIT")" == '518d171e608c4a6320d2bdd4d3825015d4298f67' ]] || fail 'F-PM14 invariant audit blob drift'

python3 - "$CANDIDATE" "$STATUS" "$AUDIT" <<'PY'
import json, subprocess, sys
candidate,status_path,audit_path=sys.argv[1:]
def load_at(path):
    raw=subprocess.check_output(['git','show',f'{candidate}:{path}'], text=True)
    return json.loads(raw)
s=load_at(status_path)
a=load_at(audit_path)
assert s['decision']=='QUALIFIED_FPM14_DRAINAGE_RESPONSE_RUNTIME_OWNER_READY_FOR_INDEPENDENT_VQ'
assert s['owner_qualified'] is True
assert s['preservation_qualified'] is True
assert s['backend_postimage_materialized'] is True
assert s['independently_qualified'] is False
assert s['canonical_admitted'] is False
assert s['drainage_v1_100_percent_complete'] is False
assert s['tested_candidate_head']=='232bfebd375c45f912a84cced24318f2a06a0991'
assert s['backend_postimage_commit']=='4094cd80393781ec06482a302b173b3fc2c73cdf'
assert s['owner_gate']['conclusion']=='success'
assert s['preservation_gate']['conclusion']=='success'
assert a['disposition']=='QUALIFIED_FPM14_DRAINAGE_RESPONSE_RUNTIME_OWNER_READY_FOR_INDEPENDENT_VQ'
assert len(a['invariants'])==30
assert [x['id'] for x in a['invariants']]==list(range(1,31))
assert all(x['status'] in {'QUALIFIED','PRESERVED'} for x in a['invariants'])
assert 'NOT_INDEPENDENTLY_FVQ_QUALIFIED' in a['explicit_nonclaims']
assert 'NOT_CANONICAL_ADMITTED' in a['explicit_nonclaims']
assert 'NOT_DRAINAGE_V1_100_PERCENT_COMPLETE' in a['explicit_nonclaims']
print('FVQ73_OWNER_CLOSEOUT_PROVENANCE=PASS')
print('FVQ73_INVARIANTS_1_30_OWNER_DISPOSITION_PRESENT=PASS')
PY

# Exact production authority of the candidate. All hashes were resolved directly
# from the owner-closeout commit, not copied from intermediate PM14 heads.
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
for p in "${!PROD_BLOBS[@]}"; do
  [[ "$(git rev-parse "$CANDIDATE:$p")" == "${PROD_BLOBS[$p]}" ]] || fail "candidate production blob drift: $p"
  [[ "$(git rev-parse "HEAD:$p")" == "${PROD_BLOBS[$p]}" ]] || fail "VQ branch modified candidate production: $p"
done

echo 'FVQ73_CANDIDATE_PRODUCTION_BLOBS_EXACT=PASS'

git diff --quiet "$CANDIDATE"..HEAD -- src reference || fail 'VQ branch modifies src/reference authority'
echo 'FVQ73_INDEPENDENT_BRANCH_NO_PRODUCTION_OR_REFERENCE_CHANGE=PASS'

expected="$({ printf '%s\n' "${!PROD_BLOBS[@]}"; } | LC_ALL=C sort)"
actual="$(git diff --name-only "$CANONICAL" "$CANDIDATE" -- src reference | LC_ALL=C sort)"
[[ "$actual" == "$expected" ]] || {
  echo 'Expected production delta:' >&2; printf '%s\n' "$expected" >&2
  echo 'Actual production delta:' >&2; printf '%s\n' "$actual" >&2
  fail 'canonical-to-candidate production delta is not the exact 11-file F-PM14 set'
}
echo 'FVQ73_CANONICAL_TO_CANDIDATE_PRODUCTION_DELTA_EXACT=PASS'

python3 - <<'PY'
from pathlib import Path
binding=Path('src/runtime/mod_fmr_drainage_response_binding.f90').read_text().lower()
backend=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
assert 'headcalc' not in binding
for token in ('open(', 'read(', 'write(', '.swp', 'midnight', 'calendar'):
    assert token not in binding
assert 'F-PM14 drainage response runtime composition' in backend
assert 'evaluate_fmr_drainage_response_bottom_lumped' in backend
assert 'call account_external_fluxes' in backend
print('FVQ73_STATIC_ARCHITECTURE_SEAM=PASS')
PY

git diff --check "$CANDIDATE"..HEAD
echo 'FVQ73_SOURCE_GOVERNANCE=PASS'
