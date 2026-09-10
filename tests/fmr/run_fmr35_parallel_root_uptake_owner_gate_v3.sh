#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$ROOT/tests/fmr/.fmr35-owner-v3-$$.sh"
trap 'rm -f "$TMP"' EXIT
cp "$ROOT/tests/fmr/run_fmr35_parallel_root_uptake_owner_gate.sh" "$TMP"
python3 - "$TMP" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
old='CANDIDATE=040e34dfb169058932583431052e471dd10bd8cc\n'
new='CANDIDATE=6b9e47df37513705d3db13edc2c7035526c9c0de\n'
if s.count(old) != 1: raise SystemExit('FMR35 v3: candidate pin token mismatch')
s=s.replace(old,new,1)
old="""one('program test_fmq26_parallel_v1_admission','program test_fmr35_parallel_root_uptake','program')
one('end program test_fmq26_parallel_v1_admission','end program test_fmr35_parallel_root_uptake','end program')
"""
new="""one('end program test_fmq26_parallel_v1_admission','end program test_fmr35_parallel_root_uptake','end program')
one('program test_fmq26_parallel_v1_admission','program test_fmr35_parallel_root_uptake','program')
"""
if s.count(old) != 1: raise SystemExit('FMR35 v3: derivation matcher patch token mismatch')
s=s.replace(old,new,1)
p.write_text(s)
PY
bash "$TMP"
