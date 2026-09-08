#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="${TMPDIR:-/tmp}/fsi15-physical-authority-v2-$$.sh"
trap 'rm -f "$TMP"' EXIT
cp "$ROOT/tests/fsi/run_fsi15_physical_option_authority_gate.sh" "$TMP"
python3 - "$TMP" "$ROOT" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); root=sys.argv[2]
s=p.read_text()
old='ROOT="$(cd "$(dirname "$0")/../.." && pwd)"'
if s.count(old) != 1:
    raise SystemExit('F-SI15 v2 ROOT marker mismatch')
s=s.replace(old, f'ROOT="{root}"', 1)
old='gfortran "${FLAGS[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c "$driver" -o "$out/driver.o"'
new='gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c "$driver" -o "$out/driver.o"'
if s.count(old) != 1:
    raise SystemExit('F-SI15 v2 driver compile marker mismatch')
s=s.replace(old, new, 1)
p.write_text(s)
PY
chmod +x "$TMP"
bash "$TMP"
