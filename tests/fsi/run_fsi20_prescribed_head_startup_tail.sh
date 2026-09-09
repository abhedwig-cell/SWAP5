#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
TMP_DRIVER="tests/fsi/.fsi20_startup_tail_driver_tmp.f90"
TMP_INNER="tests/fsi/.fsi20_startup_tail_inner_tmp.sh"
LOG="${TMPDIR:-/tmp}/fsi20-startup-tail-$$.log"
cleanup() { rm -f "$TMP_DRIVER" "$TMP_INNER" "$LOG"; }
trap cleanup EXIT

cp tests/fsi/test_fsi20_prescribed_head_temporal_characterization.f90 "$TMP_DRIVER"
cp tests/fsi/run_fsi20_prescribed_head_temporal_characterization.sh "$TMP_INNER"

python3 - "$TMP_DRIVER" "$TMP_INNER" <<'PY'
from pathlib import Path
import sys

driver=Path(sys.argv[1]); inner=Path(sys.argv[2])
s=driver.read_text()
repls={
  'real(real64), parameter :: tolerance_cases(3) = [1.0e-10_real64, 1.0e-12_real64, 1.0e-14_real64]':
  'real(real64), parameter :: tolerance_cases(3) = [1.0e-12_real64, 1.0e-12_real64, 1.0e-12_real64]',
  'p%max_iterations = 16':'p%max_iterations = 8',
  'p%max_backtracking = 8':'p%max_backtracking = 4',
  'p%min_step_duration = 1.0e-8_real64':'p%min_step_duration = 1.0e-6_real64',
  'cfg%transaction%max_retries = 6':'cfg%transaction%max_retries = 17'
}
for old,new in repls.items():
    if s.count(old)!=1:
        raise SystemExit(f'expected exactly one driver token: {old}')
    s=s.replace(old,new,1)
driver.write_text(s)

r=inner.read_text()
old='tests/fsi/test_fsi20_prescribed_head_temporal_characterization.f90'
new='tests/fsi/.fsi20_startup_tail_driver_tmp.f90'
if r.count(old)!=1:
    raise SystemExit(f'expected exactly one inner driver reference, got {r.count(old)}')
r=r.replace(old,new,1)
inner.write_text(r)
PY

# Explicitly prove the temporary experiment uses the exact F-GC02 numerical controls.
grep -Fq 'p%max_iterations = 8' "$TMP_DRIVER"
grep -Fq 'p%max_backtracking = 4' "$TMP_DRIVER"
grep -Fq 'p%min_step_duration = 1.0e-6_real64' "$TMP_DRIVER"
grep -Fq 'cfg%transaction%max_retries = 17' "$TMP_DRIVER"
grep -Fq '1.0e-12_real64, 1.0e-12_real64, 1.0e-12_real64' "$TMP_DRIVER"
echo 'FSI20_STARTUP_TAIL_EXACT_FGC02_SOLVER_CONTROLS=PASS'
echo 'FSI20_STARTUP_TAIL_LAST_ADMISSIBLE_HALVING_TARGET=0.25/2^17_day'

bash "$TMP_INNER" | tee "$LOG"

python3 - "$LOG" <<'PY'
from pathlib import Path
import math,re,sys
lines=Path(sys.argv[1]).read_text().splitlines()
rows=[]
for line in lines:
    if line.startswith('FSI20_CASE=2:COMPARE='):
        m=re.search(r':COMPARE=(\d+):DT=([^:]+):DHEAD=([^:]+):IMAXH=(\d+):DTHETA=([^:]+):IMAXTHETA=(\d+):DSTORAGE=([^:]+):DPOND=([^:]+):DGWL=([^:]+):APPARENT_ORDER=(\S+)',line)
        if not m: raise SystemExit('bad startup-tail row: '+line)
        rows.append({
            'i':int(m.group(1)),'dt':float(m.group(2)),'dh':float(m.group(3)),'imaxh':int(m.group(4)),
            'dtc':float(m.group(5)),'imaxt':int(m.group(6)),'storage':float(m.group(7)),
            'pond':float(m.group(8)),'gwl':float(m.group(9))})
if not rows: raise SystemExit('no baseline startup-tail rows')
if any(not all(math.isfinite(r[k]) for k in ('dt','dh','dtc','storage','pond','gwl')) for r in rows):
    raise SystemExit('nonfinite startup-tail evidence')
if len(rows)>18: raise SystemExit('more rows than 0..17 retry ladder permits')
if rows[-1]['dt'] < 1.0e-6:
    raise SystemExit('startup-tail crossed exact F-GC02 dtmin')
if len(rows)==18:
    expected=0.25/(2**17)
    if abs(rows[-1]['dt']-expected) > 1e-15:
        raise SystemExit('unexpected final admissible halving')

minrow=min(rows,key=lambda r:r['dh'])
print(f'FSI20_STARTUP_TAIL_ROWS={len(rows)}')
print(f"FSI20_STARTUP_TAIL_FIRST:DT={rows[0]['dt']:.17e}:DHEAD={rows[0]['dh']:.17e}:IMAXH={rows[0]['imaxh']}")
print(f"FSI20_STARTUP_TAIL_LAST:DT={rows[-1]['dt']:.17e}:DHEAD={rows[-1]['dh']:.17e}:IMAXH={rows[-1]['imaxh']}")
print(f"FSI20_STARTUP_TAIL_MIN:DT={minrow['dt']:.17e}:DHEAD={minrow['dh']:.17e}:IMAXH={minrow['imaxh']}")

# Report local log2 slopes without requiring monotonicity.
for a,b in zip(rows,rows[1:]):
    p=float('nan')
    if a['dh']>0 and b['dh']>0:
        p=math.log(a['dh']/b['dh'],2)
    print(f"FSI20_STARTUP_TAIL_SLOPE:DT0={a['dt']:.17e}:DT1={b['dt']:.17e}:P={p:.17e}")

# Characterize, do not force, a possible late decay regime.
late=rows[-5:] if len(rows)>=5 else rows
strict_late=all(b['dh'] < a['dh'] for a,b in zip(late,late[1:]))
print('FSI20_STARTUP_TAIL_LAST5_STRICTLY_DECREASING='+('YES' if strict_late else 'NO'))
print('FSI20_STARTUP_TAIL_NONMONOTONE_ALLOWED=PASS')
print('FSI20_STARTUP_TAIL_PRODUCTION_METRIC_SELECTED=NO')
PY

echo 'FSI20_STARTUP_TAIL_PRODUCTION_ACCEPTANCE_CHANGED=NO'
echo 'FSI20_STARTUP_TAIL_MASS_REQUIREMENT_CHANGED=NO'
echo 'FSI20_PRESCRIBED_HEAD_STARTUP_TAIL PASS'
