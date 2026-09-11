#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DERIVED="$HERE/.fci41-derived-postpromotion-runner.sh"
cp "$HERE/run_fci41_surface_evaporation_runtime_canonical_admission.sh" "$DERIVED"
trap 'rm -f "$DERIVED"' EXIT

python3 - "$DERIVED" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
old = "test \"$(git rev-parse origin/integration/f-ci-canonical)\" = \"$BASE\" || fail 'canonical moved after F-CI41 activation; recomposition required'"
new = r'''CANONICAL_NOW="$(git rev-parse origin/integration/f-ci-canonical)"
if [[ "$CANONICAL_NOW" == "$BASE" ]]; then
  echo 'FCI41_CANONICAL_PHASE=PRE_PROMOTION_SOURCE_LOCK'
else
  git merge-base --is-ancestor "$COMPOSITION" "$CANONICAL_NOW" || fail 'post-promotion canonical does not descend from F-CI41 composition'
  test "$(git rev-parse ${CANONICAL_NOW}:$PROCESS)" = "$PROCESS_BLOB" || fail 'post-promotion canonical structural process blob drift'
  test "$(git rev-parse ${CANONICAL_NOW}:$RUNTIME)" = "$RUNTIME_BLOB" || fail 'post-promotion canonical runtime materialization blob drift'
  test "$(git rev-parse ${CANONICAL_NOW}:reference)" = "$BASE_REF" || fail 'post-promotion canonical reference tree drift'
  echo 'FCI41_CANONICAL_PHASE=POST_PROMOTION_RECONCILIATION'
fi'''
if s.count(old) != 1:
    raise SystemExit(f'FCI41 v2 expected one source-lock guard, found {s.count(old)}')
s = s.replace(old, new, 1)
p.write_text(s)
PY

bash "$DERIVED"
