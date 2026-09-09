#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq29-calibration-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=1ac759b39ee743bfa0992d6b9da09f2cfeda38b9
DRIVER=tests/fsi/test_fsi20_fixed_horizon_reference.f90
DRIVER_BLOB=5c8ea89bfedd16a57fdfcf38d188a093a2999525
STUB=tests/fsi/fsi04_real_headcalc_stubs.f90
STUB_BLOB=23c00e4a188e88bc36ef95cbe4faaacdd6aad639
FSI18_BRANCH=origin/work/f-si18-reference-convergence-cliff
FSI18_GENERATOR=tests/fsi/fsi18_make_reference_tridag_stubs.py
FSI18_GENERATOR_BLOB=bf25c4c7fefaa59811255b0bc25c041522ab008e

fail() { echo "FVQ29_CALIBRATION_FAIL $*" >&2; exit 1; }

git diff --quiet "$BASE" -- \
  src/solver \
  src/legacy/b1_10_port/headcalc.f90 \
  src/adapter/mod_reference_richards_legacy_binding.f90 \
  src/runtime/mod_a23bu_worker_execution_context.f90 \
  tests/fmr/mod_fmr04_fixed_top_provider.f90 \
  || fail 'Richards/direct-solver source drift from F-VQ29 base'
[[ "$(git rev-parse HEAD:$DRIVER)" == "$DRIVER_BLOB" ]] || fail 'fixed-horizon driver drift'
[[ "$(git rev-parse HEAD:$STUB)" == "$STUB_BLOB" ]] || fail 'HeadCalc stub drift'
echo 'FVQ29_CALIBRATION_SOURCE_LOCK=PASS'

git fetch --quiet --no-tags origin work/f-si18-reference-convergence-cliff:refs/remotes/origin/work/f-si18-reference-convergence-cliff
[[ "$(git rev-parse "$FSI18_BRANCH:$FSI18_GENERATOR")" == "$FSI18_GENERATOR_BLOB" ]] || fail 'F-SI18 TRIDAG generator drift'
git show "$FSI18_BRANCH:$FSI18_GENERATOR" > "$BUILD/make_reference_tridag.py"
python3 "$BUILD/make_reference_tridag.py" "$STUB" "$BUILD/reference_tridag_stubs.f90"
grep -Fq 'SWAP 4.3.1 tridag.f90' "$BUILD/reference_tridag_stubs.f90" || fail 'reference TRIDAG marker missing'
if grep -Fq 'solution(i) = 0.0d0' "$BUILD/reference_tridag_stubs.f90"; then
  fail 'zero-correction TRIDAG survived reference replacement'
fi
echo 'FVQ29_CALIBRATION_REFERENCE_TRIDAG=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  "$BUILD/reference_tridag_stubs.f90"
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

HEADS=(-25.0 -40.0 -55.0 -75.0 -110.0 -160.0 -210.0 -250.0 -320.0)
JUMPS=(-0.05 0.05)
HORIZONS=(0.125 0.25 0.5)
EXPECTED_CASES=54

build_modules() {
  local opt="$1"
  local out="$2"
  mkdir -p "$out"
  : > "$out/objects.txt"
  for src in "${MODULE_SRC[@]}"; do
    local obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    echo "$obj" >> "$out/objects.txt"
  done
}

make_driver() {
  local target="$1" h0="$2" hb="$3" horizon="$4"
  cp "$DRIVER" "$target"
  python3 - "$target" "$h0" "$hb" "$horizon" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); h0=float(sys.argv[2]); hb=float(sys.argv[3]); horizon=float(sys.argv[4]); s=p.read_text()
repls={
  'real(real64), parameter :: total_dt = 0.25_real64':f'real(real64), parameter :: total_dt = {horizon:.17e}_real64',
  'real(real64), parameter :: initial_head_cm = -75.0_real64':f'real(real64), parameter :: initial_head_cm = {h0:.17e}_real64',
  'real(real64), parameter :: predictor_bottom_head_cm = -74.99_real64':f'real(real64), parameter :: predictor_bottom_head_cm = {hb:.17e}_real64',
  'integer, parameter :: nlevels = 11':'integer, parameter :: nlevels = 12',
  'integer, parameter :: nsteps(nlevels) = [1,2,4,8,16,32,64,128,256,512,1024]':
      'integer, parameter :: nsteps(nlevels) = [1,2,4,8,16,32,64,128,256,512,1024,2048]'
}
for old,new in repls.items():
    if s.count(old)!=1: raise SystemExit('driver token drift: '+old)
    s=s.replace(old,new,1)
p.write_text(s)
PY
}

run_matrix() {
  local opt="$1"
  local tag="$2"
  local out="$BUILD/$tag"
  build_modules "$opt" "$out"
  mapfile -t objects < "$out/objects.txt"
  local cid=0
  for horizon in "${HORIZONS[@]}"; do
    for h0 in "${HEADS[@]}"; do
      for jump in "${JUMPS[@]}"; do
        cid=$((cid+1))
        local hb driver
        hb="$(python3 - <<PY
print(f'{float("$h0")+float("$jump"):.17e}')
PY
)"
        driver="$out/case_${cid}.f90"
        make_driver "$driver" "$h0" "$hb" "$horizon"
        gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$driver" -o "$out/case_${cid}.o"
        gfortran "$opt" "${objects[@]}" "$out/case_${cid}.o" -o "$out/case_${cid}"
        timeout 300s "$out/case_${cid}" > "$out/case_${cid}.txt" 2>&1 || {
          cat "$out/case_${cid}.txt" >&2
          fail "case $cid execution opt=$tag h0=$h0 jump=$jump horizon=$horizon"
        }
        grep -Fq 'FSI20_FIXED_HORIZON_REFERENCE_DRIVER PASS' "$out/case_${cid}.txt" || fail "case $cid missing PASS"
        printf '%s %s %s %s\n' "$cid" "$h0" "$jump" "$horizon" >> "$out/cases.tsv"
        echo "FVQ29_CALIBRATION_CASE_RUN=PASS:OPT=$tag:CASE=$cid:H0=$h0:JUMP=$jump:HORIZON=$horizon"
      done
    done
  done
  [[ "$cid" -eq "$EXPECTED_CASES" ]] || fail "case count $cid != $EXPECTED_CASES"
}

run_matrix -O0 o0
run_matrix -O2 o2
cmp "$BUILD/o0/cases.tsv" "$BUILD/o2/cases.tsv" || fail 'O0/O2 case ordering drift'
for i in $(seq 1 "$EXPECTED_CASES"); do
  cmp "$BUILD/o0/case_${i}.txt" "$BUILD/o2/case_${i}.txt" || fail "O0/O2 trajectory output drift case $i"
done
echo 'FVQ29_CALIBRATION_O0_O2_IDENTITY=PASS'

python3 - "$BUILD/o0" <<'PY'
from pathlib import Path
import math,re,sys
root=Path(sys.argv[1])
meta=[]
for line in (root/'cases.tsv').read_text().splitlines():
    cid,h0,jump,horizon=line.split()
    meta.append((int(cid),float(h0),float(jump),float(horizon)))
steps=[1,2,4,8,16,32,64,128,256,512,1024]
candidates=[1,2,4,8,16,32,64]
eps=sys.float_info.epsilon
cases=[]
max_mass=0.0
for cid,h0,jump,horizon in meta:
    lines=(root/f'case_{cid}.txt').read_text().splitlines()
    endpoints=[]; comps=[]
    for line in lines:
        if line.startswith('FSI20_FIXED_ENDPOINT:'):
            m=re.match(r'FSI20_FIXED_ENDPOINT:N=(\d+):SUB_DT=\s*([^:]+):MAX_MASS_RESIDUAL=\s*([^:]+):MAX_SOLVER_RESIDUAL=\s*(\S+)',line)
            if not m: raise SystemExit('bad endpoint row '+line)
            endpoints.append((int(m.group(1)),float(m.group(2)),float(m.group(3)),float(m.group(4))))
        elif line.startswith('FSI20_FIXED_COMPARE:'):
            m=re.match(r'FSI20_FIXED_COMPARE:N=(\d+):N2=(\d+):DHEAD_N_N2=\s*([^:]+):DTHETA_N_N2=\s*([^:]+):EHEAD_N_REF=\s*([^:]+):ETHETA_N_REF=\s*([^:]+):EHEAD_N2_REF=\s*([^:]+):ETHETA_N2_REF=\s*([^:]+):SIGNED_STORAGE_N_REF=\s*(\S+)',line)
            if not m: raise SystemExit('bad compare row '+line)
            comps.append((int(m.group(1)),int(m.group(2)),*(float(m.group(i)) for i in range(3,10))))
    if len(endpoints)!=12 or len(comps)!=11:
        raise SystemExit(f'case {cid}: expected 12 endpoints/11 compares got {len(endpoints)}/{len(comps)}')
    mm=max(abs(x[2]) for x in endpoints); max_mass=max(max_mass,mm)
    if mm>1e-12: raise SystemExit(f'case {cid}: mass residual {mm}')
    d=[x[2] for x in comps]
    e2=[x[6] for x in comps]
    if not all(math.isfinite(x) and x>=0 for x in d+e2): raise SystemExit(f'case {cid}: invalid head metric')
    floor=128.0*eps*max(1.0,abs(h0),abs(h0+jump))
    cases.append(dict(cid=cid,h0=h0,jump=jump,horizon=horizon,d=d,e2=e2,floor=floor))

selected=None
for nmin in candidates:
    idx=steps.index(nmin)
    ratios=[]
    for c in cases:
        for j in range(idx,len(c['d'])-1):
            a,b=c['d'][j],c['d'][j+1]
            if a>c['floor'] and b>c['floor']:
                ratios.append(b/a)
    if not ratios:
        print(f'FVQ29_CALIBRATION_CANDIDATE:NMIN={nmin}:STATUS=NO_RESOLVED_RATIOS')
        continue
    qcap=max(ratios)
    if not (math.isfinite(qcap) and 0.0<=qcap<1.0):
        print(f'FVQ29_CALIBRATION_CANDIDATE:NMIN={nmin}:QCAP={qcap:.17e}:STATUS=NO_CONTRACTION_CAP')
        continue
    mult=qcap/(1.0-qcap)
    failures=[]; floor_cases=0; resolved_cases=0; min_margin=math.inf
    for c in cases:
        dN=c['d'][idx]; err=c['e2'][idx]
        if dN<=c['floor']:
            floor_cases+=1
            if err>c['floor']:
                failures.append((c['cid'],'floor',dN,err,c['floor']))
            continue
        resolved_cases+=1
        bound=mult*dN
        min_margin=min(min_margin,bound-err)
        if bound < err:
            failures.append((c['cid'],'bound',bound,err,c['floor']))
    status='PASS' if not failures else 'FAIL'
    print(f'FVQ29_CALIBRATION_CANDIDATE:NMIN={nmin}:QCAP={qcap:.17e}:MULT={mult:.17e}:RESOLVED_CASES={resolved_cases}:FLOOR_CASES={floor_cases}:FAILURES={len(failures)}:MIN_BOUND_MINUS_ERROR={min_margin:.17e}:STATUS={status}')
    for f in failures[:8]:
        print('FVQ29_CALIBRATION_FAILURE_DETAIL:'+':'.join(map(str,f)))
    if not failures and selected is None:
        selected=(nmin,qcap,mult,resolved_cases,floor_cases,min_margin)

if selected is None:
    print('FVQ29_CALIBRATION_ERROR_BOUND_CANDIDATE=NO')
    raise SystemExit(2)
nmin,qcap,mult,resolved_cases,floor_cases,min_margin=selected
# Report state/horizon-specific worst future ratios for diagnosis only.
idx=steps.index(nmin)
for horizon in sorted({c['horizon'] for c in cases}):
    rs=[]
    for c in cases:
        if c['horizon']!=horizon: continue
        for j in range(idx,len(c['d'])-1):
            a,b=c['d'][j],c['d'][j+1]
            if a>c['floor'] and b>c['floor']: rs.append(b/a)
    print(f'FVQ29_CALIBRATION_HORIZON_QMAX:HORIZON={horizon:.17e}:QMAX={max(rs):.17e}')
for h0 in sorted({c['h0'] for c in cases}):
    rs=[]
    for c in cases:
        if c['h0']!=h0: continue
        for j in range(idx,len(c['d'])-1):
            a,b=c['d'][j],c['d'][j+1]
            if a>c['floor'] and b>c['floor']: rs.append(b/a)
    print(f'FVQ29_CALIBRATION_STATE_QMAX:H0={h0:.17e}:QMAX={max(rs):.17e}')
max_tail=max(c['d'][-1] for c in cases)
print(f'FVQ29_CALIBRATION_MAX_MASS_RESIDUAL={max_mass:.17e}')
print(f'FVQ29_CALIBRATION_MAX_X1024_X2048_DHEAD={max_tail:.17e}')
print(f'FVQ29_CALIBRATION_SELECTED:NMIN={nmin}:QCAP={qcap:.17e}:MULT={mult:.17e}:RESOLVED_CASES={resolved_cases}:FLOOR_CASES={floor_cases}:MIN_BOUND_MINUS_ERROR={min_margin:.17e}')
print('FVQ29_CALIBRATION_MANUAL_MARGIN_ADDED=NO')
print('FVQ29_CALIBRATION_SCIENTIFIC_TOLERANCE_SELECTED=NO')
print('FVQ29_CALIBRATION_ERROR_BOUND_CANDIDATE=YES')
PY

git diff --quiet "$BASE" -- \
  src/solver \
  src/legacy/b1_10_port/headcalc.f90 \
  src/adapter/mod_reference_richards_legacy_binding.f90 \
  src/runtime/mod_a23bu_worker_execution_context.f90 \
  tests/fmr/mod_fmr04_fixed_top_provider.f90 \
  || fail 'Richards/direct-solver source changed during Gate A'
echo 'FVQ29_CALIBRATION_PRODUCTION_RICHARDS_SOURCE_UNCHANGED=PASS'
echo 'FVQ29_CALIBRATION_GATE_A PASS'
