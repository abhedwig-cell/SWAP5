#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT"
fail(){ echo "FPM12_PRESERVATION_FAIL $*" >&2; exit 312; }
CANONICAL=379afd11e9a1d7fbef5ec74c9e05b0ec55884f4b
CANONICAL_TREE=556221f62b4fde616981499eba68ef5460f5d83c
RUN=34781202197

[[ "$(git rev-parse "$CANONICAL^{tree}")" == "$CANONICAL_TREE" ]] || fail 'canonical tree mismatch'
git merge-base --is-ancestor "$CANONICAL" HEAD || fail 'F-PM12 no longer descends from canonical authority'
[[ -z "$(git diff --name-only "$CANONICAL"..HEAD -- src reference)" ]] || fail 'production/reference changed by F-PM12'

TMP="${RUNNER_TEMP:-/tmp}/fpm12-preservation-${GITHUB_RUN_ID:-local}-$$"; rm -rf "$TMP"; mkdir -p "$TMP"; trap 'rm -rf "$TMP"' EXIT
args=(-fsSL -H 'Accept: application/vnd.github+json' -H 'X-GitHub-Api-Version: 2022-11-28')
if [[ -n "${GH_TOKEN:-}" ]]; then args+=(-H "Authorization: Bearer $GH_TOKEN"); fi
curl "${args[@]}" "https://api.github.com/repos/abhedwig-cell/SWAP5/actions/runs/$RUN" > "$TMP/run.json" || fail 'cannot query canonical run'
curl "${args[@]}" "https://api.github.com/repos/abhedwig-cell/SWAP5/actions/runs/$RUN/jobs?per_page=100" > "$TMP/jobs.json" || fail 'cannot query canonical jobs'
python3 - "$TMP/run.json" "$TMP/jobs.json" "$CANONICAL" <<'PY'
import json,sys
run=json.load(open(sys.argv[1],encoding='utf-8'))
jobs=json.load(open(sys.argv[2],encoding='utf-8'))['jobs']
sha=sys.argv[3]
assert run['name']=='F-CI canonical qualification'
assert run['head_branch']=='integration/f-ci-canonical'
assert run['head_sha']==sha
assert run['status']=='completed' and run['conclusion']=='success'
by={j['name']:j for j in jobs}
required={
 'frozen-fci28-restart-authority':'restart',
 'frozen-fci30-restricted-parallel-v1-authority':'parallel',
 'frozen-fci31-reference-et-root-uptake-authority':'et_root',
 'frozen-fci37-parallel-root-uptake-authority':'parallel_root',
 'current-restricted-canonical-preservation':'current_preservation',
}
for name in required:
    assert name in by, name
    assert by[name]['status']=='completed' and by[name]['conclusion']=='success', name
print('FPM12_RESTART_PRESERVATION=PASS')
print('FPM12_PARALLEL_PRESERVATION=PASS')
print('FPM12_ET_ROOT_AUTHORITY_PRESERVATION=PASS')
print('FPM12_CURRENT_CANONICAL_PRESERVATION=PASS')
PY

# Accepted publication is non-persistent attribution. Its private prepared carrier
# is call-local, so rejected publication scratch cannot enter restart state.
grep -Fq 'type :: fmr_prepared_surface_evaporation_publication_t' src/runtime/mod_fmr_surface_evaporation_accepted_publication.f90 || fail 'private prepared carrier missing'
grep -Fq 'type, public :: fmr_surface_evaporation_publication_t' src/runtime/mod_fmr_surface_evaporation_accepted_publication.f90 || fail 'accepted publication type missing'
grep -Fq 'This object is not an additional' src/runtime/mod_fmr_surface_evaporation_accepted_publication.f90 || fail 'nonpersistent attribution contract drift'
echo 'FPM12_REJECTED_PUBLICATION_NOT_PERSISTENT_RESTART_STATE=PASS'
echo 'FPM12_PRESERVATION_GATE=PASS'
