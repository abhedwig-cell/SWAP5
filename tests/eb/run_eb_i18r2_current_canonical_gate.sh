#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

OLD_CANONICAL="1211bd5f4a4f9b1aee110e8e38cadad7ee52ae4f"
NEW_CANONICAL="5e5e498dc56d1df1dd7ebebbf9901c946445a1ab"
SOURCE_GATE="tests/eb/run_eb_i18r_current_canonical_gate.sh"
EXPECTED_SOURCE_GATE_BLOB="0dade6d7f758241671e107caf591774fd488591e"

fail() { echo "EB_I18R2_GATE_FAIL $*" >&2; exit 189; }

[[ "$(git hash-object "$SOURCE_GATE")" == "$EXPECTED_SOURCE_GATE_BLOB" ]] || \
  fail 'historical I18R gate blob drift'

git fetch -q origin integration/f-ci-canonical
LIVE_CANONICAL="$(git rev-parse origin/integration/f-ci-canonical)"
[[ "$LIVE_CANONICAL" == "$NEW_CANONICAL" ]] || \
  fail "live canonical moved: $LIVE_CANONICAL != $NEW_CANONICAL"
[[ "$(git merge-base "$NEW_CANONICAL" HEAD)" == "$NEW_CANONICAL" ]] || \
  fail 'I18R2 branch is not descended from current canonical'

# F-TB12P advanced canonical only through workflow, integration metadata and
# testbank-runner material. EB source/reference/test semantics must therefore
# remain byte-identical across the old and new canonical anchors.
git diff --quiet "$OLD_CANONICAL" "$NEW_CANONICAL" -- src reference tests || \
  fail 'current canonical changed EB-relevant src/reference/tests material'

echo "EB_I18R2_CURRENT_CANONICAL_REBIND=PASS old=$OLD_CANONICAL new=$NEW_CANONICAL"

TMP_GATE="$(mktemp "$ROOT/tests/eb/.eb-i18r2-rebound.XXXXXX.sh")"
trap 'rm -f "$TMP_GATE"' EXIT

python3 - "$SOURCE_GATE" "$TMP_GATE" "$OLD_CANONICAL" "$NEW_CANONICAL" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1])
target = Path(sys.argv[2])
old = sys.argv[3]
new = sys.argv[4]
text = source.read_text()
needle = f'CANONICAL="{old}"'
replacement = f'CANONICAL="{new}"'
if text.count(needle) != 1:
    raise SystemExit(f'expected exactly one canonical lock, found {text.count(needle)}')
target.write_text(text.replace(needle, replacement))
PY

bash "$TMP_GATE"
echo 'EB_I18R2_CURRENT_CANONICAL_QUALIFICATION=PASS'
