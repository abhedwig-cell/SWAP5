#!/usr/bin/env bash
set -euo pipefail
PROFILE="${1:-FAST}"
case "$PROFILE" in FAST|CANONICAL|RELEASE|DEEP) ;; *) echo "usage: $0 {FAST|CANONICAL|RELEASE|DEEP}" >&2; exit 2;; esac
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
FTB05=81d4f0479a99bc456803f583457862387c267ec0
HIST=testbank/runners/run_ftb05_qualification.sh
[[ "$(git rev-parse "HEAD:$HIST")" == "$(git rev-parse "$FTB05:$HIST")" ]] || { echo 'FTB06_QUALIFICATION_FAIL:F-TB05 runner authority drift' >&2; exit 46; }
TMP="testbank/runners/.ftb06-qualification-$$.sh"
cp "$HIST" "$TMP"
trap 'rm -f "$TMP"' EXIT
python3 - "$TMP" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
subs={
 'python3 testbank/runners/validate_ftb05_continuous_adoption.py':'python3 testbank/runners/validate_ftb06_soil_temperature_adoption.py',
 'bash testbank/runners/run_ftb05_current_canonical_replays.sh':'bash testbank/runners/run_ftb06_current_canonical_replays.sh',
}
for old,new in subs.items():
    if old not in s:
        raise SystemExit('FTB06_QUALIFICATION_FAIL:expected F-TB05 seam not found: '+old)
    s=s.replace(old,new)
p.write_text(s)
PY
chmod +x "$TMP"
"$TMP" "$PROFILE"
if [[ "$PROFILE" != FAST ]]; then
  bash testbank/runners/run_ftb06_thermal_current_canonical_replay.sh
fi
python3 -m json.tool testbank/manifests/F-TB06_SOIL_TEMPERATURE_RUNTIME_CASES.json >/dev/null
python3 -m json.tool integration/f-tb/F-TB06_WORK_UNIT_CONTRACT.json >/dev/null
echo "FTB06_PROFILE_${PROFILE}=PASS"
