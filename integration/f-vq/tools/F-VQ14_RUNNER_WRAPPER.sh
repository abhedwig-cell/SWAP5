#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SOURCE="$ROOT/tests/fvq/run_fvq14_gate.sh"
EFFECTIVE="$ROOT/tests/fvq/.fvq14_gate_effective.sh"

python3 - "$SOURCE" "$EFFECTIVE" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1])
out = Path(sys.argv[2])
text = src.read_text(encoding="utf-8")
old = '  local opt="$1" mode="$2" outdir="$RESULTS/build_${mode}_o${opt}"\n'
new = ('  local opt="$1"\n'
       '  local mode="$2"\n'
       '  local outdir="$RESULTS/build_${mode}_o${opt}"\n')
count = text.count(old)
if count != 1:
    raise SystemExit(f"F-VQ14 runner patch refused: expected exactly one target, found {count}")
out.write_text(text.replace(old, new), encoding="utf-8")
PY

trap 'rm -f "$EFFECTIVE"' EXIT
bash "$EFFECTIVE" "$@"
