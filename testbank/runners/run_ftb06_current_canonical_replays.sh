#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-}"
case "$MODE" in restart|parallel|parallel-restart) ;; *) echo "usage: $0 {restart|parallel|parallel-restart}" >&2; exit 2;; esac
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
FTB05=81d4f0479a99bc456803f583457862387c267ec0
HIST=testbank/runners/run_ftb05_current_canonical_replays.sh
[[ "$(git rev-parse "HEAD:$HIST")" == "$(git rev-parse "$FTB05:$HIST")" ]] || { echo 'FTB06_REPLAY_FAIL:F-TB05 replay authority drift' >&2; exit 45; }
TMP="testbank/runners/.ftb06-current-canonical-replay-$$.sh"
cp "$HIST" "$TMP"
trap 'rm -f "$TMP"' EXIT
python3 - "$TMP" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
subs={
 'CANONICAL=d201904a85f3b595e028242978e52c02f5122a09':'CANONICAL=c7379b6b5b5f529ff96de3087379712bd665276a',
 'SRC_TREE=d6f4816be543044b090d11294808b5be986b2ee8':'SRC_TREE=d5aec38b432242d2674885c8b8bd21d7f0fa0836',
 'PASS:d201904a85f3b595e028242978e52c02f5122a09':'PASS:c7379b6b5b5f529ff96de3087379712bd665276a',
}
for old,new in subs.items():
    if old not in s:
        raise SystemExit('FTB06_REPLAY_FAIL:expected F-TB05 seam not found: '+old)
    s=s.replace(old,new)
p.write_text(s)
PY
chmod +x "$TMP"
"$TMP" "$MODE"
echo "FTB06_REBOUND_REPLAY_${MODE^^}=PASS:c7379b6b5b5f529ff96de3087379712bd665276a"
