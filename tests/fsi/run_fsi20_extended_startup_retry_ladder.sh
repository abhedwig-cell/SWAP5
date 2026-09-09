#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi20-extended-startup-$$"
mkdir -p "$BUILD"
DRIVER="$ROOT/tests/fsi/test_fsi20_prescribed_head_temporal_characterization.f90"
BASE_RUNNER="$ROOT/tests/fsi/run_fsi20_prescribed_head_temporal_characterization.sh"
ORIGINAL_DRIVER="$BUILD/original-driver.f90"
ORIGINAL_RUNNER="$BUILD/original-runner.sh"
LOG="$BUILD/extended.log"
trap 'cp "$ORIGINAL_DRIVER" "$DRIVER" 2>/dev/null || true; cp "$ORIGINAL_RUNNER" "$BASE_RUNNER" 2>/dev/null || true; rm -rf "$BUILD"' EXIT
cd "$ROOT"

EXPECTED_DRIVER_BLOB=98c945164b6ca7d9c2aaef332a322896f132fa79
EXPECTED_RUNNER_BLOB=eb22de0a36bea43daf4e75663ad5e793e73e67ca
FGC02_BRANCH=origin/work/f-gc02-physical-coupling-seam
FGC02_FIXTURE_BLOB=d8c3863a1acb08eb60712c7dd58bafc4cc5de5a6

fail() { echo "FSI20_EXTENDED_STARTUP_FAIL $*" >&2; exit 1; }
[[ "$(git rev-parse HEAD:tests/fsi/test_fsi20_prescribed_head_temporal_characterization.f90)" == "$EXPECTED_DRIVER_BLOB" ]] || fail 'base characterization driver drift'
[[ "$(git rev-parse HEAD:tests/fsi/run_fsi20_prescribed_head_temporal_characterization.sh)" == "$EXPECTED_RUNNER_BLOB" ]] || fail 'base characterization runner drift'
[[ "$(git rev-parse "$FGC02_BRANCH:tests/fgc/test_fgc02_physical_coupling.f90")" == "$FGC02_FIXTURE_BLOB" ]] || fail 'F-GC02 fixture drift'
cp "$DRIVER" "$ORIGINAL_DRIVER"
cp "$BASE_RUNNER" "$ORIGINAL_RUNNER"

python3 - "$DRIVER" "$BASE_RUNNER" <<'PY'
from pathlib import Path
import sys
driver=Path(sys.argv[1]); s=driver.read_text()
replacements={
    '    p%max_iterations = 16\n':'    p%max_iterations = 8\n',
    '    p%max_backtracking = 8\n':'    p%max_backtracking = 4\n',
    '    p%min_step_duration = 1.0e-8_real64\n':'    p%min_step_duration = 1.0e-6_real64\n',
    '    cfg%transaction%max_retries = 6\n':'    cfg%transaction%max_retries = 16\n',
}
for old,new in replacements.items():
    if s.count(old)!=1:
        raise SystemExit(f'expected exactly one driver patch target: {old.strip()}')
    s=s.replace(old,new,1)
driver.write_text(s)
runner=Path(sys.argv[2]); r=runner.read_text()
old='''    print(f"FSI20_CASE={cid}:NONLINEAR_TOL={c['tol']:.17e}:TEMPORAL_COMPARISONS={len(c['rows'])}")\n    previous=None\n'''
new='''    print(f"FSI20_CASE={cid}:NONLINEAR_TOL={c['tol']:.17e}:TEMPORAL_COMPARISONS={len(c['rows'])}")\n    print('FSI20_EXTENDED_RAW_CASE_END='+str(c['end']))\n    previous=None\n'''
if r.count(old)!=1:
    raise SystemExit('expected exactly one runner diagnostics patch target')
r=r.replace(old,new,1)
runner.write_text(r)
print('FSI20_EXTENDED_STARTUP_EPHEMERAL_HARNESS_PATCH=PASS')
PY

grep -Fq 'p%max_iterations = 8' "$DRIVER"
grep -Fq 'p%max_backtracking = 4' "$DRIVER"
grep -Fq 'p%min_step_duration = 1.0e-6_real64' "$DRIVER"
grep -Fq 'cfg%transaction%max_retries = 16' "$DRIVER"
echo 'FSI20_EXTENDED_STARTUP_EXACT_FGC02_SOLVER_CONTROLS=PASS'
echo 'FSI20_EXTENDED_STARTUP_NONPRODUCTION_MAX_RETRIES=16'

bash "$BASE_RUNNER" | tee "$LOG"

python3 - "$LOG" <<'PY'
from pathlib import Path
import math,re,sys
lines=Path(sys.argv[1]).read_text().splitlines()
rows={1:[],2:[],3:[]}; ends={}
for line in lines:
    m=re.match(r'FSI20_CASE=(\d+):COMPARE=(\d+):DT=([^:]+):DHEAD=([^:]+):IMAXH=(\d+):DTHETA=([^:]+):IMAXTHETA=(\d+):DSTORAGE=([^:]+):DPOND=([^:]+):DGWL=([^:]+):APPARENT_ORDER=(.+)',line)
    if m:
        cid=int(m.group(1))
        if cid not in rows: raise SystemExit(f'unexpected case {cid}')
        rows[cid].append({'j':int(m.group(2)),'dt':float(m.group(3)),'dh':float(m.group(4)),'ih':int(m.group(5)),
            'dtheta':float(m.group(6)),'it':int(m.group(7)),'storage':float(m.group(8)),
            'pond':float(m.group(9)),'gwl':float(m.group(10)),'order':m.group(11)})
        continue
    if line.startswith('FSI20_EXTENDED_RAW_CASE_END=FSI20_CASE_END='):
        raw=line.split('=',1)[1]
        m2=re.match(r'FSI20_CASE_END=(\d+):STATUS=(\d+):COMPLETED=([TF]):ATTEMPTS=(\d+):RETRIES=(\d+):SOLVER_REJECTIONS=(\d+):TEMPORAL_REJECTIONS=(\d+):MASS_REJECTIONS=(\d+):ACCEPTED_SUBSTEPS=(\d+)',raw)
        if not m2: raise SystemExit(f'bad case-end diagnostics: {raw}')
        ends[int(m2.group(1))]={
            'status':int(m2.group(2)),'completed':m2.group(3)=='T','attempts':int(m2.group(4)),
            'retries':int(m2.group(5)),'solver':int(m2.group(6)),'temporal':int(m2.group(7)),
            'mass':int(m2.group(8)),'accepted':int(m2.group(9))}
if set(ends)!={1,2,3}: raise SystemExit(f'missing case-end diagnostics {ends}')
counts={len(v) for v in rows.values()}
if len(counts)!=1: raise SystemExit(f'tolerance cases terminate at different comparison counts {counts}')
count=next(iter(counts))
if count<7: raise SystemExit(f'extended ladder regressed below original seven comparisons: {count}')
for cid,r in rows.items():
    if abs(r[0]['dt']-0.25)>1e-15: raise SystemExit('unexpected initial dt')
    for x in r:
        if not all(math.isfinite(v) for v in (x['dt'],x['dh'],x['dtheta'],x['storage'],x['pond'],x['gwl'])):
            raise SystemExit('nonfinite extended row')
        if x['pond']!=0.0 or x['gwl']!=0.0: raise SystemExit('unexpected ponding/GWL delta on locked fixture')
base=rows[2]
minrow=min(base,key=lambda x:x['dh']); last=base[-1]
monotone_tail=1
for length in range(2,len(base)+1):
    tail=base[-length:]
    if all(tail[i+1]['dh'] < tail[i]['dh'] for i in range(len(tail)-1)):
        monotone_tail=length
    else:
        break
print(f'FSI20_EXTENDED_STARTUP_BASELINE_ROWS={count}')
for cid in (1,2,3):
    e=ends[cid]
    print(f"FSI20_EXTENDED_STARTUP_CASE_END:CASE={cid}:STATUS={e['status']}:COMPLETED={str(e['completed']).upper()}:ATTEMPTS={e['attempts']}:RETRIES={e['retries']}:SOLVER_REJECTIONS={e['solver']}:TEMPORAL_REJECTIONS={e['temporal']}:MASS_REJECTIONS={e['mass']}:ACCEPTED_SUBSTEPS={e['accepted']}")
for x in base:
    print(f"FSI20_EXTENDED_STARTUP_ROW:INDEX={x['j']}:DT={x['dt']:.17e}:DHEAD={x['dh']:.17e}:IMAXH={x['ih']}:DTHETA={x['dtheta']:.17e}:DSTORAGE={x['storage']:.17e}:APPARENT_ORDER={x['order']}")
print(f"FSI20_EXTENDED_STARTUP_MIN_DHEAD={minrow['dh']:.17e}:AT_DT={minrow['dt']:.17e}")
print(f"FSI20_EXTENDED_STARTUP_FINAL_DHEAD={last['dh']:.17e}:FINAL_DT={last['dt']:.17e}")
print(f'FSI20_EXTENDED_STARTUP_STRICT_MONOTONE_SUFFIX_LENGTH={monotone_tail}')
print('FSI20_EXTENDED_STARTUP_FINAL_OVER_INITIAL_DHEAD='+f"{last['dh']/base[0]['dh']:.17e}")
for j in range(count):
    vals=[rows[c][j]['dh'] for c in (1,2,3)]
    spread=max(vals)-min(vals)
    print(f"FSI20_EXTENDED_STARTUP_TOLERANCE_SPREAD:INDEX={j+1}:DT={rows[2][j]['dt']:.17e}:ABS_DHEAD_SPREAD={spread:.17e}")
if ends[2]['mass']!=0: raise SystemExit('hard mass rejection appeared in extended baseline')
print('FSI20_EXTENDED_STARTUP_EARLY_TERMINATION_IS_EVIDENCE=PASS')
print('FSI20_EXTENDED_STARTUP_NONMONOTONE_ALLOWED=PASS')
print('FSI20_EXTENDED_STARTUP_NO_PRODUCTION_METRIC_SELECTED=PASS')
PY

cmp "$ORIGINAL_DRIVER" <(git show HEAD:tests/fsi/test_fsi20_prescribed_head_temporal_characterization.f90)
cmp "$ORIGINAL_RUNNER" <(git show HEAD:tests/fsi/run_fsi20_prescribed_head_temporal_characterization.sh)
echo 'FSI20_EXTENDED_STARTUP_COMMITTED_BASE_HARNESS_UNCHANGED=PASS'
echo 'FSI20_EXTENDED_STARTUP_LADDER PASS'
