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
p.write_text(s.replace(old,new,1))
PY
chmod +x "$TMP"
bash "$TMP"
