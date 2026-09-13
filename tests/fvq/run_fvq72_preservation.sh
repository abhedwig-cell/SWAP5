#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT"
fail(){ echo "FVQ72_PRESERVATION_FAIL $*" >&2; exit 372; }
CANONICAL=379afd11e9a1d7fbef5ec74c9e05b0ec55884f4b
RUN=34781202197

[[ -z "$(git diff --name-only 82189c148a38b90b6a5a326d03f282ccbee52960..HEAD -- src reference)" ]] || fail 'qualification changed production/reference'
TMP="${RUNNER_TEMP:-/tmp}/fvq72-pres-${GITHUB_RUN_ID:-local}-$$"; rm -rf "$TMP"; mkdir -p "$TMP"; trap 'rm -rf "$TMP"' EXIT
args=(-fsSL -H 'Accept: application/vnd.github+json' -H 'X-GitHub-Api-Version: 2022-11-28')
if [[ -n "${GH_TOKEN:-}" ]]; then args+=(-H "Authorization: Bearer $GH_TOKEN"); fi
curl "${args[@]}" "https://api.github.com/repos/abhedwig-cell/SWAP5/actions/runs/$RUN" > "$TMP/run.json" || fail 'query canonical run'
curl "${args[@]}" "https://api.github.com/repos/abhedwig-cell/SWAP5/actions/runs/$RUN/jobs?per_page=100" > "$TMP/jobs.json" || fail 'query canonical jobs'
python3 - "$TMP/run.json" "$TMP/jobs.json" "$CANONICAL" <<'PY'
import json,sys
run=json.load(open(sys.argv[1],encoding='utf-8'))
jobs=json.load(open(sys.argv[2],encoding='utf-8'))['jobs']
sha=sys.argv[3]
assert run['name']=='F-CI canonical qualification'
assert run['head_sha']==sha and run['status']=='completed' and run['conclusion']=='success'
by={j['name']:j for j in jobs}
required=[
 'frozen-fci28-restart-authority',
 'frozen-fci30-restricted-parallel-v1-authority',
 'frozen-fci31-reference-et-root-uptake-authority',
 'frozen-fci37-parallel-root-uptake-authority',
 'current-restricted-canonical-preservation',
]
for name in required:
    assert name in by and by[name]['status']=='completed' and by[name]['conclusion']=='success', name
print('FVQ72_RESTART_PRESERVATION=PASS')
print('FVQ72_PARALLEL_PRESERVATION=PASS')
print('FVQ72_ET_ROOT_PRESERVATION=PASS')
print('FVQ72_BROAD_CANONICAL_PRESERVATION=PASS')
PY

python3 - <<'PY'
import json
p=json.load(open('integration/f-pm/F-PM11_STATUS.json',encoding='utf-8'))
assert p['decision']=='QUALIFIED_ET_ROOT_UPTAKE_SURFACE_EVAPORATION_V1_100_PERCENT_COMPLETE'
assert p['completion_100_percent'] is True
print('FVQ72_FPM11_100_PERCENT_COMPLETION_PRESERVED=PASS')
PY

PUB=src/runtime/mod_fmr_surface_evaporation_accepted_publication.f90
grep -Fq 'type :: fmr_prepared_surface_evaporation_publication_t' "$PUB" || fail 'private carrier missing'
grep -Fq 'This object is not an additional' "$PUB" || fail 'non-mass/persistence contract missing'
echo 'FVQ72_REJECTED_PUBLICATION_NOT_RESTART_STATE=PASS'
echo 'FVQ72_PRESERVATION_GATE=PASS'
