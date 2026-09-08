#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE="$ROOT/tests/fsi/run_fsi16_qualification_matrix_gate.sh"
TMP="$ROOT/tests/fsi/.run_fsi16_qualification_matrix_gate_v2_$$.sh"
trap 'rm -f "$TMP"' EXIT
cp "$BASE" "$TMP"
python3 - "$TMP" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
old="new=f'request_c%boundary%bottom_head = head_value + ({offset})_real64'"
new="new=f'request_c%boundary%bottom_head = head_value + ({offset}_real64)'"
if s.count(old) != 1:
    raise SystemExit(f'F-SI16_MATRIX_V2 literal marker count={s.count(old)}')
s=s.replace(old,new,1)
# The first characterized sweep showed qbot remained negative through -74 cm.
# Use one fixed high lower-face pressure head (-55 cm, +20 cm from reference)
# to exercise the supported inflow direction. This is a fixed qualification
# case, not an adaptive search and introduces no new scientific tolerance.
old="  run_case \"$opt\" high '1.0'  \"$out\""
new="  run_case \"$opt\" high '20.0' \"$out\""
if s.count(old) != 1:
    raise SystemExit(f'F-SI16_MATRIX_V2 high-head marker count={s.count(old)}')
s=s.replace(old,new,1)
p.write_text(s)
PY
chmod +x "$TMP"
bash "$TMP"
