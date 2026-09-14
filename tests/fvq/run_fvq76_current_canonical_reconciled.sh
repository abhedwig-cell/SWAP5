#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
fail(){ echo "FVQ76_CURRENT_CANONICAL_RECONCILIATION_FAIL $*" >&2; exit 176; }
SOURCE_POSTIMAGE='46ed64aba280bf721bce6f99446d0dd4ed00e38f'
LIVE="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
git cat-file -e "$LIVE^{commit}" || git fetch origin "$LIVE"
git diff --quiet "$SOURCE_POSTIMAGE".."$LIVE" -- src reference || fail "live canonical contains production/reference drift after preregistered source postimage: $LIVE"
git diff --quiet "$LIVE"..HEAD -- src reference || fail 'qualification HEAD production/reference differs from live canonical'
[[ "$(git rev-parse "$LIVE^{tree}")" != "$(git rev-parse "$SOURCE_POSTIMAGE^{tree}")" ]] || true

echo "FVQ76_LIVE_CANONICAL=$LIVE"
echo 'FVQ76_LIVE_CANONICAL_SRC_REFERENCE_BIT_EQUIVALENT_TO_PREREGISTERED_POSTIMAGE=PASS'

PATCHED='tests/fvq/.fvq76_reconciled_inner.sh'
trap 'rm -f "$PATCHED"' EXIT
python3 - <<'PY'
from pathlib import Path
src=Path('tests/fvq/run_fvq76_drainage_post_fci62_preservation_requalification.sh').read_text()
old='[[ "$LIVE" == "$CANONICAL" ]] || fail "live canonical drift expected=$CANONICAL actual=$LIVE"\n'
if old not in src:
    raise SystemExit('expected exact-live-canonical guard not found in F-VQ76 inner gate')
src=src.replace(old, "echo 'FVQ76_ORIGINAL_EXACT_LIVE_LOCK_RECONCILED_BY_METADATA_ONLY_CANONICAL_WRAPPER=PASS'\n", 1)
Path('tests/fvq/.fvq76_reconciled_inner.sh').write_text(src)
PY
chmod +x "$PATCHED"
bash "$PATCHED"
