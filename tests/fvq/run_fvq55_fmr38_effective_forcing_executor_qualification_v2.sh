#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DERIVED="$HERE/.fvq55-derived-runner.sh"
cp "$HERE/run_fvq55_fmr38_effective_forcing_executor_qualification.sh" "$DERIVED"
trap 'rm -f "$DERIVED"' EXIT

python3 - "$DERIVED" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
old="one('program test_fmq26_parallel_v1_admission','program test_fvq55_effective_forcing_executor','program')"
new="s=s.replace('program test_fmq26_parallel_v1_admission','program test_fvq55_effective_forcing_executor',1)"
if s.count(old) != 1:
    raise SystemExit(f'FVQ55 wrapper expected one faulty program rename, found {s.count(old)}')
s=s.replace(old,new,1)
p.write_text(s)
PY

bash "$DERIVED"
