#!/usr/bin/env bash
set -euo pipefail
PROFILE="${1:-FAST}"
case "$PROFILE" in FAST|CANONICAL|RELEASE|DEEP) ;; *) echo "usage: $0 {FAST|CANONICAL|RELEASE|DEEP}" >&2; exit 2;; esac
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
FTB04=85280c6c436a73c211b70996f9a22f4ad6b04f9c
HIST=testbank/runners/run_ftb04_qualification.sh
[[ "$(git rev-parse "HEAD:$HIST")" == "$(git rev-parse "$FTB04:$HIST")" ]] || { echo 'FTB05_QUALIFICATION_FAIL:F-TB04 runner authority drift' >&2; exit 46; }
TMP="testbank/runners/.ftb05-qualification-$$.sh"
cp "$HIST" "$TMP"
trap 'rm -f "$TMP"' EXIT
python3 - "$TMP" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
subs={
 'python3 testbank/runners/validate_ftb04_catalog.py':'python3 testbank/runners/validate_ftb05_continuous_adoption.py',
 'bash testbank/runners/run_ftb04_current_canonical_replays.sh':'bash testbank/runners/run_ftb05_current_canonical_replays.sh',
}
for old,new in subs.items():
    if old not in s:
        raise SystemExit('FTB05_QUALIFICATION_FAIL:expected F-TB04 seam not found: '+old)
    s=s.replace(old,new)
p.write_text(s)
PY
chmod +x "$TMP"
"$TMP" "$PROFILE"
echo "FTB05_PROFILE_${PROFILE}=PASS"
