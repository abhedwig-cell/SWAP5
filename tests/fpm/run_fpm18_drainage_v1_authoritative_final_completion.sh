#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
fail(){ echo "FPM18_AUTHORITATIVE_COMPLETION_GATE_FAIL $*" >&2; exit 118; }

CANONICAL='46ed64aba280bf721bce6f99446d0dd4ed00e38f'
PM13='e5cd87eafb95356ca0d5ef8399fcb64feae78fd2'
PM14='52c1a9aebddc435ef3792378f958305a96308ed0'
VQ73='ea40e2d850aa9b4b23b25ba6b4a63ffd39811001'
VQ74='60c121a0993993bd79fb30ddfd54e2a9d14f042e'
PM17='45455f54c0c3554150e273aff07bfccd06d69c14'
FCI61_MERGE='eb2b2b17b2d54eeab22c4cba922426d8168e56a9'
FCI61P_MERGE='e79b0272edb544ec4c8000a4d6869274f1ab3ae5'
FCI62_SECOND_PARENT='9745433b4ff7e6eb1337b58e0d861e73a9f1ade8'
PM14_COMPOSITION='c7444233b0f23d4f0a845ef5639287e77099291b'

for c in "$CANONICAL" "$PM13" "$PM14" "$VQ73" "$VQ74" "$PM17" "$FCI61_MERGE" "$FCI61P_MERGE" "$PM14_COMPOSITION"; do
  git cat-file -e "$c^{commit}" || fail "missing authority commit $c"
done
LIVE="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$LIVE" == "$CANONICAL" ]] || fail "live canonical drift expected=$CANONICAL actual=$LIVE"
git merge-base --is-ancestor "$CANONICAL" HEAD || fail 'F-PM18 is not rooted in live canonical'
git diff --quiet "$CANONICAL"..HEAD -- src reference || fail 'F-PM18 changes production/reference source'
echo 'FPM18_AUDIT_ONLY_NO_PRODUCTION_REFERENCE_CHANGE=PASS'

[[ "$(git rev-parse "$PM13:integration/f-pm/F-PM13_DRAINAGE_V1_FINAL_COMPLETION.json")" == 'ce4dc39da4a97f070539896e9929f00c475d7ffa' ]] || fail 'F-PM13 denominator authority drift'
[[ "$(git rev-parse "$PM14:integration/f-pm/F-PM14_STATUS.json")" == 'b31714551ccd3f934d540d94c164d6eea822f6c1' ]] || fail 'F-PM14 status drift'
[[ "$(git rev-parse "$VQ73:integration/f-vq/F-VQ73_STATUS.json")" == 'c3bf68d2e885ec2f576e1400fcfb5d359806d319' ]] || fail 'F-VQ73 status drift'
[[ "$(git rev-parse "$VQ74:integration/f-vq/F-VQ74_STATUS.json")" == '6d11601f5d4929af801fdadd526bb4918281b6d2' ]] || fail 'F-VQ74 status drift'
[[ "$(git rev-parse "$PM17:integration/f-pm/F-PM17_STATUS.json")" == 'ff7e444ad99271ea6daf7bde5be6c84896d1aeab' ]] || fail 'F-PM17 scope correction drift'
echo 'FPM18_FROZEN_AUTHORITIES_EXACT=PASS'

python3 - "$PM13" "$PM14" "$VQ73" "$VQ74" "$PM17" <<'PY'
import json, subprocess, sys
pm13,pm14,vq73,vq74,pm17=sys.argv[1:]
def load(c,p):
    return json.loads(subprocess.check_output(['git','show',f'{c}:{p}'],text=True))
a=load(pm13,'integration/f-pm/F-PM13_DRAINAGE_V1_FINAL_COMPLETION.json')
o=load(pm14,'integration/f-pm/F-PM14_STATUS.json')
v73=load(vq73,'integration/f-vq/F-VQ73_STATUS.json')
v74=load(vq74,'integration/f-vq/F-VQ74_STATUS.json')
s17=load(pm17,'integration/f-pm/F-PM17_STATUS.json')
assert a['denominator']['changed'] is False and a['denominator']['scope_reduced'] is False
assert len(a['denominator']['frozen_variants']) == 8
assert [x['id'] for x in a['hard_blockers']] == ['G1_RUNTIME_COMPOSITION','G2_TRANSACTION_MASS_RESTART_MULTISWAP_DIAGNOSTICS','G3_CANONICAL_ADMISSION_PRESERVATION']
assert o['owner_qualified'] is True and o['preservation_qualified'] is True
assert v73['independently_qualified'] is True and v73['closed'] is True
assert v73['decision']=='QUALIFIED_FPM14_DRAINAGE_RESPONSE_RUNTIME_INDEPENDENTLY'
assert v74['independently_qualified'] is True and v74['closed'] is True
assert v74['decision']=='QUALIFIED_DRAINAGE_V1_CROSS_CUTTING_G2_INDEPENDENTLY'
assert s17['decision']=='F_PM15_G1R_NOT_A_FROZEN_DRAINAGE_V1_EXIT_REQUIREMENT'
assert s17['frozen_denominator_changed'] is False
assert s17['scope_expanded_for_completion'] is False
assert s17['fully_implicit_implementation_authorized'] is False
print('FPM18_ORIGINAL_PM13_DENOMINATOR_AND_G1_G2_G3_ONLY=PASS')
print('FPM18_FPM15_SCOPE_EXPANSION_EXCLUDED=PASS')
PY

# Exact historical admission/preservation history remains reachable.
[[ "$(git rev-list --parents -n1 "$FCI61_MERGE")" == "$FCI61_MERGE e7b512cb4d7f400ed8e1d7aeb24f6dfe165ac557 0ac2f09642f71269ee43301cfedde4f2dd95ade6" ]] || fail 'F-CI61 merge-parent drift'
[[ "$(git rev-list --parents -n1 "$FCI61P_MERGE")" == "$FCI61P_MERGE $FCI61_MERGE 537695a6194d22b19e28d2d9abfb0d80da42dd93" ]] || fail 'F-CI61P merge-parent drift'
[[ "$(git rev-list --parents -n1 "$CANONICAL")" == "$CANONICAL $FCI61P_MERGE $FCI62_SECOND_PARENT" ]] || fail 'F-CI62 canonical merge-parent drift'
echo 'FPM18_DRAINAGE_ADMISSION_AND_FCI62_LINEAGE_EXACT=PASS'

# Ten response/process/binding blobs remain exact. The shared backend does not.
declare -A STABLE_BLOBS=(
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
for p in "${!STABLE_BLOBS[@]}"; do
  [[ "$(git rev-parse "$CANONICAL:$p")" == "${STABLE_BLOBS[$p]}" ]] || fail "stable drainage blob drift: $p"
done
BACKEND='src/runtime/mod_fmr_serialized_reference_backend.f90'
OLD_BACKEND='0f09c0df1559ece894356b146b64d872470c0a32'
NEW_BACKEND='21e0e4229f202f1a3a74c4da004aa32a2c855f03'
[[ "$(git rev-parse "$VQ73:$BACKEND")" == "$OLD_BACKEND" ]] || fail 'F-VQ73 backend authority drift'
[[ "$(git rev-parse "$CANONICAL:$BACKEND")" == "$NEW_BACKEND" ]] || fail 'unexpected live canonical backend blob'
[[ "$OLD_BACKEND" != "$NEW_BACKEND" ]] || fail 'backend drift expected but absent'
echo 'FPM18_TEN_DRAINAGE_BLOBS_EXACT_SHARED_BACKEND_DRIFT_CONFIRMED=PASS'

# F-CI62 itself says postimage reconciliation is still open.
python3 - <<'PY'
import json
from pathlib import Path
s=json.loads(Path('integration/f-ci/F-CI62_STATUS.json').read_text())
assert s['decision']=='QUALIFIED_F_CI62_READY_FOR_CANONICAL_PROMOTION'
assert s['postimage_reconciled'] is False
assert s['canonical_base']=='e79b0272edb544ec4c8000a4d6869274f1ab3ae5'
print('FPM18_FCI62_POSTIMAGE_RECONCILIATION_OPEN=PASS')
PY

# Reproduce the moving-current preservation mismatch without treating it as a physics defect.
WORKFLOW='.github/workflows/fci-canonical.yml'
grep -q 'AUTH=c7444233b0f23d4f0a845ef5639287e77099291b' "$WORKFLOW" || fail 'moving authority no longer PM14 composition; audit must be rerun'
grep -q 'src/runtime/mod_fmr_serialized_reference_backend.f90' "$WORKFLOW" || fail 'shared drainage backend not protected by moving surface'
grep -q 'src/solver/mod_reference_richards_temporal_indicator.f90' "$WORKFLOW" || fail 'temporal indicator not protected by moving surface'
[[ "$(git rev-parse "$CANONICAL:src/solver/mod_reference_richards_temporal_indicator.f90")" != "$(git rev-parse "$PM14_COMPOSITION:src/solver/mod_reference_richards_temporal_indicator.f90")" ]] || fail 'expected temporal-indicator moving drift absent'
[[ "$(git rev-parse "$CANONICAL:$BACKEND")" != "$(git rev-parse "$PM14_COMPOSITION:$BACKEND")" ]] || fail 'expected shared-backend moving drift absent'
echo 'FPM18_CURRENT_CANONICAL_MOVING_PRESERVATION_DRIFT_REPRODUCED=PASS'

python3 - <<'PY'
import json
from pathlib import Path
c=json.loads(Path('integration/f-pm/F-PM18_DRAINAGE_V1_AUTHORITATIVE_FINAL_COMPLETION.json').read_text())
a=json.loads(Path('integration/f-pm/F-PM18_ARCHITECTURE_AUDIT.json').read_text())
assert len(c['frozen_denominator']['variants'])==8
assert c['frozen_denominator']['original_blockers']==['G1_RUNTIME_COMPOSITION','G2_TRANSACTION_MASS_RESTART_MULTISWAP_DIAGNOSTICS','G3_CANONICAL_ADMISSION_PRESERVATION']
assert c['scope_authority_reconciliation']['fully_implicit_drainage_solver_coupling_is_v1_exit_requirement'] is False
assert c['current_canonical_drift']['shared_drainage_backend']['exact_blob_preserved'] is False
assert c['minimum_remaining_closure']['new_drainage_physics_required'] is False
assert c['minimum_remaining_closure']['fully_implicit_solver_coupling_required'] is False
assert c['hundred_percent_complete'] is False
assert c['final_decision']=='DRAINAGE_V1_FINAL_CLOSURE_GAPS_REMAIN_CURRENT_CANONICAL_PRESERVATION_ONLY'
assert a['invariant_count']==30 and len(a['invariants'])==30
assert [x['id'] for x in a['invariants']]==list(range(1,31))
assert a['all_invariants_no_adverse_F_PM18_delta'] is True
assert a['mass_conservation_concession'] is False
assert a['scope_reduction'] is False and a['scope_expansion'] is False
assert a['hundred_percent_complete'] is False
print('FPM18_MACHINE_READABLE_FAIL_CLOSED_COMPLETION_DECISION=PASS')
PY

git diff --check "$CANONICAL..HEAD"
echo "FPM18_EXACT_HEAD=$(git rev-parse HEAD)"
echo 'F-PM18 AUTHORITATIVE DRAINAGE-V1 COMPLETION GATE PASS'
