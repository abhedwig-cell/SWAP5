#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
SOURCE="tests/fmr/run_fmr38_explicit_effective_forcing_owner_gate.sh"
PATCHED="tests/fmr/.run_fmr38_owner_gate_patched_$$.sh"
trap 'rm -f "$PATCHED"' EXIT

python3 - "$SOURCE" "$PATCHED" <<'PY'
from pathlib import Path
import re, sys
src, dst = map(Path, sys.argv[1:])
s = src.read_text()
old1 = "one('program test_fmq26_parallel_v1_admission','program test_fmr38_resolved_seam_identity','program')"
old2 = "one('end program test_fmq26_parallel_v1_admission','end program test_fmr38_resolved_seam_identity','end program')"
replacement = """def line(old,new,label):
    global s
    pattern=r'(?m)^'+re.escape(old)+r'$'
    s2,n=re.subn(pattern,new,s)
    if n != 1: raise SystemExit(f'{label}: expected one full line got {n}')
    s=s2
line('program test_fmq26_parallel_v1_admission','program test_fmr38_resolved_seam_identity','program line')
line('end program test_fmq26_parallel_v1_admission','end program test_fmr38_resolved_seam_identity','end program line')"""
if s.count(old1) != 1 or s.count(old2) != 1:
    raise SystemExit('FMR38 wrapper: historical matcher lines drifted')
s = s.replace(old1 + "\n" + old2, replacement, 1)
dst.write_text(s)
PY

chmod +x "$PATCHED"
echo 'FMR38_HARNESS_PROGRAM_MATCHER_ANCHORED=PASS'
bash "$PATCHED"
