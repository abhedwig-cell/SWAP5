#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
PREREG=e151ee9c19c58d27c7f446d60c1042743f507882
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-gc-rzm06e09a-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${RZM06E09A_EVIDENCE_DIR:-$ROOT/RZM06E09A-EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "GC_RZM06E09A_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG" HEAD || fail "preregistration not ancestor"
: "${GITHUB_TOKEN:?GITHUB_TOKEN required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY required}"

meta="$(gh api "repos/$GITHUB_REPOSITORY/actions/artifacts/10703718492")"
name="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["name"])' <<<"$meta")"
expired="$(python3 -c 'import json,sys; print(str(json.load(sys.stdin)["expired"]).lower())' <<<"$meta")"
digest="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["digest"])' <<<"$meta")"
[[ "$name" == "gc-rzm06e07-35748744856" ]] || fail "E07 artifact name"
[[ "$expired" == "false" ]] || fail "E07 artifact expired"
[[ "$digest" == "sha256:3fe15feeffbdc318f97215fe78083b9861d5473c3d58647ea603994a560e4d5b" ]] || fail "E07 artifact digest"

curl --fail --silent --show-error --location   -H "Accept: application/vnd.github+json"   -H "Authorization: Bearer $GITHUB_TOKEN"   -H "X-GitHub-Api-Version: 2022-11-28"   -o "$BUILD/e07.zip"   "https://api.github.com/repos/$GITHUB_REPOSITORY/actions/artifacts/10703718492/zip"
unzip -q "$BUILD/e07.zip" -d "$BUILD/e07"

O0="$(find "$BUILD/e07" -type f -name 'e07-o0.txt' -print -quit)"
O2="$(find "$BUILD/e07" -type f -name 'e07-o2.txt' -print -quit)"
[[ -n "$O0" && -n "$O2" ]] || fail "missing E07 state outputs"
cmp "$O0" "$O2" || fail "E07 O0/O2 source drift"
echo 'GC_RZM06E09A_SOURCE_AUTHORITY=PASS'

python3 tests/research/test_gc_rootzone_memory_rzm06e09a_census.py   --o0 "$O0" --o2 "$O2" --output "$EVIDENCE/result.json" | tee "$EVIDENCE/census.txt"
grep -Fq 'GC_RZM06E09A_RESPONSE_BLIND_CENSUS=PASS' "$EVIDENCE/census.txt" || fail "census marker"
sha256sum "$O0" "$O2" "$EVIDENCE/result.json" "$EVIDENCE/census.txt" > "$EVIDENCE/sha256.txt"
echo 'GC_RZM06E09A_QUALIFICATION=PASS'
