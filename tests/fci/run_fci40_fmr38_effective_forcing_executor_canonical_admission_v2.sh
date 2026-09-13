#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DERIVED="$HERE/.fci40-derived-postpromotion-runner.sh"
cp "$HERE/run_fci40_fmr38_effective_forcing_executor_canonical_admission.sh" "$DERIVED"
trap 'rm -f "$DERIVED"' EXIT

python3 - "$DERIVED" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
old = "test \"$(git rev-parse origin/integration/f-ci-canonical)\" = \"$BASE\" || fail 'canonical moved after F-CI40 source lock'"
new = r'''CANONICAL_NOW="$(git rev-parse origin/integration/f-ci-canonical)"
if [[ "$CANONICAL_NOW" == "$BASE" ]]; then
  echo 'FCI40_CANONICAL_PHASE=PRE_PROMOTION_SOURCE_LOCK'
else
  git merge-base --is-ancestor "$COMPOSE" "$CANONICAL_NOW" || fail 'post-promotion canonical does not descend from F-CI40 composition'
  test "$(git rev-parse ${CANONICAL_NOW}:$RUNTIME)" = "$CANDIDATE_BLOB" || fail 'post-promotion canonical runtime candidate blob drift'
  test "$(git rev-parse ${CANONICAL_NOW}:reference)" = "$REF_TREE" || fail 'post-promotion canonical reference tree drift'
  echo 'FCI40_CANONICAL_PHASE=POST_PROMOTION_RECONCILIATION'
fi'''
if s.count(old) != 1:
    raise SystemExit(f'FCI40 v2 expected one source-lock guard, found {s.count(old)}')
s = s.replace(old, new, 1)
p.write_text(s)
PY

bash "$DERIVED"
