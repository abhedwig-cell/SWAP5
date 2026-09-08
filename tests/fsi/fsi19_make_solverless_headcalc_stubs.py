#!/usr/bin/env python3
from pathlib import Path
import re
import sys

if len(sys.argv) != 3:
    raise SystemExit('usage: fsi19_make_solverless_headcalc_stubs.py INPUT OUTPUT')

src_path = Path(sys.argv[1])
out_path = Path(sys.argv[2])
src = src_path.read_text(encoding='utf-8')
expected_sha = '23c00e4a188e88bc36ef95cbe4faaacdd6aad639'
import hashlib
actual_sha = hashlib.sha1(src.encode('utf-8')).hexdigest()
if actual_sha != expected_sha:
    raise SystemExit(f'FSI19 support fixture blob drift {actual_sha} != {expected_sha}')

for name in ('tridag', 'bandec', 'banbks'):
    pattern = re.compile(
        rf'(?ims)^subroutine\s+{name}\b.*?^end\s+subroutine\s+{name}\s*\n'
    )
    matches = list(pattern.finditer(src))
    if len(matches) != 1:
        raise SystemExit(f'FSI19 expected one {name} support routine, found {len(matches)}')
    src = pattern.sub('', src, count=1)

for forbidden in ('subroutine tridag', 'subroutine bandec', 'subroutine banbks'):
    if forbidden in src.lower():
        raise SystemExit(f'FSI19 solver support routine remains: {forbidden}')

out_path.write_text(src, encoding='utf-8')
print('FSI19_SOLVERLESS_SUPPORT_FIXTURE=PASS')
print('FSI19_REMOVED_EXTERNAL_LINEAR_SOLVERS=tridag,bandec,banbks')
