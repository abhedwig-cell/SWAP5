from pathlib import Path
import re
import sys

src = Path(sys.argv[1])
dst = Path(sys.argv[2])
s = src.read_text(encoding='utf-8')

# Historical EB-I01/I20R/I20R1 fixtures predate the explicit owner-instance
# argument.  Preserve their original semantics by giving every begin_trial
# call in the copied fixture one deterministic logical owner token.  This
# adapter is test-only; production callers must provide their own positive,
# live-owner-unique token explicitly.
pattern = re.compile(r'(call\s+[A-Za-z0-9_]+%begin_trial\()')
s, count = pattern.subn(r'\g<1>8202001_int64, ', s)
if count < 1:
    raise SystemExit('EB-I20R2 fixture contains no begin_trial call')

# All relevant fixtures already import int64 after their current-canonical
# normalization, except simple owner tests which do so natively.
if 'int64' not in s:
    raise SystemExit('EB-I20R2 fixture lacks int64 import')

dst.write_text(s, encoding='utf-8')
print(f'EB_I20R2_FIXTURE_BEGIN_TRIAL_CALLS_NORMALIZED={count}')
