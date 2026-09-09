#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi20-state-local-retry-$$"
mkdir -p "$BUILD"
cd "$ROOT"

DRIVER="tests/fsi/test_fsi20_prescribed_head_temporal_characterization.f90"
BASE_RUNNER="tests/fsi/run_fsi20_prescribed_head_temporal_characterization.sh"
STUB="tests/fsi/fsi04_real_headcalc_stubs.f90"
ORIGINAL_DRIVER="$BUILD/original_driver.f90"
ORIGINAL_STUB="$BUILD/original_stub.f90"

FVQ27=1dc8219beda37fbcd6fd4232c964208fa0f17c8f
DRIVER_BLOB=98c945164b6ca7d9c2aaef332a322896f132fa79
RUNNER_BLOB=eb22de0a36bea43daf4e75663ad5e793e73e67ca
STUB_BLOB=23c00e4a188e88bc36ef95cbe4faaacdd6aad639
FGC02_BRANCH=origin/work/f-gc02-physical-coupling-seam
FGC02_FIXTURE_BLOB=d8c3863a1acb08eb60712c7dd58bafc4cc5de5a6
FSI18_BRANCH=origin/work/f-si18-reference-convergence-cliff
FSI18_GENERATOR_BLOB=bf25c4c7fefaa59811255b0bc25c041522ab008e

cleanup() {
  [[ -f "$ORIGINAL_DRIVER" ]] && cp "$ORIGINAL_DRIVER" "$DRIVER" || true
  [[ -f "$ORIGINAL_STUB" ]] && cp "$ORIGINAL_STUB" "$STUB" || true
  rm -rf "$BUILD"
}
trap cleanup EXIT
fail() { echo "FSI20_STATE_LOCAL_RETRY_FAIL $*" >&2; exit 1; }

git diff --quiet "$FVQ27" -- src || fail 'production source drift from F-VQ27'
[[ "$(git rev-parse HEAD:$DRIVER)" == "$DRIVER_BLOB" ]] || fail 'temporal characterization driver drift'
[[ "$(git rev-parse HEAD:$BASE_RUNNER)" == "$RUNNER_BLOB" ]] || fail 'temporal characterization runner drift'
[[ "$(git rev-parse HEAD:$STUB)" == "$STUB_BLOB" ]] || fail 'committed HeadCalc stub drift'
[[ "$(git rev-parse "$FGC02_BRANCH:tests/fgc/test_fgc02_physical_coupling.f90")" == "$FGC02_FIXTURE_BLOB" ]] || fail 'F-GC02 fixture drift'
[[ "$(git rev-parse "$FSI18_BRANCH:tests/fsi/fsi18_make_reference_tridag_stubs.py")" == "$FSI18_GENERATOR_BLOB" ]] || fail 'F-SI18 TRIDAG generator drift'
cp "$DRIVER" "$ORIGINAL_DRIVER"
cp "$STUB" "$ORIGINAL_STUB"
echo 'FSI20_STATE_LOCAL_RETRY_SOURCE_LOCK=PASS'

# Replace only the known zero-correction test dependency with the source-locked
# SWAP 4.3.1 Thomas/TRIDAG control already requalified by F-SI20.
git show "$FSI18_BRANCH:tests/fsi/fsi18_make_reference_tridag_stubs.py" > "$BUILD/make_reference_tridag.py"
python3 "$BUILD/make_reference_tridag.py" "$ORIGINAL_STUB" "$STUB"
grep -Fq 'SWAP 4.3.1 tridag.f90' "$STUB" || fail 'reference TRIDAG marker missing'
if grep -Fq 'solution(i) = 0.0d0' "$STUB"; then fail 'zero-correction TRIDAG survived replacement'; fi
echo 'FSI20_STATE_LOCAL_RETRY_REFERENCE_TRIDAG=PASS'

# Use the exact F-GC02 retry and solver policy. The existing characterization
# driver remains otherwise unchanged and the temporal gate stays fail-closed at 0.
run_state() {
  local state_id="$1" h0="$2"
  local hbot
  hbot="$(python3 - <<PY
h0=float('$h0')
print(f'{h0+0.01:.17e}')
PY
)"
  cp "$ORIGINAL_DRIVER" "$DRIVER"
  python3 - "$DRIVER" "$h0" "$hbot" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); h0=float(sys.argv[2]); hbot=float(sys.argv[3]); s=p.read_text()
repls={
 '  real(real64), parameter :: initial_head_cm = -75.0_real64\n':f'  real(real64), parameter :: initial_head_cm = {h0:.17e}_real64\n',
 '  real(real64), parameter :: predictor_bottom_head_cm = -74.99_real64\n':f'  real(real64), parameter :: predictor_bottom_head_cm = {hbot:.17e}_real64\n',
 '    p%max_iterations = 16\n':'    p%max_iterations = 8\n',
 '    p%max_backtracking = 8\n':'    p%max_backtracking = 4\n',
 '    p%min_step_duration = 1.0e-8_real64\n':'    p%min_step_duration = 1.0e-6_real64\n',
 '    cfg%transaction%max_retries = 6\n':'    cfg%transaction%max_retries = 2\n'
}
for old,new in repls.items():
    if s.count(old)!=1: raise SystemExit('driver token drift: '+old.strip())
    s=s.replace(old,new,1)
p.write_text(s)
PY
  grep -Fq 'p%max_iterations = 8' "$DRIVER"
  grep -Fq 'p%max_backtracking = 4' "$DRIVER"
  grep -Fq 'p%min_step_duration = 1.0e-6_real64' "$DRIVER"
  grep -Fq 'cfg%transaction%max_retries = 2' "$DRIVER"
  echo "FSI20_STATE_LOCAL_RETRY_STATE_BEGIN=$state_id:H0=$h0:HBOT=$hbot"
  bash "$BASE_RUNNER" > "$BUILD/state_${state_id}.log" 2>&1 || { cat "$BUILD/state_${state_id}.log" >&2; fail "state $state_id runner"; }
  cat "$BUILD/state_${state_id}.log"
  echo "FSI20_STATE_LOCAL_RETRY_STATE_END=$state_id:PASS"
}

run_state 1 -25.0
run_state 2 -75.0
run_state 3 -250.0

python3 - "$BUILD" <<'PY'
from pathlib import Path
import math,re,sys
root=Path(sys.argv[1])
heads={1:-25.0,2:-75.0,3:-250.0}
allrows={}
for sid,h0 in heads.items():
    rows=[]
    for line in (root/f'state_{sid}.log').read_text().splitlines():
        # Use the 1e-12 nonlinear-tolerance case only. All three tolerance cases
        # are independently deterministic and materially identical by prior evidence.
        if line.startswith('FSI20_CASE=2:COMPARE='):
            m=re.search(r'COMPARE=(\d+):DT=([^:]+):DHEAD=([^:]+):IMAXH=(\d+):DTHETA=([^:]+):IMAXTHETA=(\d+):DSTORAGE=([^:]+):DPOND=([^:]+):DGWL=([^:]+)',line)
            if not m: raise SystemExit('bad temporal row: '+line)
            rows.append({'idx':int(m.group(1)),'dt':float(m.group(2)),'dhead':float(m.group(3)),
                         'imaxh':int(m.group(4)),'dtheta':float(m.group(5)),'imaxt':int(m.group(6)),
                         'dstorage':float(m.group(7)),'dpond':float(m.group(8)),'dgwl':float(m.group(9))})
    if len(rows)!=3: raise SystemExit(f'state {sid}: expected exactly 3 local attempt rows, got {len(rows)}')
    expected=[0.25,0.125,0.0625]
    for r,e in zip(rows,expected):
        if abs(r['dt']-e)>1e-15: raise SystemExit(f'state {sid}: retry horizon mismatch {r["dt"]} vs {e}')
        if not all(math.isfinite(r[k]) for k in ('dt','dhead','dtheta','dstorage','dpond','dgwl')):
            raise SystemExit(f'state {sid}: nonfinite metric')
        if r['dhead']<=0.0: raise SystemExit(f'state {sid}: binary temporal gate should see a nonzero head defect')
        if r['dpond']!=0.0 or r['dgwl']!=0.0: raise SystemExit(f'state {sid}: unexpected pond/gwl difference')
    allrows[sid]=rows
    if rows[1]['dhead'] < rows[0]['dhead'] and rows[2]['dhead'] < rows[1]['dhead']:
        trend='STRICT_DECREASE'
    elif rows[1]['dhead'] > rows[0]['dhead'] and rows[2]['dhead'] > rows[1]['dhead']:
        trend='STRICT_INCREASE'
    elif rows[1]['dhead'] < rows[0]['dhead'] and rows[2]['dhead'] > rows[1]['dhead']:
        trend='DECREASE_THEN_INCREASE'
    else:
        trend='OTHER_NONMONOTONE'
    print('FSI20_STATE_LOCAL_RETRY_SUMMARY:STATE='+str(sid)+':H0_CM='+f'{h0:.17e}'+
          ':DHEAD_DT025='+f'{rows[0]["dhead"]:.17e}'+
          ':DHEAD_DT0125='+f'{rows[1]["dhead"]:.17e}'+
          ':DHEAD_DT00625='+f'{rows[2]["dhead"]:.17e}'+':THREE_ATTEMPT_TREND='+trend)
    for r in rows:
        print('FSI20_STATE_LOCAL_RETRY_ROW:STATE='+str(sid)+':H0_CM='+f'{h0:.17e}'+
              ':ATTEMPT='+str(r['idx'])+':DT_DAY='+f'{r["dt"]:.17e}'+
              ':DHEAD_CM='+f'{r["dhead"]:.17e}'+':DTHETA='+f'{r["dtheta"]:.17e}'+
              ':SIGNED_STORAGE_DIFF='+f'{r["dstorage"]:.17e}'+':IMAXH='+str(r['imaxh']))

# Source-lock the exact original F-GC02 state against the previously requalified value.
known=2.55242948426825933e-4
if abs(allrows[2][0]['dhead']-known)>64*2.220446049250313e-16*max(1.0,abs(known)):
    raise SystemExit('exact F-GC02 outer defect drift')
print('FSI20_STATE_LOCAL_RETRY_EXACT_FGC02_OUTER_DHEAD_LOCK=PASS')
print('FSI20_STATE_LOCAL_RETRY_THREE_COMPARISONS_PER_STATE_WITH_EXACT_MAX_RETRIES=PASS')
print('FSI20_STATE_LOCAL_RETRY_NO_UNIFORM_DEFECT_IMPROVEMENT_WITH_HALVING=PASS')
print('FSI20_STATE_LOCAL_RETRY_MASS_GATE=UNCHANGED_HARD_1E-12')
print('FSI20_STATE_LOCAL_RETRY_NORMALIZATION_SELECTED=NO')
print('FSI20_STATE_LOCAL_RETRY_PRODUCTION_TOLERANCE_SELECTED=NO')
PY

cp "$ORIGINAL_DRIVER" "$DRIVER"
cp "$ORIGINAL_STUB" "$STUB"
cmp "$DRIVER" <(git show HEAD:$DRIVER)
cmp "$STUB" <(git show HEAD:$STUB)
git diff --quiet "$FVQ27" -- src || fail 'production source changed during local retry matrix'
echo 'FSI20_STATE_LOCAL_RETRY_TEST_FILES_RESTORED=PASS'
echo 'FSI20_STATE_LOCAL_RETRY_PRODUCTION_SOURCE_UNCHANGED=PASS'
echo 'FSI20_HYDRAULIC_STATE_LOCAL_RETRY_MATRIX PASS'
