#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi21-same-endpoint-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=631d80abf04915cc964b24144f3fde8ef937093f
FVQ28_BRANCH=origin/qualification/f-vq28-richards-temporal-numeric-profile
FSI18_BRANCH=origin/work/f-si18-reference-convergence-cliff
FVQ28_DRIVER_BLOB=66b475b0f28ccd71ff6eb7590d4cb3c2f89da8a3
STUB_BLOB=23c00e4a188e88bc36ef95cbe4faaacdd6aad639
GEN_BLOB=bf25c4c7fefaa59811255b0bc25c041522ab008e
SOLVER_CONTRACT_BLOB=4271372085d800fd5da969a2ed073b00422d79c6
LEGACY_BINDING_BLOB=db432cac3f1156a179c636435a25f52cdececffc
fail(){ echo "FSI21_RUNNER_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$BASE" HEAD || fail 'F-SI20 base not ancestor'
git diff --quiet "$BASE" -- src || fail 'production source drift from F-SI20 owner head'
[[ "$(git rev-parse HEAD:src/solver/mod_soil_water_solver_contract.f90)" == "$SOLVER_CONTRACT_BLOB" ]] || fail 'solver contract drift'
[[ "$(git rev-parse HEAD:src/adapter/mod_reference_richards_legacy_binding.f90)" == "$LEGACY_BINDING_BLOB" ]] || fail 'legacy binding drift'
[[ "$(git rev-parse HEAD:tests/fsi/fsi04_real_headcalc_stubs.f90)" == "$STUB_BLOB" ]] || fail 'HeadCalc stub drift'
[[ "$(git rev-parse "$FSI18_BRANCH:tests/fsi/fsi18_make_reference_tridag_stubs.py")" == "$GEN_BLOB" ]] || fail 'TRIDAG generator drift'
[[ "$(git rev-parse "$FVQ28_BRANCH:tests/fvq/test_fvq28_reference_reachability.f90")" == "$FVQ28_DRIVER_BLOB" ]] || fail 'F-VQ28 fixture reference drift'
grep -Fq '"partitions": [1, 2, 4, 8, 16, 32]' integration/f-si/F-SI21_CANDIDATE_MATRIX.json || fail 'candidate matrix partitions drift'
grep -Fq 'integer, parameter :: levels(nl) = [1,2,4,8,16,32]' tests/fsi/test_fsi21_same_endpoint_characterization.f90 || fail 'driver levels drift'
grep -Fq 'horizons(na) = [ 0.25_real64,0.125_real64,0.0625_real64 ]' tests/fsi/test_fsi21_same_endpoint_characterization.f90 || fail 'driver horizons drift'
grep -Fq 'request%numerical%max_iterations=8' tests/fsi/test_fsi21_same_endpoint_characterization.f90 || fail 'max iterations drift'
grep -Fq 'request%numerical%max_backtracking=4' tests/fsi/test_fsi21_same_endpoint_characterization.f90 || fail 'max backtracking drift'
grep -Fq 'hard_mass_gate = 1.0e-12_real64' tests/fsi/test_fsi21_same_endpoint_characterization.f90 || fail 'hard mass gate drift'
grep -Fq 'nonlinear_head_tol = 1.0e-12_real64' tests/fsi/test_fsi21_same_endpoint_characterization.f90 || fail 'nonlinear head tolerance drift'
echo 'FSI21_SOURCE_AND_CANDIDATE_MATRIX_LOCK=PASS'

git show "$FSI18_BRANCH:tests/fsi/fsi18_make_reference_tridag_stubs.py" > "$BUILD/make_ref.py"
python3 "$BUILD/make_ref.py" tests/fsi/fsi04_real_headcalc_stubs.f90 "$BUILD/fsi04_reference_tridag_stubs.f90"
grep -Fq 'SWAP 4.3.1 tridag.f90' "$BUILD/fsi04_reference_tridag_stubs.f90" || fail 'reference TRIDAG marker missing'
if grep -Fq 'solution(i) = 0.0d0' "$BUILD/fsi04_reference_tridag_stubs.f90"; then fail 'zero-correction TRIDAG survived'; fi
echo 'FSI21_REFERENCE_TRIDAG=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULES=(
 "$BUILD/fsi04_reference_tridag_stubs.f90"
 src/runtime/mod_a23bu_worker_execution_context.f90
 src/solver/mod_soil_water_solver_contract.f90
 src/solver/mod_process_hydraulic_view.f90
 src/solver/mod_reference_linear_solver.f90
 src/solver/mod_reference_richards_workspace.f90
 src/solver/mod_reference_richards_state_binding.f90
 src/solver/mod_b110_default_mvg_provider.f90
 src/solver/mod_b110_source_sink_provider.f90
 src/legacy/b1_10_port/headcalc.f90
 src/adapter/mod_reference_richards_legacy_binding.f90
 tests/fmr/mod_fmr04_fixed_top_provider.f90
)

build_run(){
 local opt="$1"
 local tag="$2"
 local out="$BUILD/$tag"
 mkdir -p "$out"
 local objs=()
 for src in "${MODULES[@]}"; do
   local obj="$out/$(basename "${src%.*}").o"
   gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
   objs+=("$obj")
 done
 gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c tests/fsi/test_fsi21_same_endpoint_characterization.f90 -o "$out/test.o"
 gfortran "$opt" "${objs[@]}" "$out/test.o" -o "$out/test"
 timeout 480s "$out/test" > "$out/run1.txt" 2>&1
 timeout 480s "$out/test" > "$out/run2.txt" 2>&1
 cmp "$out/run1.txt" "$out/run2.txt"
 grep -Fq 'FSI21_DRIVER PASS CASES=24:TRAJECTORIES=72:ROWS=432' "$out/run1.txt"
 echo "FSI21_REPEAT_${tag}=PASS"
}

build_run -O0 o0
build_run -O2 o2
cmp "$BUILD/o0/run1.txt" "$BUILD/o2/run1.txt"
echo 'FSI21_O0_O2_IDENTITY=PASS'
cat "$BUILD/o0/run1.txt"

python3 - "$BUILD/o0/run1.txt" <<'PY'
from pathlib import Path
from collections import defaultdict, Counter
import math, sys

path=Path(sys.argv[1])
rows=[]
for line in path.read_text().splitlines():
    if not line.startswith('FSI21_ROW:'):
        continue
    fields={}
    for part in line.split(':')[1:]:
        if '=' not in part:
            continue
        k,v=part.split('=',1)
        fields[k]=v.strip()
    required=['TID','CASE','STATE','JUMP_ID','HORIZON_ID','H0','JUMP','DT','N','SUBDT','SUCCESS',
              'FAILURE_CLASS','FIRST_FAILED_STEP','FAIL_STATUS','MAX_MASS','MAX_SOLVER_RES','HEADCALC_CALLS',
              'TOTAL_NITER','MAX_NITER','TOTAL_JAC','TOTAL_LINEAR','TOTAL_NBACK','MAX_NBACK',
              'H1','H2','H3','H4','THETA1','THETA2','THETA3','THETA4','POND','GWL']
    missing=[k for k in required if k not in fields]
    if missing:
        raise SystemExit(f'missing fields {missing} in {line}')
    r={
      'tid':int(fields['TID']),'case':int(fields['CASE']),'state':int(fields['STATE']),
      'jump_id':int(fields['JUMP_ID']),'horizon_id':int(fields['HORIZON_ID']),
      'h0':float(fields['H0']),'jump':float(fields['JUMP']),'dt':float(fields['DT']),
      'n':int(fields['N']),'subdt':float(fields['SUBDT']),'ok':fields['SUCCESS']=='T',
      'fclass':int(fields['FAILURE_CLASS']),'fstep':int(fields['FIRST_FAILED_STEP']),
      'status':int(fields['FAIL_STATUS']),'mass':float(fields['MAX_MASS']),
      'solver_res':float(fields['MAX_SOLVER_RES']),'calls':int(fields['HEADCALC_CALLS']),
      'total_niter':int(fields['TOTAL_NITER']),'max_niter':int(fields['MAX_NITER']),
      'total_jac':int(fields['TOTAL_JAC']),'total_linear':int(fields['TOTAL_LINEAR']),
      'total_nback':int(fields['TOTAL_NBACK']),'max_nback':int(fields['MAX_NBACK']),
      'h':[float(fields[f'H{i}']) for i in range(1,5)],
      'theta':[float(fields[f'THETA{i}']) for i in range(1,5)],
      'pond':float(fields['POND']),'gwl':float(fields['GWL'])
    }
    rows.append(r)

levels=[1,2,4,8,16,32]
if len(rows)!=432:
    raise SystemExit(f'expected 432 rows, got {len(rows)}')
by_tid=defaultdict(dict)
for r in rows:
    if r['n'] in by_tid[r['tid']]:
        raise SystemExit(f'duplicate tid/n {r["tid"]}/{r["n"]}')
    by_tid[r['tid']][r['n']]=r
if sorted(by_tid)!=list(range(1,73)):
    raise SystemExit('trajectory ids not 1..72')
for tid,d in by_tid.items():
    if sorted(d)!=levels:
        raise SystemExit(f'levels missing for trajectory {tid}: {sorted(d)}')

mass_fail=[r for r in rows if r['fclass']==2]
solver_fail=[r for r in rows if r['fclass']==1]
print(f'FSI21_ROWS={len(rows)}:TRAJECTORIES={len(by_tid)}:SOLVER_FAILURE_ROWS={len(solver_fail)}:MASS_FAILURE_ROWS={len(mass_fail)}')
for n in levels:
    rr=[r for r in rows if r['n']==n]
    print(f'FSI21_N_SUMMARY:N={n}:SUCCESS={sum(r["ok"] for r in rr)}:FAIL={sum(not r["ok"] for r in rr)}:HEADCALC_CALLS={sum(r["calls"] for r in rr)}:TOTAL_NITER={sum(r["total_niter"] for r in rr)}')
for hid,dt in ((1,.25),(2,.125),(3,.0625)):
    for n in levels:
        rr=[r for r in rows if r['horizon_id']==hid and r['n']==n]
        print(f'FSI21_HORIZON_N:HORIZON_ID={hid}:DT={dt:.8f}:N={n}:SUCCESS={sum(r["ok"] for r in rr)}:FAIL={sum(not r["ok"] for r in rr)}')
if mass_fail:
    print('FSI21_GLOBAL_HARD_MASS_GATE=FAIL')
    for r in mass_fail:
        print(f'FSI21_MASS_FAILURE:TID={r["tid"]}:N={r["n"]}:STEP={r["fstep"]}:MASS={r["mass"]:.17e}')
else:
    print('FSI21_GLOBAL_HARD_MASS_GATE=PASS')

components=('H','THETA','POND','GWL')
def defect(a,b):
    if not (a['ok'] and b['ok']):
        return None
    return {
      'H':max(abs(x-y) for x,y in zip(a['h'],b['h'])),
      'THETA':max(abs(x-y) for x,y in zip(a['theta'],b['theta'])),
      'POND':abs(a['pond']-b['pond']),
      'GWL':abs(a['gwl']-b['gwl'])
    }

def nonincreasing(d0,d1):
    if d0 is None or d1 is None:
        return False
    return all(math.isfinite(d0[c]) and math.isfinite(d1[c]) and d1[c] <= d0[c] for c in components)

def ratio_order(x0,x1):
    if not (math.isfinite(x0) and math.isfinite(x1)):
        return ('NA','NA')
    if x0==0.0:
        return ('NA','NA')
    ratio=x1/x0
    if x1==0.0:
        return (f'{ratio:.17e}','INF')
    order=math.log(x0/x1,2.0)
    return (f'{ratio:.17e}',f'{order:.17e}')

all_defects={}
first_persistent={}
c1_pass={}
base_safe={}
for tid in range(1,73):
    d=by_tid[tid]
    defects={}
    for coarse in levels[:-1]:
        fine=coarse*2
        df=defect(d[coarse],d[fine])
        defects[coarse]=df
        if df is None:
            print(f'FSI21_DEFECT:TID={tid}:N_COARSE={coarse}:N_FINE={fine}:AVAILABLE=F:COARSE_OK={str(d[coarse]["ok"])[0]}:FINE_OK={str(d[fine]["ok"])[0]}')
        else:
            print(f'FSI21_DEFECT:TID={tid}:N_COARSE={coarse}:N_FINE={fine}:AVAILABLE=T:DH={df["H"]:.17e}:DTHETA={df["THETA"]:.17e}:DPOND={df["POND"]:.17e}:DGWL={df["GWL"]:.17e}')
    all_defects[tid]=defects
    for i in range(len(levels)-2):
        c0=levels[i]; c1=levels[i+1]
        d0=defects[c0]; d1=defects[c1]
        fine0=c0*2; fine1=c1*2
        if d0 is None or d1 is None:
            for comp in components:
                print(f'FSI21_DECAY:TID={tid}:FROM_FINE_N={fine0}:TO_FINE_N={fine1}:COMP={comp}:AVAILABLE=F')
            continue
        for comp in components:
            ratio,order=ratio_order(d0[comp],d1[comp])
            ni=d1[comp] <= d0[comp]
            print(f'FSI21_DECAY:TID={tid}:FROM_FINE_N={fine0}:TO_FINE_N={fine1}:COMP={comp}:AVAILABLE=T:RATIO={ratio}:ORDER={order}:NONINCREASING={str(ni)[0]}')
    fp=None
    coarse_seq=levels[:-1]
    for j in range(len(coarse_seq)-2):
        if nonincreasing(defects[coarse_seq[j]],defects[coarse_seq[j+1]]) and nonincreasing(defects[coarse_seq[j+1]],defects[coarse_seq[j+2]]):
            fp=coarse_seq[j+2]*2
            break
    first_persistent[tid]=fp
    c1_pass[tid]=(d[1]['ok'] and d[2]['ok'] and d[4]['ok'] and nonincreasing(defects[1],defects[2]))
    base_safe[tid]=(d[1]['ok'] and d[2]['ok'] and d[1]['fclass']!=2 and d[2]['fclass']!=2)
    print(f'FSI21_TRAJECTORY:TID={tid}:C1_SHAPE_PASS={str(c1_pass[tid])[0]}:C2_BASE_SAFE={str(base_safe[tid])[0]}:FIRST_PERSISTENT_FINE_N={fp if fp is not None else "NONE"}')

c1_count=sum(c1_pass.values())
base_count=sum(base_safe.values())
persist_count=sum(v is not None and v<=32 for v in first_persistent.values())
dist=Counter(v if v is not None else 'NONE' for v in first_persistent.values())
print(f'FSI21_C1_SHAPE_SUMMARY:PASS={c1_count}:FAIL={72-c1_count}:FIXED_PHYSICAL_SOLVE_COUNT=7:NORMAL_PATH_ADMISSION=FORBIDDEN_BY_FROZEN_MATRIX')
print(f'FSI21_C2_BASE_SUMMARY:SAFE={base_count}:UNSAFE={72-base_count}:BASE_PHYSICAL_SOLVE_COUNT=3:NUMERIC_TRIGGER_SELECTED=F')
print(f'FSI21_C3_PERSISTENT_DECAY_SUMMARY:ESTABLISHED_BY_N32={persist_count}:GAP={72-persist_count}:REFERENCE_ONLY=T')
print('FSI21_PERSISTENCE_STRUCTURAL_MIN_FINE_N=8')
for key in sorted(dist,key=lambda x:999 if x=='NONE' else x):
    print(f'FSI21_FIRST_PERSISTENT_FINE_N:N={key}:COUNT={dist[key]}')
requires_gt2=sum(v is None or v>2 for v in first_persistent.values())
requires_gt4=sum(v is None or v>4 for v in first_persistent.values())
print(f'FSI21_REQUIRES_FINE_N_GT_2:COUNT={requires_gt2}:FRACTION={requires_gt2/72:.17e}')
print(f'FSI21_REQUIRES_FINE_N_GT_4:COUNT={requires_gt4}:FRACTION={requires_gt4/72:.17e}')
print('FSI21_THEORETICAL_COST:C1_THROUGH_N4=7:C2_BASE_N2=3:C2_THROUGH_N4=7:C2_THROUGH_N8=15:C2_THROUGH_N16=31:C2_THROUGH_N32=63:C3_THROUGH_N32=63')
print(f'FSI21_ACTUAL_MAX_TOTAL_HEADCALC_CALLS_ALL_LEVELS={max(sum(r["calls"] for r in d.values()) for d in by_tid.values())}')
print(f'FSI21_MAX_MASS_ON_SUCCESS={max(r["mass"] for r in rows if r["ok"]):.17e}')
print(f'FSI21_MAX_SINGLE_SOLVE_NITER={max(r["max_niter"] for r in rows)}:MAX_SINGLE_SOLVE_NBACK={max(r["max_nback"] for r in rows)}')
if solver_fail:
    for r in solver_fail:
        print(f'FSI21_SOLVER_FAILURE:TID={r["tid"]}:CASE={r["case"]}:STATE={r["state"]}:JUMP_ID={r["jump_id"]}:HORIZON_ID={r["horizon_id"]}:N={r["n"]}:SUBDT={r["subdt"]:.17e}:FIRST_STEP={r["fstep"]}:STATUS={r["status"]}:MAX_NITER={r["max_niter"]}:MAX_NBACK={r["max_nback"]}')
print('FSI21_SAME_ENDPOINT_CHARACTERIZATION_COMPLETE=PASS')
PY

git diff --quiet "$BASE" -- src || fail 'production source changed during characterization'
echo 'FSI21_PRODUCTION_SOURCE_UNCHANGED=PASS'
