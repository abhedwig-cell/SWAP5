#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi20-solver-rejection-$$"
mkdir -p "$BUILD"
DRIVER="$ROOT/tests/fsi/test_fsi20_prescribed_head_temporal_characterization.f90"
BASE_RUNNER="$ROOT/tests/fsi/run_fsi20_prescribed_head_temporal_characterization.sh"
HEADCALC="$ROOT/src/legacy/b1_10_port/headcalc.f90"
ORIGINAL_DRIVER="$BUILD/original-driver.f90"
ORIGINAL_RUNNER="$BUILD/original-runner.sh"
PROBE_HEADCALC="$BUILD/headcalc_fsi20_solver_probe.f90"
LOG="$BUILD/classification.log"
trap 'cp "$ORIGINAL_DRIVER" "$DRIVER" 2>/dev/null || true; cp "$ORIGINAL_RUNNER" "$BASE_RUNNER" 2>/dev/null || true; rm -rf "$BUILD"' EXIT
cd "$ROOT"

FVQ27=1dc8219beda37fbcd6fd4232c964208fa0f17c8f
EXPECTED_DRIVER_BLOB=98c945164b6ca7d9c2aaef332a322896f132fa79
EXPECTED_RUNNER_BLOB=eb22de0a36bea43daf4e75663ad5e793e73e67ca
FGC02_BRANCH=origin/work/f-gc02-physical-coupling-seam
FGC02_FIXTURE_BLOB=d8c3863a1acb08eb60712c7dd58bafc4cc5de5a6

fail() { echo "FSI20_SOLVER_REJECTION_FAIL $*" >&2; exit 1; }
[[ "$(git rev-parse HEAD:tests/fsi/test_fsi20_prescribed_head_temporal_characterization.f90)" == "$EXPECTED_DRIVER_BLOB" ]] || fail 'base driver drift'
[[ "$(git rev-parse HEAD:tests/fsi/run_fsi20_prescribed_head_temporal_characterization.sh)" == "$EXPECTED_RUNNER_BLOB" ]] || fail 'base runner drift'
[[ "$(git rev-parse "$FGC02_BRANCH:tests/fgc/test_fgc02_physical_coupling.f90")" == "$FGC02_FIXTURE_BLOB" ]] || fail 'F-GC02 fixture drift'
[[ "$(git rev-parse HEAD:src/legacy/b1_10_port/headcalc.f90)" == "$(git rev-parse "$FVQ27:src/legacy/b1_10_port/headcalc.f90")" ]] || fail 'production HeadCalc drift from F-VQ27'
[[ "$(git rev-parse HEAD:src/adapter/mod_reference_richards_legacy_binding.f90)" == "$(git rev-parse "$FVQ27:src/adapter/mod_reference_richards_legacy_binding.f90")" ]] || fail 'production legacy binding drift from F-VQ27'
cp "$DRIVER" "$ORIGINAL_DRIVER"
cp "$BASE_RUNNER" "$ORIGINAL_RUNNER"
cp "$HEADCALC" "$PROBE_HEADCALC"
echo 'FSI20_SOLVER_REJECTION_SOURCE_LOCK=PASS'

python3 - "$DRIVER" "$BASE_RUNNER" "$PROBE_HEADCALC" <<'PY'
from pathlib import Path
import sys

driver=Path(sys.argv[1]); s=driver.read_text()
for old,new in {
    '    p%max_iterations = 16\n':'    p%max_iterations = 8\n',
    '    p%max_backtracking = 8\n':'    p%max_backtracking = 4\n',
    '    p%min_step_duration = 1.0e-8_real64\n':'    p%min_step_duration = 1.0e-6_real64\n',
    '    cfg%transaction%max_retries = 6\n':'    cfg%transaction%max_retries = 16\n',
}.items():
    if s.count(old)!=1:
        raise SystemExit(f'expected one driver target: {old.strip()}')
    s=s.replace(old,new,1)
driver.write_text(s)

headcalc=Path(sys.argv[3]); h=headcalc.read_text()
old='''   real(8)                          :: factmax, factmax1, sump, sum1, sumold, deviat, q1\n'''
new='''   real(8)                          :: factmax, factmax1, sump, sum1, sumold, deviat, q1\n   real(8)                          :: fsi20_diag_balance_ratio, fsi20_diag_total_ratio, fsi20_diag_head_ratio\n'''
if h.count(old)!=1:
    raise SystemExit('expected one HeadCalc declaration target')
h=h.replace(old,new,1)
old='''!  Convergence could not been reached\n   if (.NOT.fldtmin) then\n'''
new='''!  Convergence could not been reached\n   fsi20_diag_balance_ratio = maxval(dabs(fsi_ws%residual(1:NN))) / max(CritDevBalCp,tiny(1.0d0))\n   fsi20_diag_total_ratio = dabs(sum(fsi_ws%residual(1:NN))) / max(CritDevBalTot,tiny(1.0d0))\n   fsi20_diag_head_ratio = 0.0d0\n   do i = 1, NN\n      if (dabs(fsi_ws%old_head(i)) < 1.0d0) then\n         fsi20_diag_head_ratio = max(fsi20_diag_head_ratio, &\n              dabs(state%h(i)-fsi_ws%old_head(i)) / max(CritDevh2Cp,tiny(1.0d0)))\n      else\n         fsi20_diag_head_ratio = max(fsi20_diag_head_ratio, &\n              (dabs(state%h(i)-fsi_ws%old_head(i))/dabs(fsi_ws%old_head(i))) / max(CritDevh1Cp,tiny(1.0d0)))\n      end if\n   end do\n   write(*,'(A,1X,ES26.17E3,4(1X,I0),3(1X,ES26.17E3))') 'FSI20_SOLVER_EXHAUSTION', dt, &\n        ctx%diagnostics%nonlinear_iterations, state%numbit, count(fsi_ws%nonconverged_balance(1:NN)), &\n        count(fsi_ws%nonconverged_head(1:NN)), fsi20_diag_balance_ratio, fsi20_diag_total_ratio, fsi20_diag_head_ratio\n   if (.NOT.fldtmin) then\n'''
if h.count(old)!=1:
    raise SystemExit('expected one HeadCalc exhaustion target')
h=h.replace(old,new,1)
headcalc.write_text(h)

runner=Path(sys.argv[2]); r=runner.read_text()
old='  src/legacy/b1_10_port/headcalc.f90\n'
new='  '+str(headcalc)+'\n'
if r.count(old)!=1:
    raise SystemExit('expected one runner HeadCalc source target')
r=r.replace(old,new,1)
runner.write_text(r)
print('FSI20_SOLVER_REJECTION_EPHEMERAL_PROBE=PASS')
PY

grep -Fq 'p%max_iterations = 8' "$DRIVER"
grep -Fq 'p%max_backtracking = 4' "$DRIVER"
grep -Fq 'p%min_step_duration = 1.0e-6_real64' "$DRIVER"
grep -Fq 'cfg%transaction%max_retries = 16' "$DRIVER"
grep -Fq 'FSI20_SOLVER_EXHAUSTION' "$PROBE_HEADCALC"
echo 'FSI20_SOLVER_REJECTION_EXACT_FGC02_CONTROLS=PASS'

bash "$BASE_RUNNER" | tee "$LOG"

python3 - "$LOG" <<'PY'
from pathlib import Path
import math,re,sys
rows={1:[],2:[],3:[]}
case=None
for line in Path(sys.argv[1]).read_text().splitlines():
    m=re.match(r'FSI20_CASE_BEGIN=(\d+):',line)
    if m:
        case=int(m.group(1)); continue
    if line.startswith('FSI20_CASE_END='):
        case=None; continue
    if line.startswith('FSI20_SOLVER_EXHAUSTION'):
        if case not in rows: raise SystemExit('solver exhaustion outside case')
        p=line.split()
        if len(p)!=9: raise SystemExit(f'bad solver exhaustion fields {len(p)}: {line}')
        rows[case].append({
            'dt':float(p[1]), 'iterations':int(p[2]), 'numbit':int(p[3]),
            'nbalance':int(p[4]), 'nhead':int(p[5]),
            'balance_ratio':float(p[6]), 'total_ratio':float(p[7]), 'head_ratio':float(p[8])})
for cid in (1,2,3):
    if len(rows[cid])!=5:
        raise SystemExit(f'expected five fine-step solver exhaustions for case {cid}, got {len(rows[cid])}')
    for r in rows[cid]:
        if not all(math.isfinite(r[k]) for k in ('dt','balance_ratio','total_ratio','head_ratio')):
            raise SystemExit('nonfinite rejection diagnostic')
        if r['iterations']!=8:
            raise SystemExit(f'unexpected nonlinear iteration count {r}')
base=rows[2]
for i,r in enumerate(base,1):
    print('FSI20_SOLVER_REJECTION_ROW:INDEX='+str(i)+
          ':DT='+f"{r['dt']:.17e}"+
          ':NONLINEAR_ITERATIONS='+str(r['iterations'])+
          ':LEGACY_NUMBIT='+str(r['numbit'])+
          ':NONCONVERGED_BALANCE_NODES='+str(r['nbalance'])+
          ':NONCONVERGED_HEAD_NODES='+str(r['nhead'])+
          ':MAX_COMPARTMENT_BALANCE_RATIO='+f"{r['balance_ratio']:.17e}"+
          ':TOTAL_BALANCE_RATIO='+f"{r['total_ratio']:.17e}"+
          ':MAX_HEAD_CRITERION_RATIO='+f"{r['head_ratio']:.17e}")
if all(r['nbalance']==0 and r['total_ratio']<=1.0 and r['nhead']>0 for r in base):
    classification='HEAD_ITERATION_CRITERION_ONLY'
elif all(r['nhead']==0 and (r['nbalance']>0 or r['total_ratio']>1.0) for r in base):
    classification='BALANCE_CRITERION_ONLY'
elif all(r['nhead']>0 and (r['nbalance']>0 or r['total_ratio']>1.0) for r in base):
    classification='MIXED_HEAD_AND_BALANCE_CRITERIA'
else:
    classification='MIXED_OR_CHANGING_CRITERIA'
print('FSI20_SOLVER_REJECTION_CLASSIFICATION='+classification)
print('FSI20_SOLVER_REJECTION_MIN_DT='+f"{min(r['dt'] for r in base):.17e}")
print('FSI20_SOLVER_REJECTION_MAX_DT='+f"{max(r['dt'] for r in base):.17e}")
print('FSI20_SOLVER_REJECTION_PRODUCTION_POLICY_CHANGED=NO')
print('FSI20_SOLVER_REJECTION_MASS_GATE_CHANGED=NO')
PY

cp "$ORIGINAL_DRIVER" "$DRIVER"
cp "$ORIGINAL_RUNNER" "$BASE_RUNNER"
cmp "$HEADCALC" <(git show HEAD:src/legacy/b1_10_port/headcalc.f90)
git diff --quiet "$FVQ27" -- src || fail 'production source changed during diagnostic probe'
echo 'FSI20_SOLVER_REJECTION_PRODUCTION_IMMUTABILITY=PASS'
echo 'FSI20_FINE_STEP_SOLVER_REJECTION_CLASSIFICATION PASS'
