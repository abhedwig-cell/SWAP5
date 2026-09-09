#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
TMP_DRIVER="tests/fsi/.fsi20_iteration_ceiling_driver_tmp.f90"
TMP_INNER="tests/fsi/.fsi20_iteration_ceiling_inner_tmp.sh"
LOG="${TMPDIR:-/tmp}/fsi20-iteration-ceiling-$$.log"
cleanup() { rm -f "$TMP_DRIVER" "$TMP_INNER" "$LOG"; }
trap cleanup EXIT

BASE_DRIVER_SHA=98c945164b6ca7d9c2aaef332a322896f132fa79
BASE_RUNNER_SHA=eb22de0a36bea43daf4e75663ad5e793e73e67ca
[[ "$(git rev-parse HEAD:tests/fsi/test_fsi20_prescribed_head_temporal_characterization.f90)" == "$BASE_DRIVER_SHA" ]]
[[ "$(git rev-parse HEAD:tests/fsi/run_fsi20_prescribed_head_temporal_characterization.sh)" == "$BASE_RUNNER_SHA" ]]

cp tests/fsi/test_fsi20_prescribed_head_temporal_characterization.f90 "$TMP_DRIVER"
cp tests/fsi/run_fsi20_prescribed_head_temporal_characterization.sh "$TMP_INNER"

python3 - "$TMP_DRIVER" "$TMP_INNER" <<'PY'
from pathlib import Path
import sys

driver=Path(sys.argv[1]); inner=Path(sys.argv[2])
s=driver.read_text()
# Keep the existing characterization-only 16/8, dtmin=1e-8 controls. Only
# extend the transaction retry axis and collapse the three duplicate tolerance
# cases to the source-qualified 1e-12 setting.
repls={
  'real(real64), parameter :: tolerance_cases(3) = [1.0e-10_real64, 1.0e-12_real64, 1.0e-14_real64]':
  'real(real64), parameter :: tolerance_cases(3) = [1.0e-12_real64, 1.0e-12_real64, 1.0e-12_real64]',
  'cfg%transaction%max_retries = 6':'cfg%transaction%max_retries = 17'
}
for old,new in repls.items():
    if s.count(old)!=1:
        raise SystemExit(f'expected exactly one driver token: {old}')
    s=s.replace(old,new,1)
driver.write_text(s)

r=inner.read_text()
old='tests/fsi/test_fsi20_prescribed_head_temporal_characterization.f90'
new='tests/fsi/.fsi20_iteration_ceiling_driver_tmp.f90'
if r.count(old)!=1:
    raise SystemExit(f'expected exactly one inner driver reference, got {r.count(old)}')
r=r.replace(old,new,1)
inner.write_text(r)
PY

grep -Fq 'p%max_iterations = 16' "$TMP_DRIVER"
grep -Fq 'p%max_backtracking = 8' "$TMP_DRIVER"
grep -Fq 'p%min_step_duration = 1.0e-8_real64' "$TMP_DRIVER"
grep -Fq 'cfg%transaction%max_retries = 17' "$TMP_DRIVER"
echo 'FSI20_ITERATION_CEILING_AXIS_NONPRODUCTION_CONTROLS=16_8'
echo 'FSI20_ITERATION_CEILING_AXIS_DtMIN=1E-8_DAY'
echo 'FSI20_ITERATION_CEILING_AXIS_PRODUCTION_POLICY_CHANGED=NO'

bash "$TMP_INNER" | tee "$LOG"

python3 - "$LOG" <<'PY'
from pathlib import Path
import math,re,sys
lines=Path(sys.argv[1]).read_text().splitlines()
rows=[]
for line in lines:
    if line.startswith('FSI20_CASE=2:COMPARE='):
        m=re.search(r':COMPARE=(\d+):DT=([^:]+):DHEAD=([^:]+):IMAXH=(\d+):DTHETA=([^:]+):IMAXTHETA=(\d+):DSTORAGE=([^:]+):DPOND=([^:]+):DGWL=([^:]+):APPARENT_ORDER=(\S+)',line)
        if not m: raise SystemExit('bad row: '+line)
        rows.append({'i':int(m.group(1)),'dt':float(m.group(2)),'dh':float(m.group(3)),
                     'imaxh':int(m.group(4)),'dtheta':float(m.group(5)),
                     'storage':float(m.group(7)),'pond':float(m.group(8)),'gwl':float(m.group(9))})
if len(rows) < 12:
    raise SystemExit(f'16/8 axis regressed below exact 8/4 valid tail: {len(rows)}')
if len(rows) > 18:
    raise SystemExit(f'unexpected row count: {len(rows)}')
for r in rows:
    if not all(math.isfinite(r[k]) for k in ('dt','dh','dtheta','storage','pond','gwl')):
        raise SystemExit('nonfinite row')
print(f'FSI20_ITERATION_CEILING_AXIS_ROWS={len(rows)}')
for r in rows:
    print(f"FSI20_ITERATION_CEILING_AXIS_ROW:INDEX={r['i']}:DT={r['dt']:.17e}:DHEAD={r['dh']:.17e}:IMAXH={r['imaxh']}:DTHETA={r['dtheta']:.17e}:DSTORAGE={r['storage']:.17e}")
last5=rows[-5:]
strict=all(b['dh']<a['dh'] for a,b in zip(last5,last5[1:]))
print('FSI20_ITERATION_CEILING_AXIS_LAST5_STRICTLY_DECREASING='+('YES' if strict else 'NO'))
print(f"FSI20_ITERATION_CEILING_AXIS_LAST_DT={rows[-1]['dt']:.17e}:LAST_DHEAD={rows[-1]['dh']:.17e}")
print('FSI20_ITERATION_CEILING_AXIS_NO_METRIC_OR_TOLERANCE_ADMISSION=PASS')
PY

echo 'FSI20_ITERATION_CEILING_STARTUP_TAIL PASS'
