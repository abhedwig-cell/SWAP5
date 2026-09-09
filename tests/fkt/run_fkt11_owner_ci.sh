#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
TMP="$(mktemp tests/fkt/.run_fkt11_owner_ci_XXXXXX.sh)"
trap 'rm -f "$TMP"' EXIT
cp tests/fkt/run_fkt11_richards_head_budget_policy.sh "$TMP"
python3 - "$TMP" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
old="grep -Fq 'FKT09_MODEL_CERTIFICATE_RUNNER PASS' \"$BUILD/fkt09.txt\""
new="grep -Fq 'FKT09_MODEL_CERTIFICATE_GATE=PASS' \"$BUILD/fkt09.txt\""
assert s.count(old)==1, 'F-KT11 F-KT09 marker patch drift'
p.write_text(s.replace(old,new,1))
PY
bash "$TMP"
