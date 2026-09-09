#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi23-c3-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=394d064a0dad0a7f7852b129bae99713b9aeb4c0
PLAN=integration/f-si/F-SI23_GATE_C3_TRANSACTION_LOCAL_REFINEMENT_PLAN.json
PLAN_BLOB=599ee73cd8a8f71e51d42e83ac420066cbc66bb3
DRIVER=tests/fsi/test_fsi23_gate_c3_transaction_local_refinement.f90
DRIVER_BLOB=261cec4550e8333734b54710bb9a34e2ff708742
STUB=tests/fsi/fsi04_real_headcalc_stubs.f90
FSI18_BRANCH=origin/work/f-si18-reference-convergence-cliff
FSI18_GENERATOR=tests/fsi/fsi18_make_reference_tridag_stubs.py
FSI18_GENERATOR_BLOB=bf25c4c7fefaa59811255b0bc25c041522ab008e

fail() { echo "FSI23_C3_GATE_FAIL $*" >&2; exit 1; }

git diff --quiet "$BASE" -- \
  src/solver \
  src/legacy/b1_10_port/headcalc.f90 \
  src/adapter/mod_reference_richards_legacy_binding.f90 \
  src/runtime/mod_a23bu_worker_execution_context.f90 \
  tests/fmr/mod_fmr04_fixed_top_provider.f90 \
  || fail 'production Richards/runtime source drift from F-VQ29 base'
[[ "$(git rev-parse HEAD:$PLAN)" == "$PLAN_BLOB" ]] || fail 'C3 plan drift after freeze'
[[ "$(git rev-parse HEAD:$DRIVER)" == "$DRIVER_BLOB" ]] || fail 'C3 driver drift after implementation lock'
echo 'FSI23_C3_SOURCE_PLAN_DRIVER_LOCK=PASS'

git fetch --quiet --no-tags origin work/f-si18-reference-convergence-cliff:refs/remotes/origin/work/f-si18-reference-convergence-cliff
[[ "$(git rev-parse "$FSI18_BRANCH:$FSI18_GENERATOR")" == "$FSI18_GENERATOR_BLOB" ]] || fail 'F-SI18 TRIDAG generator drift'
git show "$FSI18_BRANCH:$FSI18_GENERATOR" > "$BUILD/make_reference_tridag.py"
python3 "$BUILD/make_reference_tridag.py" "$STUB" "$BUILD/reference_tridag_stubs.f90"
grep -Fq 'SWAP 4.3.1 tridag.f90' "$BUILD/reference_tridag_stubs.f90" || fail 'reference TRIDAG marker missing'
if grep -Fq 'solution(i) = 0.0d0' "$BUILD/reference_tridag_stubs.f90"; then
  fail 'zero-correction TRIDAG survived reference replacement'
fi
echo 'FSI23_C3_REFERENCE_TRIDAG=PASS'

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

CASES=(
  '-25.0 -0.1' '-25.0 -0.01' '-25.0 0.001' '-25.0 0.01' '-25.0 0.1'
  '-75.0 -0.1' '-75.0 -0.01' '-75.0 0.001' '-75.0 0.01' '-75.0 0.1'
  '-250.0 -0.1' '-250.0 -0.01' '-250.0 0.001' '-250.0 0.01' '-250.0 0.1'
)

build_modules() {
  local opt="$1" out="$2"
  mkdir -p "$out"
  local objects_file="$out/objects.txt"
  : > "$objects_file"
  for src in "${MODULE_SRC[@]}"; do
    local obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    echo "$obj" >> "$objects_file"
  done
}

run_matrix() {
  local opt="$1"
  local tag="$2"
  local out="$BUILD/$tag"
  build_modules "$opt" "$out"
  mapfile -t objects < "$out/objects.txt"
  local case_id=0
  for spec in "${CASES[@]}"; do
    case_id=$((case_id+1))
    read -r h0 jump <<<"$spec"
    local hb driver="$out/case_${case_id}.f90"
    hb="$(python3 - <<PY
h0=float('$h0'); jump=float('$jump')
print(f'{h0+jump:.17e}')
PY
)"
    cp "$DRIVER" "$driver"
    python3 - "$driver" "$h0" "$hb" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); h0=float(sys.argv[2]); hb=float(sys.argv[3]); s=p.read_text()
repls={
  'real(real64), parameter :: initial_head_cm = -75.0_real64':f'real(real64), parameter :: initial_head_cm = {h0:.17e}_real64',
  'real(real64), parameter :: predictor_bottom_head_cm = -74.99_real64':f'real(real64), parameter :: predictor_bottom_head_cm = {hb:.17e}_real64'
}
for old,new in repls.items():
    if s.count(old)!=1: raise SystemExit('C3 driver token drift: '+old)
    s=s.replace(old,new,1)
p.write_text(s)
PY
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$driver" -o "$out/case_${case_id}.o"
    gfortran "$opt" "${objects[@]}" "$out/case_${case_id}.o" -o "$out/case_${case_id}"
    timeout 300s "$out/case_${case_id}" > "$out/case_${case_id}.txt" 2>&1 || {
      cat "$out/case_${case_id}.txt" >&2
      fail "case $case_id execution opt=$tag"
    }
    grep -Fq 'FSI23_C3_TRANSACTION_LOCAL_CASE PASS' "$out/case_${case_id}.txt" || {
      cat "$out/case_${case_id}.txt" >&2
      fail "case $case_id PASS marker missing opt=$tag"
    }
    [[ "$(grep -c '^FSI23_C3_ROW:' "$out/case_${case_id}.txt")" -eq 10 ]] || fail "case $case_id row count opt=$tag"
    echo "FSI23_C3_CASE_RUN=PASS:OPT=$tag:CASE=$case_id:H0=$h0:JUMP=$jump"
  done
}

run_matrix -O0 o0
run_matrix -O2 o2
for i in $(seq 1 ${#CASES[@]}); do
  cmp "$BUILD/o0/case_${i}.txt" "$BUILD/o2/case_${i}.txt" || {
    diff -u "$BUILD/o0/case_${i}.txt" "$BUILD/o2/case_${i}.txt" >&2 || true
    fail "O0/O2 drift case $i"
  }
done
echo 'FSI23_C3_O0_O2_IDENTITY=PASS'

python3 - "$BUILD" <<'PY'
from pathlib import Path
import math,re,sys
build=Path(sys.argv[1])
pat=re.compile(
 r'^FSI23_C3_ROW:HALVING=(\d+):DT=\s*([^:]+):EOBS=\s*([^:]+):E1_8=\s*([^:]+):D4_8=\s*([^:]+)'
 r':RATIO_AVAILABLE=(YES|NO\s*):R8=\s*([^:]+):TAIL_AVAILABLE=(YES|NO\s*):TAIL_FRACTION=\s*([^:]+)'
 r':EOBS_GE_E1_8=(YES|NO\s*):XEFF=\s*([^:]+):XEFF_AVAILABLE=(YES|NO\s*)'
 r':LINEAR_R8_PRED=\s*([^:]+):LINEAR_PRED_AVAILABLE=(YES|NO\s*):BOTTOM_DERIV_RATIO=\s*([^:]+):MAX_MASS=\s*(\S+)$')
rows=[]
case_specs=[
 (-25.0,-0.1),(-25.0,-0.01),(-25.0,0.001),(-25.0,0.01),(-25.0,0.1),
 (-75.0,-0.1),(-75.0,-0.01),(-75.0,0.001),(-75.0,0.01),(-75.0,0.1),
 (-250.0,-0.1),(-250.0,-0.01),(-250.0,0.001),(-250.0,0.01),(-250.0,0.1)]
for cid,(h0,jump) in enumerate(case_specs,1):
    lines=(build/'o0'/f'case_{cid}.txt').read_text().splitlines()
    matches=[pat.match(x) for x in lines if x.startswith('FSI23_C3_ROW:')]
    if len(matches)!=10 or any(m is None for m in matches):
        raise SystemExit(f'case {cid}: malformed C3 rows')
    case=[]
    for m in matches:
        halving=int(m.group(1)); dt=float(m.group(2)); eobs=float(m.group(3)); e18=float(m.group(4)); d48=float(m.group(5))
        ravail=m.group(6).strip()=='YES'; r8=float(m.group(7)); tavail=m.group(8).strip()=='YES'; tail=float(m.group(9))
        ge=m.group(10).strip()=='YES'; xeff=float(m.group(11)); xavail=m.group(12).strip()=='YES'
        pred=float(m.group(13)); pavail=m.group(14).strip()=='YES'; dratio=float(m.group(15)); mass=float(m.group(16))
        for x in (dt,eobs,e18,d48,mass):
            if not math.isfinite(x): raise SystemExit(f'case {cid} h{halving}: nonfinite primary observable')
        if min(dt,eobs,e18,d48,mass)<0.0: raise SystemExit(f'case {cid} h{halving}: negative primary observable')
        if mass>1e-12: raise SystemExit(f'case {cid} h{halving}: mass gate exceeded')
        if ravail and (not math.isfinite(r8) or r8<0.0): raise SystemExit(f'case {cid} h{halving}: invalid R8')
        if tavail and (not math.isfinite(tail) or tail<0.0): raise SystemExit(f'case {cid} h{halving}: invalid tail')
        if xavail and (not math.isfinite(xeff) or xeff<0.0): raise SystemExit(f'case {cid} h{halving}: invalid XEFF')
        if pavail and (not math.isfinite(pred) or pred<0.0): raise SystemExit(f'case {cid} h{halving}: invalid linear prediction')
        row=dict(case=cid,h0=h0,jump=jump,halving=halving,dt=dt,eobs=eobs,e18=e18,d48=d48,
                 ravail=ravail,r8=r8,tavail=tavail,tail=tail,ge=ge,xeff=xeff,xavail=xavail,
                 pred=pred,pavail=pavail,dratio=dratio,mass=mass)
        rows.append(row); case.append(row)
    if [r['halving'] for r in case] != list(range(10)):
        raise SystemExit(f'case {cid}: halving sequence drift')

for r in rows:
    print('FSI23_C3_AGG_ROW:CASE='+str(r['case'])+':H0_CM='+f"{r['h0']:.17e}"+':JUMP_CM='+f"{r['jump']:.17e}"+
          ':HALVING='+str(r['halving'])+':DT_DAY='+f"{r['dt']:.17e}"+':EOBS_CM='+f"{r['eobs']:.17e}"+
          ':E1_8_CM='+f"{r['e18']:.17e}"+':R8='+f"{r['r8']:.17e}"+':D4_8_CM='+f"{r['d48']:.17e}"+
          ':TAIL_FRACTION='+f"{r['tail']:.17e}"+':RELATION='+('FINITE_REFERENCE_CONSISTENT' if r['ge'] else 'NEGATIVE_TRANSFER_EVIDENCE')+
          ':XEFF='+f"{r['xeff']:.17e}"+':XEFF_AVAILABLE='+('YES' if r['xavail'] else 'NO')+
          ':LINEAR_R8_PRED='+f"{r['pred']:.17e}"+':LINEAR_PRED_AVAILABLE='+('YES' if r['pavail'] else 'NO')+
          ':MAX_MASS='+f"{r['mass']:.17e}")

print('FSI23_C3_CASES=15')
print('FSI23_C3_ATTEMPTS_PER_CASE=10')
print('FSI23_C3_TOTAL_ATTEMPT_ROWS='+str(len(rows)))
print('FSI23_C3_FINITE_REFERENCE_CONSISTENT_ROWS='+str(sum(r['ge'] for r in rows)))
print('FSI23_C3_NEGATIVE_TRANSFER_ROWS='+str(sum(not r['ge'] for r in rows)))
print('FSI23_C3_XEFF_AVAILABLE_ROWS='+str(sum(r['xavail'] for r in rows)))
print('FSI23_C3_LINEAR_PRED_AVAILABLE_ROWS='+str(sum(r['pavail'] for r in rows)))
for h0 in (-25.0,-75.0,-250.0):
    sub=[r for r in rows if r['h0']==h0]
    starts=[r['r8'] for r in sub if r['halving']==0 and r['ravail']]
    ends=[r['r8'] for r in sub if r['halving']==9 and r['ravail']]
    tails=[r['tail'] for r in sub if r['halving']==9 and r['tavail']]
    case_ids=sorted(set(r['case'] for r in sub))
    monotone=0
    for cid in case_ids:
        seq=[r['r8'] for r in sub if r['case']==cid and r['ravail']]
        if len(seq)==10 and all(b<=a for a,b in zip(seq,seq[1:])): monotone+=1
    print('FSI23_C3_STATE:H0_CM='+f'{h0:.17e}'+':R8_START_MIN='+f'{min(starts):.17e}'+':R8_START_MAX='+f'{max(starts):.17e}'+
          ':R8_END_MIN='+f'{min(ends):.17e}'+':R8_END_MAX='+f'{max(ends):.17e}'+
          ':END_TAIL_MIN='+f'{min(tails):.17e}'+':END_TAIL_MAX='+f'{max(tails):.17e}'+
          ':MONOTONE_NONINCREASING_CASES='+str(monotone)+':STATE_CASES=5')
print('FSI23_C3_N8_EXACT_REFERENCE=NO')
print('FSI23_C3_TRUE_ERROR_BOUND_QUALIFIED=NO')
print('FSI23_C3_GLOBAL_SCALE_FIT=NO')
print('FSI23_C3_TEMPORAL_THRESHOLD_SELECTED=NO')
print('FSI23_C3_CERTIFICATE_NORMALIZATION_SELECTED=NO')
print('FSI23_C3_CHARACTERIZATION PASS')
PY

git diff --quiet "$BASE" -- \
  src/solver \
  src/legacy/b1_10_port/headcalc.f90 \
  src/adapter/mod_reference_richards_legacy_binding.f90 \
  src/runtime/mod_a23bu_worker_execution_context.f90 \
  tests/fmr/mod_fmr04_fixed_top_provider.f90 \
  || fail 'production source changed during C3'
echo 'FSI23_C3_PRODUCTION_SOURCE_UNCHANGED=PASS'
echo 'FSI23_C3_GATE PASS'
