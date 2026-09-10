#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$ROOT/tests/fmq/.fmq30-v2-$$.sh"
trap 'rm -f "$TMP"' EXIT
cp "$ROOT/tests/fmq/run_fmq30_parallel_root_uptake_qualification.sh" "$TMP"
python3 - "$TMP" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
old="""one('program test_fmq26_parallel_v1_admission','program test_fmq30_parallel_root_uptake','program')
one('end program test_fmq26_parallel_v1_admission','end program test_fmq30_parallel_root_uptake','end program')
"""
new="""one('end program test_fmq26_parallel_v1_admission','end program test_fmq30_parallel_root_uptake','end program')
one('program test_fmq26_parallel_v1_admission','program test_fmq30_parallel_root_uptake','program')
"""
if s.count(old) != 1:
    raise SystemExit('FMQ30 v2: program/end-program matcher patch token mismatch')
s=s.replace(old,new,1)
p.write_text(s)
PY
bash "$TMP"
