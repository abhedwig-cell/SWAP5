#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CORE_AUTHORITY='6b8578003319ac71c22284882c7e9160232f117a'
GOV_CANON='992a5c657bfe10a10100f92e0cb77c4825ae65b6'
GOV_TREE='dec751ba5182fd9ceee86568020090952d118fae'
SCIENTIFIC_BASE='50346642bd565f79134ea17d5462e544b354998c'
SCIENTIFIC_TREE='3b085d7dea3d3f3fce42ad9d8f259a8350205846'

TMP_CORE="$ROOT/qualification/.status_a_20260916_core_$$.sh"
trap 'rm -f "$TMP_CORE"' EXIT

git cat-file -e "$CORE_AUTHORITY^{commit}"
git show "$CORE_AUTHORITY:qualification/run_status_a_20260916_current_canonical.sh" > "$TMP_CORE"

python3 - "$TMP_CORE" "$GOV_CANON" "$GOV_TREE" "$SCIENTIFIC_BASE" <<'PY'
from pathlib import Path
import sys

path=Path(sys.argv[1])
gov, tree, scientific=sys.argv[2:]
s=path.read_text(encoding='utf-8')
repls=[
    ("CANON='50346642bd565f79134ea17d5462e544b354998c'", f"CANON='{gov}'"),
    ("CANON_TREE='3b085d7dea3d3f3fce42ad9d8f259a8350205846'", f"CANON_TREE='{tree}'"),
    ('python3 - "$PE11_CLOSE" "$CANON" <<\'PY\'', f'python3 - "$PE11_CLOSE" "{scientific}" <<\'PY\''),
]
for old,new in repls:
    if s.count(old) != 1:
        raise SystemExit(f'post-admission repin anchor mismatch: {old!r}')
    s=s.replace(old,new,1)
path.write_text(s,encoding='utf-8')
PY

# The concurrent canonical admission is governance/evidence only. Assert that
# its scientific production image is exactly the already-qualified 503466 tree.
[[ "$(git rev-parse "$SCIENTIFIC_BASE^{tree}")" == "$SCIENTIFIC_TREE" ]] || {
  echo 'STATUS_A_POST_ADMISSION_SCIENTIFIC_TREE_LOCK=FAIL' >&2
  exit 191
}
[[ -z "$(git diff --name-only "$SCIENTIFIC_BASE".."$GOV_CANON" -- src reference)" ]] || {
  echo 'STATUS_A_POST_ADMISSION_PRODUCTION_REFERENCE_DELTA=FAIL' >&2
  git diff --name-only "$SCIENTIFIC_BASE".."$GOV_CANON" -- src reference >&2
  exit 192
}
changed="$(git diff --name-only "$SCIENTIFIC_BASE".."$GOV_CANON")"
[[ "$changed" == 'tests/qualification/status-a-baseline-20260916/STATUS_A_RELEASE_READINESS_BASELINE.md' ]] || {
  echo 'STATUS_A_POST_ADMISSION_UNEXPECTED_GOVERNANCE_DELTA=FAIL' >&2
  printf '%s\n' "$changed" >&2
  exit 193
}
echo 'STATUS_A_POST_ADMISSION_GOVERNANCE_ONLY_DELTA=PASS'

bash "$TMP_CORE"

echo "STATUS_A_GOVERNANCE_CANONICAL_HEAD=$GOV_CANON"
echo "STATUS_A_GOVERNANCE_CANONICAL_TREE=$GOV_TREE"
echo "STATUS_A_SCIENTIFIC_PRODUCTION_BASELINE_HEAD=$SCIENTIFIC_BASE"
echo "STATUS_A_SCIENTIFIC_PRODUCTION_BASELINE_TREE=$SCIENTIFIC_TREE"
echo 'STATUS_A_POST_ADMISSION_BOUNDED_QUALIFICATION=PASS'
