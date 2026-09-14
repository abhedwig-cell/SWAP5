#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
fail(){ echo "FTB12_DRAINAGE_PRESERVATION_FAIL $*" >&2; exit 112; }

CANON='6425fb3290da637357e47618b459f4caf65a78d8'
CANON_TREE='40507dd481299ad1f98a9e2779b0ef870c6f66a3'
PM19='84edf5b728795cb62b43b0a2376d3bd8e3d5a5a3'
VQ76='5ee4920ffe680c920b64996159060fc1f509fcd8'
PM19_STATUS_BLOB='1d237b26f31c5e83fa7b299e01f47bd9ec6d5ff4'
PM19_COMPLETION_BLOB='f4ddf0b9ed945ccb6f8a66c4611de624d10dc4a8'
PM19_AUDIT_BLOB='dd49912365425f6d3cc9ce8b070a671eb010d751'
VQ76_STATUS_BLOB='c61081dbede3518d5625714926246cf438106222'
VQ76_WRAPPER_BLOB='751ae59d081be80c926e451505e22c77a39a77dc'
VQ76_INNER_BLOB='b5269247a8d5939a2c639239d8512451f9eca8b2'
VQ76_PREREG_BLOB='9ec4f4388c58b677bc1a40ebe58ae2579150fd2b'
VQ76_AUDIT_BLOB='f8c2cefd1e15938e9b0f84eceaa9913efa3134e0'

LIVE="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$LIVE" == "$CANON" ]] || fail "live canonical drift expected=$CANON actual=$LIVE"
[[ "$(git rev-parse "$CANON^{tree}")" == "$CANON_TREE" ]] || fail 'canonical tree drift'
git merge-base --is-ancestor "$CANON" HEAD || fail 'F-TB12 is not descended from exact canonical'
[[ -z "$(git diff --name-only "$CANON..HEAD" -- src reference)" ]] || fail 'F-TB12 changes production/reference source'
echo 'FTB12-REL-001=PASS_EXACT_CANONICAL_ZERO_PRODUCTION_DELTA'

# Exact completion and independent-preservation authorities.
[[ "$(git rev-parse "$PM19:integration/f-pm/F-PM19_STATUS.json")" == "$PM19_STATUS_BLOB" ]] || fail 'F-PM19 status drift'
[[ "$(git rev-parse "$PM19:integration/f-pm/F-PM19_DRAINAGE_V1_FINAL_COMPLETION.json")" == "$PM19_COMPLETION_BLOB" ]] || fail 'F-PM19 completion certificate drift'
[[ "$(git rev-parse "$PM19:integration/f-pm/F-PM19_ARCHITECTURE_AUDIT.json")" == "$PM19_AUDIT_BLOB" ]] || fail 'F-PM19 architecture audit drift'
[[ "$(git rev-parse "$VQ76:integration/f-vq/F-VQ76_STATUS.json")" == "$VQ76_STATUS_BLOB" ]] || fail 'F-VQ76 status drift'
[[ "$(git rev-parse "$VQ76:tests/fvq/run_fvq76_current_canonical_reconciled.sh")" == "$VQ76_WRAPPER_BLOB" ]] || fail 'F-VQ76 wrapper drift'
[[ "$(git rev-parse "$VQ76:tests/fvq/run_fvq76_drainage_post_fci62_preservation_requalification.sh")" == "$VQ76_INNER_BLOB" ]] || fail 'F-VQ76 inner gate drift'
[[ "$(git rev-parse "$VQ76:integration/f-vq/F-VQ76_PRE_REGISTRATION.json")" == "$VQ76_PREREG_BLOB" ]] || fail 'F-VQ76 preregistration drift'
[[ "$(git rev-parse "$VQ76:integration/f-vq/F-VQ76_ARCHITECTURE_AUDIT.json")" == "$VQ76_AUDIT_BLOB" ]] || fail 'F-VQ76 architecture audit drift'
echo 'FTB12_DRAINAGE_AUTHORITIES_EXACT=PASS'

python3 - "$PM19" "$VQ76" <<'PY'
import json, subprocess, sys
pm19,vq76=sys.argv[1:]
def load(commit,path):
    return json.loads(subprocess.check_output(['git','show',f'{commit}:{path}'], text=True))
s=load(pm19,'integration/f-pm/F-PM19_STATUS.json')
c=load(pm19,'integration/f-pm/F-PM19_DRAINAGE_V1_FINAL_COMPLETION.json')
a=load(pm19,'integration/f-pm/F-PM19_ARCHITECTURE_AUDIT.json')
v=load(vq76,'integration/f-vq/F-VQ76_STATUS.json')
assert s['decision']=='QUALIFIED_DRAINAGE_V1_100_PERCENT_COMPLETE'
assert s['closed'] is True and s['drainage_v1_100_percent_complete'] is True
assert s['frozen_denominator']['variant_count']==8
assert s['frozen_denominator']['changed'] is False
assert s['frozen_denominator']['scope_reduced'] is False
assert s['frozen_denominator']['scope_expanded'] is False
assert all(x=='CLOSED' for x in s['original_blockers'].values())
assert s['completion_evidence']['architecture_invariants_1_30']=='PASS_ALL_QUALIFIED_OR_PRESERVED'
assert s['completion_evidence']['mass_conservation_concession'] is False
assert s['scope_boundary']['fully_implicit_drainage_solver_coupling_added'] is False
assert c['drainage_v1_100_percent_complete'] is True
assert len(c['variant_completion'])==8 and all(x['disposition']=='PASS_COMPLETE' for x in c['variant_completion'])
assert all(x['status']=='CLOSED' for x in c['blocker_reconciliation'])
assert all(c['completion_contract'].values())
assert c['mass_conservation_concession'] is False
assert a['invariant_count']==30 and len(a['invariants'])==30
assert [x['id'] for x in a['invariants']]==list(range(1,31))
assert all(x['status'] in {'QUALIFIED','PRESERVED'} for x in a['invariants'])
assert a['all_invariants_pass_or_preserved'] is True and a['adverse_invariants']==[]
assert v['decision']=='QUALIFIED_DRAINAGE_RUNTIME_PRESERVED_ON_F_CI62_POSTIMAGE_INDEPENDENTLY'
assert v['independently_qualified'] is True
assert v['mass_conservation_concession'] is False
assert v['architecture_invariants_1_30']=='PASS_ALL_QUALIFIED_OR_PRESERVED'
print('FTB12-DRAIN-AUTH-001=PASS')
PY

# Historical F-TB11/F-TB11P remain immutable; F-TB12 is additive adoption only.
python3 - <<'PY'
import json
from pathlib import Path
old=json.loads(Path('integration/f-tb/F-TB11_PERMANENT_PRESERVATION_AUTHORITY.json').read_text())
post=json.loads(Path('integration/f-tb/F-TB11P_POSTIMAGE_RECONCILIATION.json').read_text())
new=json.loads(Path('testbank/manifests/F-TB12_DRAINAGE_V1_PERMANENT_PRESERVATION_ADOPTION.json').read_text())
assert old['drainage']['adopted'] is False
assert post['drainage_claim_added'] is False and post['drainage']['adopted'] is False
assert new['historical_testbank_authorities']['policy'].startswith('F-TB12 is additive')
assert new['adopted_capability']['decision']=='QUALIFIED_DRAINAGE_V1_100_PERCENT_COMPLETE'
assert new['adopted_capability']['frozen_denominator_variants']==8
assert new['adopted_capability']['mass_conservation_concession'] is False
assert len(new['stable_tests'])==8
assert new['horizontal_hard_gates']['waivable'] is False
print('FTB12_HISTORICAL_TESTBANK_AUTHORITIES_PRESERVED=PASS')
PY

# Re-execute the exact independent current-postimage drainage oracle.
TMP_WRAPPER='tests/fvq/run_fvq76_current_canonical_reconciled.sh'
TMP_INNER='tests/fvq/run_fvq76_drainage_post_fci62_preservation_requalification.sh'
TMP_PREREG='integration/f-vq/F-VQ76_PRE_REGISTRATION.json'
TMP_AUDIT='integration/f-vq/F-VQ76_ARCHITECTURE_AUDIT.json'
[[ ! -e "$TMP_WRAPPER" && ! -e "$TMP_INNER" && ! -e "$TMP_PREREG" && ! -e "$TMP_AUDIT" ]] || fail 'temporary VQ76 materialization paths unexpectedly exist'
cleanup(){ rm -f "$TMP_WRAPPER" "$TMP_INNER" "$TMP_PREREG" "$TMP_AUDIT" tests/fvq/.fvq76_reconciled_inner.sh tests/fpm/.fvq76_pm14_preservation.sh; }
trap cleanup EXIT
git show "$VQ76:$TMP_WRAPPER" > "$TMP_WRAPPER"
git show "$VQ76:$TMP_INNER" > "$TMP_INNER"
git show "$VQ76:$TMP_PREREG" > "$TMP_PREREG"
git show "$VQ76:$TMP_AUDIT" > "$TMP_AUDIT"
[[ "$(git hash-object "$TMP_WRAPPER")" == "$VQ76_WRAPPER_BLOB" ]] || fail 'materialized VQ76 wrapper differs'
[[ "$(git hash-object "$TMP_INNER")" == "$VQ76_INNER_BLOB" ]] || fail 'materialized VQ76 inner differs'
[[ "$(git hash-object "$TMP_PREREG")" == "$VQ76_PREREG_BLOB" ]] || fail 'materialized VQ76 prereg differs'
[[ "$(git hash-object "$TMP_AUDIT")" == "$VQ76_AUDIT_BLOB" ]] || fail 'materialized VQ76 audit differs'
chmod +x "$TMP_WRAPPER" "$TMP_INNER"
bash "$TMP_WRAPPER"

echo 'FTB12-DRAIN-RUNTIME-001=PASS'
echo 'FTB12-DRAIN-MASS-001=PASS_HARD_NON_WAIVABLE'
echo 'FTB12-DRAIN-RST-001=PASS'
echo 'FTB12-DRAIN-MSW-001=PASS'
echo 'FTB12-DRAIN-TIME-001=PASS'
echo 'FTB12-DRAIN-PRES-001=PASS'

git diff --check "$CANON..HEAD"
LIVE_END="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$LIVE_END" == "$CANON" ]] || fail "canonical moved during qualification expected=$CANON actual=$LIVE_END"
echo "FTB12_EXACT_HEAD=$(git rev-parse HEAD)"
echo 'F-TB12 QUALIFIED_DRAINAGE_V1_PERMANENT_TESTBANK_PRESERVATION_ADOPTED'
