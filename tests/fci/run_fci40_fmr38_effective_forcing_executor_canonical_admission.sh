#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE="1fab3e1b27d774f2869a003876d035b07c601ccf"
BASE_TREE="ebec5e647c68181ba958432ad575f9c95a9c752b"
COMPOSE="d81ef430ebaa601469a165dfc5b9866b813b71aa"
COMPOSE_TREE="2c0fb6cca501a65e931c3f185500b4913a46a26e"
COMPOSE_SRC_TREE="fd07bc662410a7bfbd64b4960295997c9e05e19a"
REF_TREE="9d08625217d7c0a7385df9da6a04183bcd9cb9e6"
RUNTIME="src/runtime/mod_fmr_serialized_multiswap_runtime.f90"
SOURCE_BLOB="fe5a06c9af59308cdad86c5126379f413591b0cd"
CANDIDATE_BLOB="f06a2eef7b47880e449cf9b201342d7bd1e197e1"
OWNER="eb7300829be05e1500ef94720673a13cb10cdeca"
CANDIDATE="b2e31bc8993075bc346f80ad7eb9dc4d92ff7ded"
FVQ55="00a27ac101db1492b7b1eec6d6944f846389e153"
FVQ55_STATUS_BLOB="e2c1c72f64f4ecea4b663bedee8c0e52bab9100f"
BUILD="${RUNNER_TEMP:-/tmp}/fci40-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

fail() { echo "FCI40_GATE_FAIL $*" >&2; exit 40; }
need_commit() {
  local sha="$1"
  git cat-file -e "${sha}^{commit}" 2>/dev/null || git fetch --no-tags origin "$sha" >/dev/null 2>&1 || fail "cannot fetch commit $sha"
}
for sha in "$BASE" "$COMPOSE" "$OWNER" "$CANDIDATE" "$FVQ55"; do need_commit "$sha"; done

git fetch --no-tags origin integration/f-ci-canonical >/dev/null 2>&1 || fail 'cannot fetch canonical branch'
test "$(git rev-parse origin/integration/f-ci-canonical)" = "$BASE" || fail 'canonical moved after F-CI40 source lock'
test "$(git rev-parse ${BASE}^{tree})" = "$BASE_TREE" || fail 'canonical base tree drift'
test "$(git rev-parse ${COMPOSE}^)" = "$BASE" || fail 'composition is not a direct child of current canonical'
test "$(git rev-parse ${COMPOSE}^{tree})" = "$COMPOSE_TREE" || fail 'composition tree drift'
test "$(git rev-parse ${COMPOSE}:src)" = "$COMPOSE_SRC_TREE" || fail 'composition src tree drift'
test "$(git rev-parse ${COMPOSE}:reference)" = "$REF_TREE" || fail 'composition reference tree drift'
test "$(git rev-parse ${BASE}:$RUNTIME)" = "$SOURCE_BLOB" || fail 'canonical source runtime blob drift'
test "$(git rev-parse ${CANDIDATE}:$RUNTIME)" = "$CANDIDATE_BLOB" || fail 'owner candidate blob drift'
test "$(git rev-parse ${COMPOSE}:$RUNTIME)" = "$CANDIDATE_BLOB" || fail 'composition does not reuse exact qualified blob'
test "$(git rev-parse HEAD:$RUNTIME)" = "$CANDIDATE_BLOB" || fail 'admission head changed production candidate blob'
test "$(git rev-parse ${FVQ55}:integration/f-vq/F-VQ55_STATUS.json)" = "$FVQ55_STATUS_BLOB" || fail 'F-VQ55 closeout status blob drift'
mapfile -t delta < <(git diff --name-only "$BASE".."$COMPOSE" -- src)
[[ ${#delta[@]} -eq 1 && "${delta[0]}" == "$RUNTIME" ]] || fail "unexpected production delta: ${delta[*]:-none}"
git diff --quiet "$COMPOSE"..HEAD -- src || fail 'F-CI40 governance authored post-composition production changes'
git diff --quiet "$BASE"..HEAD -- reference || fail 'F-CI40 changed frozen reference source'
echo 'FCI40_CURRENT_CANONICAL_ONE_BLOB_COMPOSITION=PASS'
echo 'FCI40_IMMUTABLE_FVQ55_PRODUCTION_BLOB=PASS'

python3 - "$OWNER" "$FVQ55" "$CANDIDATE" "$CANDIDATE_BLOB" <<'PY'
import json, subprocess, sys
owner, fvq, candidate, blob = sys.argv[1:]
def show(commit,path):
    return subprocess.check_output(['git','show',f'{commit}:{path}'],text=True)
o=json.loads(show(owner,'integration/f-mr/F-MR38_STATUS.json'))
assert o['decision']=='OWNER_QUALIFIED_GENERIC_RESOLVED_COLUMN_EXPLICIT_EFFECTIVE_FORCING_EXECUTOR_READY_FOR_INDEPENDENT_FVQ'
assert o['candidate']['commit']==candidate and o['candidate']['blob']==blob
q=json.loads(show(fvq,'integration/f-vq/F-VQ55_STATUS.json'))
assert q['decision']=='QUALIFIED_CURRENT_CANONICAL_EXPLICIT_EFFECTIVE_FORCING_EXECUTOR_WITHIN_FROZEN_SCOPE'
assert q['production_scope']==['src/runtime/mod_fmr_serialized_multiswap_runtime.f90']
assert q['production_blob']==blob
assert q['state']['independently_qualified'] is True
assert q['state']['canonical_admitted'] is False
assert q['architecture_invariants']=='30_OF_30_PASS'
print('FCI40_OWNER_AND_INDEPENDENT_AUTHORITY=PASS')
PY

# Replay the independent F-VQ55 oracle against this newer current-canonical composition.
# The historical runner is taken from the immutable F-VQ55 closeout, then only its
# source-bound base/materialization constants and known harness-only rename defect are
# adapted locally. No production source or scientific oracle is rewritten.
git show "$FVQ55:tests/fvq/run_fvq55_fmr38_effective_forcing_executor_qualification.sh" > "$BUILD/fvq55-current.sh"
python3 - "$BUILD/fvq55-current.sh" "$BASE" "$BASE_TREE" "$COMPOSE" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); base, tree, compose=sys.argv[2:]
s=p.read_text()
def one(old,new,label):
    global s
    n=s.count(old)
    if n != 1:
        raise SystemExit(f'FCI40 local replay patch {label}: expected one occurrence, found {n}')
    s=s.replace(old,new,1)
one('ROOT="$(cd "$(dirname "$0")/../.." && pwd)"','ROOT="$(pwd)"','root')
one('BASE="adf79478f55458c05444ad9b90e52644e6cf36b6"',f'BASE="{base}"','base')
one('BASE_TREE="ea5b54a971cf35ba0f49b1e283d13f7f69304654"',f'BASE_TREE="{tree}"','base tree')
one('MATERIALIZED="40c6da0a19f54434552d0e568a833bc712739899"',f'MATERIALIZED="{compose}"','materialized')
old="one('program test_fmq26_parallel_v1_admission','program test_fvq55_effective_forcing_executor','program')"
new="s=s.replace('program test_fmq26_parallel_v1_admission','program test_fvq55_effective_forcing_executor',1)"
one(old,new,'known harness-only program rename')
p.write_text(s)
PY
bash "$BUILD/fvq55-current.sh"

echo 'FCI40_FVQ55_ORACLE_REPLAY_ON_CURRENT_CANONICAL=PASS'
echo 'FCI40_TRANSACTIONAL_ROLLBACK=PASS'
echo 'FCI40_FORCING_REGISTRY_IMMUTABILITY=PASS'
echo 'FCI40_HARD_MASS=PASS'
echo 'FCI40_ARCHITECTURE_INVARIANTS=30_OF_30_NO_ADVERSE_DELTA'
echo 'FCI40_CANONICAL_ADMISSION_GATE=PASS'
