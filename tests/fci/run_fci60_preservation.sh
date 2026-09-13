#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT"
fail(){ echo "FCI60_PRESERVATION_FAIL $*" >&2; exit 360; }
CANONICAL=379afd11e9a1d7fbef5ec74c9e05b0ec55884f4b
CANONICAL_RUN=34781202197
FVQ72=a3c7bf5a60d80b430758f85489b316b5bcbc2fdc
FVQ72_TESTED=30ad6104f91e4a10bb7f9863c6c8fff0dacddfa6
FVQ72_RUN=34784624580
FPM11=602a461957c45623fc414ef15e40a1bfe755de43

[[ -z "$(git diff --name-only "$CANONICAL"..HEAD -- src reference)" ]] || fail 'production/reference delta detected'
TMP="${RUNNER_TEMP:-/tmp}/fci60-pres-${GITHUB_RUN_ID:-local}-$$"; rm -rf "$TMP"; mkdir -p "$TMP"; trap 'rm -rf "$TMP"' EXIT
args=(-fsSL -H 'Accept: application/vnd.github+json' -H 'X-GitHub-Api-Version: 2022-11-28')
if [[ -n "${GH_TOKEN:-}" ]]; then args+=(-H "Authorization: Bearer $GH_TOKEN"); fi
for run in "$CANONICAL_RUN" "$FVQ72_RUN"; do
  curl "${args[@]}" "https://api.github.com/repos/abhedwig-cell/SWAP5/actions/runs/$run" > "$TMP/run-$run.json" || fail "query run $run"
  curl "${args[@]}" "https://api.github.com/repos/abhedwig-cell/SWAP5/actions/runs/$run/jobs?per_page=100" > "$TMP/jobs-$run.json" || fail "query jobs $run"
done
python3 - "$TMP" "$CANONICAL" "$CANONICAL_RUN" "$FVQ72_TESTED" "$FVQ72_RUN" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1]); canonical=sys.argv[2]; cr=int(sys.argv[3]); fvq72=sys.argv[4]; vr=int(sys.argv[5])
def load(name): return json.load(open(p/name,encoding='utf-8'))
run=load(f'run-{cr}.json'); jobs=load(f'jobs-{cr}.json')['jobs']
assert run['name']=='F-CI canonical qualification'
assert run['head_sha']==canonical and run['status']=='completed' and run['conclusion']=='success'
assert jobs, 'canonical job set empty'
for j in jobs:
    assert j['status']=='completed' and j['conclusion']=='success', (j['name'],j['status'],j['conclusion'])
required={
 'frozen-fci28-restart-authority',
 'frozen-fci30-restricted-parallel-v1-authority',
 'frozen-fci31-reference-et-root-uptake-authority',
 'frozen-fci37-parallel-root-uptake-authority',
 'current-restricted-canonical-preservation',
}
assert required.issubset({j['name'] for j in jobs})
vrun=load(f'run-{vr}.json'); vjobs=load(f'jobs-{vr}.json')['jobs']
assert vrun['head_sha']==fvq72 and vrun['status']=='completed' and vrun['conclusion']=='success'
assert len(vjobs)==1 and vjobs[0]['status']=='completed' and vjobs[0]['conclusion']=='success'
print('FCI60_BROAD_CANONICAL_QUALIFICATION=PASS_ALL_JOBS_GREEN')
print('FCI60_RESTART_PRESERVED=PASS')
print('FCI60_PARALLEL_PRESERVED=PASS')
print('FCI60_ET_ROOT_PRESERVED=PASS')
print('FCI60_FVQ72_INDEPENDENT_RUN_BOUND=PASS')
PY

git show "$FVQ72:integration/f-vq/F-VQ72_STATUS.json" > "$TMP/fvq72-status.json" || fail 'F-VQ72 status missing'
git show "$FPM11:integration/f-pm/F-PM11_STATUS.json" > "$TMP/fpm11-status.json" || fail 'F-PM11 status missing'
python3 - "$TMP/fvq72-status.json" "$TMP/fpm11-status.json" <<'PY'
import json,sys
v=json.load(open(sys.argv[1],encoding='utf-8')); p=json.load(open(sys.argv[2],encoding='utf-8'))
assert v['decision']=='QUALIFIED_SURFACE_EVAPORATION_ACCEPTED_PUBLICATION_CANDIDATE_BOUND_PROVENANCE'
assert v['independently_qualified'] is True and v['closed'] is True
assert p['decision']=='QUALIFIED_ET_ROOT_UPTAKE_SURFACE_EVAPORATION_V1_100_PERCENT_COMPLETE'
assert p['completion_100_percent'] is True and p['denominator']['changed'] is False and p['denominator']['scope_reduced'] is False
print('FCI60_FVQ72_DECISION=PASS_EXACT')
print('FCI60_FPM11_100_PERCENT_COMPLETION_PRESERVED=PASS')
print('FCI60_FPM09_DENOMINATOR_UNCHANGED=PASS')
PY

echo 'FCI60_POSTIMAGE_STATUS=PASS_CURRENT_CANONICAL_ALREADY_IS_QUALIFIED_POSTIMAGE'
echo 'FCI60_NO_DUPLICATE_PRODUCTION_ADMISSION=PASS'
echo 'FCI60_PRESERVATION_GATE=PASS'
