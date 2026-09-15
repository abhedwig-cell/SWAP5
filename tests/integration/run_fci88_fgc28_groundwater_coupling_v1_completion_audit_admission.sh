#!/usr/bin/env bash
set -euo pipefail

BASE=dffc021507460ab1a613dfd2e916def7f3db1ea7
FVQ98_BRANCH=qualification/f-vq98-fgc28-groundwater-coupling-v1-completion-audit
FVQ98_AUTHORITY=22c2c107256de4351541a7dcdf91635d67681ec3
FVQ98_GREEN_STATUS=f4b3fa43ff453df9b15191fef6f0657b0b8e4e37
FVQ98_TESTED=bfd2a988e852afcf63da24a6f501924ccd83919c
FVQ98_CHECKPOINT_BLOB=43e29af4c8eb8cd5c1dbaab3bd978d213a4ef7a0
OWNER_BRANCH=work/f-gc28-groundwater-coupling-v1-completion-audit
OWNER_RECONCILE=fc5f9cc6bb4cc98f55dbe4ff0160dacdf1d4ee13

# Admission surface must remain governance/test-only over the exact qualified canonical base.
git merge-base --is-ancestor "$BASE" HEAD
while IFS= read -r path; do
  case "$path" in
    .github/workflows/f-ci88-fgc28-groundwater-coupling-v1-completion-audit-admission.yml|tests/integration/run_fci88_fgc28_groundwater_coupling_v1_completion_audit_admission.sh|integration/f-ci/F-CI88_STATUS.json) ;;
    *) echo "FCI88_METADATA_ONLY_DELTA=FAIL:$path"; exit 1 ;;
  esac
done < <(git diff --name-only "$BASE" HEAD)
echo "FCI88_METADATA_ONLY_DELTA=PASS"

git fetch --no-tags origin \
  "refs/heads/integration/f-ci-canonical:refs/remotes/origin/integration/f-ci-canonical" \
  "refs/heads/${FVQ98_BRANCH}:refs/remotes/origin/${FVQ98_BRANCH}" \
  "refs/heads/${OWNER_BRANCH}:refs/remotes/origin/${OWNER_BRANCH}"

LIVE_CANONICAL=$(git rev-parse refs/remotes/origin/integration/f-ci-canonical)
LIVE_FVQ98=$(git rev-parse "refs/remotes/origin/${FVQ98_BRANCH}")
LIVE_OWNER=$(git rev-parse "refs/remotes/origin/${OWNER_BRANCH}")
[[ "$LIVE_CANONICAL" == "$BASE" ]] || { echo "FCI88_LIVE_CANONICAL_LOCK=FAIL:$LIVE_CANONICAL"; exit 1; }
[[ "$LIVE_FVQ98" == "$FVQ98_AUTHORITY" ]] || { echo "FCI88_FVQ98_AUTHORITY_LOCK=FAIL:$LIVE_FVQ98"; exit 1; }
[[ "$LIVE_OWNER" == "$OWNER_RECONCILE" ]] || { echo "FCI88_OWNER_RECONCILE_LOCK=FAIL:$LIVE_OWNER"; exit 1; }
echo "FCI88_LIVE_CANONICAL_LOCK=PASS"
echo "FCI88_FVQ98_AUTHORITY_LOCK=PASS"
echo "FCI88_OWNER_RECONCILE_LOCK=PASS"

python3 - "$BASE" "$FVQ98_AUTHORITY" "$FVQ98_GREEN_STATUS" "$FVQ98_TESTED" "$FVQ98_CHECKPOINT_BLOB" "$OWNER_RECONCILE" <<'PY'
import json, subprocess, sys
base, authority, green_status, tested, checkpoint_blob, owner = sys.argv[1:]

def obj(ref, path):
    return json.loads(subprocess.check_output(['git','show',f'{ref}:{path}'], text=True))

def blob(ref, path):
    return subprocess.check_output(['git','rev-parse',f'{ref}:{path}'], text=True).strip()

def require(cond, marker, detail=''):
    if not cond:
        raise SystemExit(f"{marker}=FAIL{':' + detail if detail else ''}")
    print(f"{marker}=PASS")

q = obj(authority, 'qualification/F-VQ98_STATUS.json')
require(q['status'] == 'INDEPENDENTLY_QUALIFIED', 'FCI88_FVQ98_VERDICT')
require(q['tested_head'] == tested, 'FCI88_FVQ98_TESTED_HEAD')
require(q['workflow']['run_id'] == 35034320670 and q['workflow']['job_id'] == 104599799898 and q['workflow']['conclusion'] == 'success', 'FCI88_FVQ98_GREEN_WORKFLOW')
require(q['canonical_base']['head'] == base and q['canonical_base']['tree'] == '763645d4d3d797675f527f2b156c75cf9ccb5eb2', 'FCI88_FVQ98_BASE_PIN')
require(q['qualified_findings']['six_obligation_denominator_exact'] == 'PASS', 'FCI88_SIX_OBLIGATION_DENOMINATOR')
require(q['qualified_findings']['all_G05_production_blobs_locked'] == 'PASS', 'FCI88_G05_BLOB_LOCKS')
require(q['qualified_findings']['F_GC27_F_VQ97_F_CI87_end_to_end_close'] == 'PASS', 'FCI88_END_TO_END_CLOSE')
require(q['qualified_findings']['production_mutation'] is False and q['production_mutations'] == [] and q['reference_mutations'] == [], 'FCI88_FVQ98_NO_PRODUCTION_MUTATION')

cp = obj(authority, 'qualification/F-VQ98_QUALIFY_CHECKPOINT.json')
require(blob(authority, 'qualification/F-VQ98_QUALIFY_CHECKPOINT.json') == checkpoint_blob, 'FCI88_FVQ98_CHECKPOINT_BLOB')
require(cp['state'] == 'INDEPENDENTLY_QUALIFIED' and cp['qualification_authority']['green_status_head'] == green_status, 'FCI88_FVQ98_CHECKPOINT_VERDICT')
require(cp['qualification_authority']['workflow_run'] == 35034372726 and cp['qualification_authority']['workflow_job'] == 104599969590 and cp['qualification_authority']['conclusion'] == 'success', 'FCI88_FVQ98_GREEN_STATUS_RUN')
require(cp['production_mutations'] == [] and cp['reference_mutations'] == [], 'FCI88_FVQ98_CHECKPOINT_NO_MUTATION')

rec = obj(owner, 'integration/f-gc/F-GC28_RECONCILE_CHECKPOINT.json')
require(rec['current_canonical']['head'] == base, 'FCI88_OWNER_CANONICAL_PIN')
require(len(rec['technical_closure_obligations']) == 6 and all(x['reconciled_status'] == 'CLOSED_PENDING_F_VQ98_AUDIT' for x in rec['technical_closure_obligations']), 'FCI88_OWNER_SIX_CLOSURE_MAPPING')
require(rec['production_mutations_in_reconcile'] == [], 'FCI88_OWNER_NO_PRODUCTION_MUTATION')

expected = {
 'src/runtime/mod_groundwater_predictor_corrector_window.f90':'fa2a5a45d558fbaaea242438915cdb7420b6503c',
 'src/runtime/mod_groundwater_tile_aggregation.f90':'d62ecba039d9bef178acde6900b81e9d5b0931eb',
 'src/runtime/mod_groundwater_accuracy_binding.f90':'b8ac03e810c73519b433f7851c6fd143ba26676a',
 'src/runtime/mod_groundwater_coupling_response.f90':'645141676536ae8289b9d52433798a965c7baa04',
 'src/runtime/mod_groundwater_coupled_restart.f90':'0596933ff3ae89c61ab7a0913189a4fa3179e50b',
 'src/runtime/mod_groundwater_multiswap_coupler.f90':'f2bf0e7d144fd3c0b9dc18f24f24eb4ffb7ffa0f',
 'src/adapter/mod_groundwater_external_gateway.f90':'f307f17e2fd20983432f91e91ac90aaae8311849',
}
for path, sha in expected.items():
    require(blob(base, path) == sha, 'FCI88_CURRENT_CANONICAL_PRODUCTION_LOCK', path)
    require(q['qualified_production_blobs'][path] == sha, 'FCI88_FVQ98_PRODUCTION_AUTHORITY', path)

c27 = obj(base, 'integration/f-gc/F-GC27_CLOSEOUT.json')
require(c27['verdict'] == 'CLOSED_CANONICAL_ADMITTED' and c27['production_mutations_in_fgc27'] == [], 'FCI88_FGC27_CLOSEOUT_BOUND')
print('F-CI88 F-GC28 ADMISSION GATE PASS')
PY
