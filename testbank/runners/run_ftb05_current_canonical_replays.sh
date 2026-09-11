#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-}"
case "$MODE" in restart|parallel|parallel-restart) ;; *) echo "usage: $0 {restart|parallel|parallel-restart}" >&2; exit 2;; esac
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
FTB04=85280c6c436a73c211b70996f9a22f4ad6b04f9c
HIST=testbank/runners/run_ftb04_current_canonical_replays.sh
EXPECTED_BLOB="$(git rev-parse "$FTB04:$HIST")"
[[ "$(git rev-parse "HEAD:$HIST")" == "$EXPECTED_BLOB" ]] || { echo 'FTB05_REPLAY_FAIL:F-TB04 replay authority drift' >&2; exit 45; }
TMP="testbank/runners/.ftb05-current-canonical-replay-$$.sh"
cp "$HIST" "$TMP"
trap 'rm -f "$TMP"' EXIT
python3 - "$TMP" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
subs={
    'CANONICAL=0aeb0a2ed4096e1f9493d3dabc70962ea5270182':'CANONICAL=d201904a85f3b595e028242978e52c02f5122a09',
    'SRC_TREE=8ceeb70a64012631ebba295f5c045ea908b0681f':'SRC_TREE=d6f4816be543044b090d11294808b5be986b2ee8',
}
for old,new in subs.items():
    if old not in s:
        raise SystemExit('FTB05_REPLAY_FAIL:expected F-TB04 authority seam not found: '+old)
    s=s.replace(old,new,1)
p.write_text(s)
PY
chmod +x "$TMP"
"$TMP" "$MODE"
echo "FTB05_REBOUND_REPLAY_${MODE^^}=PASS:d201904a85f3b595e028242978e52c02f5122a09"
