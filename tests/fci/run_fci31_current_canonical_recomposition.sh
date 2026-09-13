#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TAG="${GITHUB_RUN_ID:-$$}-${GITHUB_RUN_ATTEMPT:-0}"
BASE_SCRIPT="$ROOT/tests/fci/.fci31-recomposed-base-$TAG.sh"
V4_SCRIPT="$ROOT/tests/fci/.fci31-recomposed-v4-$TAG.sh"

cleanup() {
  rm -f "$BASE_SCRIPT" "$V4_SCRIPT"
}
trap cleanup EXIT
cd "$ROOT"

BASE_BLOB=7dae081b3c57694abb76a25d577380912e7915e6
V4_BLOB=c01b469451e7485907e94a7a59860476ab7a8e78
CURRENT_CANONICAL=8c16ea58946092024e4b394db87acf91f3fd4abf
CURRENT_CANDIDATE=9492d99e6291dd21ba2c5b394a79b3f877fed0e2

for blob in "$BASE_BLOB" "$V4_BLOB"; do
  git cat-file -e "$blob" || {
    git fetch --no-tags origin qualification/f-ci31-fmr28-reference-et-root-uptake-execution-canonical-admission
    git cat-file -e "$blob"
  }
done

git cat-file blob "$BASE_BLOB" > "$BASE_SCRIPT"
git cat-file blob "$V4_BLOB" > "$V4_SCRIPT"
[[ "$(git hash-object "$BASE_SCRIPT")" == "$BASE_BLOB" ]]
[[ "$(git hash-object "$V4_SCRIPT")" == "$V4_BLOB" ]]
echo 'FCI31_CURRENT_CANONICAL_FROZEN_GREEN_HARNESS_REHYDRATED=PASS'

python3 - "$BASE_SCRIPT" "$CURRENT_CANONICAL" "$CURRENT_CANDIDATE" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); base=sys.argv[2]; candidate=sys.argv[3]
s=p.read_text(encoding='utf-8')
old_base='BASE=42b11df9b863afe9bfe2c24a6556293c04bbe555'
old_candidate='CANDIDATE=764c291c70290b9956f7ce806b9e989601f25d0a'
if s.count(old_base) != 1: raise SystemExit('FCI31 current-canonical base anchor mismatch')
if s.count(old_candidate) != 1: raise SystemExit('FCI31 current-canonical candidate anchor mismatch')
s=s.replace(old_base, f'BASE={base}', 1)
s=s.replace(old_candidate, f'CANDIDATE={candidate}', 1)
p.write_text(s,encoding='utf-8')
PY

python3 - "$V4_SCRIPT" "$BASE_SCRIPT" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); source=sys.argv[2]
s=p.read_text(encoding='utf-8')
old='SOURCE="$ROOT/tests/fci/run_fci31_reference_et_root_uptake_canonical_admission.sh"'
new=f'SOURCE="{source}"'
if s.count(old) != 1: raise SystemExit('FCI31 V4 source anchor mismatch')
s=s.replace(old,new,1)
p.write_text(s,encoding='utf-8')
PY

git merge-base --is-ancestor "$CURRENT_CANONICAL" "$CURRENT_CANDIDATE"
git merge-base --is-ancestor "$CURRENT_CANDIDATE" HEAD
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_reference_et_root_uptake_composition.f90)" == 8ed7610144700f58d0b89482925471fcb2ff7d69 ]]
git diff --quiet "$CURRENT_CANDIDATE"..HEAD -- src
mapfile -t delta < <(git diff --name-only "$CURRENT_CANONICAL".."$CURRENT_CANDIDATE" -- src | sort)
[[ "${#delta[@]}" -eq 1 ]]
[[ "${delta[0]}" == src/runtime/mod_fmr_reference_et_root_uptake_composition.f90 ]]
echo 'FCI31_CURRENT_CANONICAL_EXACT_ONE_SOURCE_RECOMPOSITION=PASS'

bash "$V4_SCRIPT"
echo 'FCI31_CURRENT_CANONICAL_RECOMPOSITION_GATE=PASS'
