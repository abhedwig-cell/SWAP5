#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi24-gate-c-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=81185df08c5231d3990c9a941591d444e880a077
GATE_B_EVIDENCE=integration/f-si/F-SI24_GATE_B_EXACT_MANUFACTURED_EVIDENCE.json
GATE_B_EVIDENCE_BLOB=be5a552660e0383f3e6a45801ca48a3a5d14a24f
PLAN=integration/f-si/F-SI24_GATE_C_NONLINEAR_B110_PLAN.json
PLAN_COMMIT=0252fb7f5a7945e96d0b6a1191616064fa9b3c02
DRIVER=tests/fsi/test_fsi24_gate_c_nonlinear_b110.f90
DRIVER_COMMIT=5a8e8527028b84b26c1bdd927b5a356e1f47b0b4
C2_EVIDENCE=integration/f-si/F-SI23_GATE_C2_PHYSICAL_TRANSFER_EVIDENCE.json
C2_EVIDENCE_BLOB=cac160dbbdbb89b172d2afa055994d918abb0bbc
STUB=tests/fsi/fsi04_real_headcalc_stubs.f90
FSI18_BRANCH=origin/work/f-si18-reference-convergence-cliff
FSI18_GENERATOR=tests/fsi/fsi18_make_reference_tridag_stubs.py
FSI18_GENERATOR_BLOB=bf25c4c7fefaa59811255b0bc25c041522ab008e

fail() { echo "FSI24_GATE_C_RUNNER_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PLAN_COMMIT" HEAD || fail 'Gate-C plan commit not in branch history'
git merge-base --is-ancestor "$DRIVER_COMMIT" HEAD || fail 'Gate-C driver commit not in branch history'
git diff --quiet "$PLAN_COMMIT" -- "$PLAN" || fail 'Gate-C plan drift after freeze'
git diff --quiet "$DRIVER_COMMIT" -- "$DRIVER" || fail 'Gate-C driver drift after freeze'
[[ "$(git rev-parse HEAD:$C2_EVIDENCE)" == "$C2_EVIDENCE_BLOB" ]] || fail 'persisted F-SI23 C2 comparator evidence drift'
[[ "$(git rev-parse HEAD:$GATE_B_EVIDENCE)" == "$GATE_B_EVIDENCE_BLOB" ]] || fail 'F-SI24 Gate-B evidence drift'

git diff --quiet "$BASE" -- \
  src/solver \
  src/legacy/b1_10_port/headcalc.f90 \
  src/adapter/mod_reference_richards_legacy_binding.f90 \
  src/runtime/mod_a23bu_worker_execution_context.f90 \
  tests/fmr/mod_fmr04_fixed_top_provider.f90 \
  || fail 'production Richards/runtime source drift from F-SI24 base'
echo 'FSI24_GATE_C_SOURCE_PLAN_COMPARATOR_DRIVER_LOCK=PASS'

git fetch --quiet --no-tags origin work/f-si18-reference-convergence-cliff:refs/remotes/origin/work/f-si18-reference-convergence-cliff
[[ "$(git rev-parse "$FSI18_BRANCH:$FSI18_GENERATOR")" == "$FSI18_GENERATOR_BLOB" ]] || fail 'F-SI18 TRIDAG generator drift'
git show "$FSI18_BRANCH:$FSI18_GENERATOR" > "$BUILD/make_reference_tridag.py"
python3 "$BUILD/make_reference_tridag.py" "$STUB" "$BUILD/reference_tridag_stubs.f90"
grep -Fq 'SWAP 4.3.1 tridag.f90' "$BUILD/reference_tridag_stubs.f90" || fail 'reference TRIDAG marker missing'
if grep -Fq 'solution(i) = 0.0d0' "$BUILD/reference_tridag_stubs.f90"; then
  fail 'zero-correction TRIDAG survived reference replacement'
fi
echo 'FSI24_GATE_C_REFERENCE_TRIDAG=PASS'

python3 - "$C2_EVIDENCE" "$BUILD/cases.tsv" <<'PY'
import json,sys
src,out=sys.argv[1:]
d=json.load(open(src))
rows=d['rows']
if len(rows)!=15: raise SystemExit('expected 15 persisted C2 rows')
with open(out,'w') as f:
    for r in rows:
        f.write(f"{r['case']}\t{r['h0_cm']:.17e}\t{r['jump_cm']:.17e}\t{r['EOBS_cm']:.17e}\t{r['E1_512_cm']:.17e}\n")
PY

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

build_and_run() {
  local opt="$1"
  local tag="$2"
  local out="$BUILD/$tag"
  mkdir -p "$out"
  local objects=()
  for src in "${MODULE_SRC[@]}"; do
    local obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$DRIVER" -o "$out/test.o"
  gfortran "$opt" "${objects[@]}" "$out/test.o" -o "$out/test"

  while IFS=$'\t' read -r cid h0 jump eobs e1512; do
    timeout 120s "$out/test" "$h0" "$jump" "$eobs" "$e1512" > "$out/case_${cid}.txt" 2>&1 || {
      cat "$out/case_${cid}.txt" >&2
      fail "Gate-C case $cid execution failed opt=$tag"
    }
    grep -Fq 'FSI24_GATE_C_NONLINEAR_CASE PASS' "$out/case_${cid}.txt" || {
      cat "$out/case_${cid}.txt" >&2
      fail "Gate-C case $cid PASS marker missing opt=$tag"
    }
    [[ "$(grep -c '^FSI24_GC_ROW:' "$out/case_${cid}.txt")" -eq 1 ]] || fail "case $cid row count opt=$tag"
    [[ "$(grep -c '^FSI24_GC_DIAG:' "$out/case_${cid}.txt")" -eq 1 ]] || fail "case $cid diag count opt=$tag"
    echo "FSI24_GATE_C_CASE_RUN=PASS:OPT=$tag:CASE=$cid:H0=$h0:JUMP=$jump"
  done < "$BUILD/cases.tsv"
}

build_and_run -O0 o0
build_and_run -O2 o2
for i in $(seq 1 15); do
  cmp "$BUILD/o0/case_${i}.txt" "$BUILD/o2/case_${i}.txt" || {
    diff -u "$BUILD/o0/case_${i}.txt" "$BUILD/o2/case_${i}.txt" >&2 || true
    fail "O0/O2 drift case $i"
  }
done
echo 'FSI24_GATE_C_O0_O2_IDENTITY=PASS'

python3 - "$BUILD" <<'PY'
from pathlib import Path
import re,math,sys
b=Path(sys.argv[1])
pat=re.compile(
 r'^FSI24_GC_ROW:H0=\s*([^:]+):JUMP=\s*([^:]+):EOBS=\s*([^:]+):E1_512=\s*([^:]+)'
 r':RAW_M=\s*([^:]+):D2_M=\s*([^:]+):BM=\s*([^:]+):BINF=\s*([^:]+):DINF=\s*([^:]+)'
 r':MIN_M=\s*([^:]+):BINF_GE_E1_512=(YES|NO\s*):RAW_RATIO=\s*([^:]+):BINF_RATIO=\s*([^:]+):DINF_RATIO=\s*(\S+)$')
rows=[]
for cid in range(1,16):
    lines=(b/'o0'/f'case_{cid}.txt').read_text().splitlines()
    ms=[pat.match(x) for x in lines if x.startswith('FSI24_GC_ROW:')]
    if len(ms)!=1 or ms[0] is None: raise SystemExit(f'case {cid}: malformed Gate-C row')
    m=ms[0]
    vals=[float(m.group(i)) for i in range(1,11)]
    h0,jump,eobs,e1512,rawm,d2m,bm,binf,dinf,minm=vals
    ge=m.group(11).strip()=='YES'
    rawr,binfr,dinfr=(float(m.group(i)) for i in range(12,15))
    allvals=vals+[rawr,binfr,dinfr]
    if not all(math.isfinite(x) for x in allvals): raise SystemExit(f'case {cid}: nonfinite aggregate value')
    if min(eobs,e1512,rawm,d2m,bm,binf,dinf,minm)<0: raise SystemExit(f'case {cid}: negative metric')
    rows.append(dict(case=cid,h0=h0,jump=jump,eobs=eobs,e1512=e1512,rawm=rawm,d2m=d2m,bm=bm,
                     binf=binf,dinf=dinf,minm=minm,ge=ge,rawr=rawr,binfr=binfr,dinfr=dinfr))
    print('FSI24_GC_AGG_ROW:CASE='+str(cid)+':H0='+f'{h0:.17e}'+':JUMP='+f'{jump:.17e}'+
          ':RAW_RATIO='+f'{rawr:.17e}'+':BINF_RATIO='+f'{binfr:.17e}'+':DINF_RATIO='+f'{dinfr:.17e}'+
          ':BINF_GE_E1_512='+('YES' if ge else 'NO'))
print('FSI24_GATE_C_CASES=15')
print('FSI24_GATE_C_FINITE_COMPARATOR_CONSISTENT='+str(sum(r['ge'] for r in rows)))
print('FSI24_GATE_C_NEGATIVE_TRANSFER='+str(sum(not r['ge'] for r in rows)))
print('FSI24_GATE_C_RAW_RATIO_MIN='+f"{min(r['rawr'] for r in rows):.17e}")
print('FSI24_GATE_C_RAW_RATIO_MAX='+f"{max(r['rawr'] for r in rows):.17e}")
print('FSI24_GATE_C_BINF_RATIO_MIN='+f"{min(r['binfr'] for r in rows):.17e}")
print('FSI24_GATE_C_BINF_RATIO_MAX='+f"{max(r['binfr'] for r in rows):.17e}")
for h0 in (-25.0,-75.0,-250.0):
    sub=[r for r in rows if r['h0']==h0]
    print('FSI24_GATE_C_STATE:H0='+f'{h0:.17e}'+':CONSISTENT='+str(sum(r['ge'] for r in sub))+
          ':NEGATIVE='+str(sum(not r['ge'] for r in sub))+':BINF_RATIO_MIN='+f"{min(r['binfr'] for r in sub):.17e}"+
          ':BINF_RATIO_MAX='+f"{max(r['binfr'] for r in sub):.17e}")
print('FSI24_GATE_C_N512_EXACT_REFERENCE=NO')
print('FSI24_GATE_C_TRUE_ERROR_BOUND_QUALIFIED=NO')
print('FSI24_GATE_C_FACTOR_FITTED=NO')
print('FSI24_GATE_C_TEMPORAL_TOLERANCE_SELECTED=NO')
print('FSI24_GATE_C_CHARACTERIZATION PASS')
PY

git diff --quiet "$BASE" -- \
  src/solver \
  src/legacy/b1_10_port/headcalc.f90 \
  src/adapter/mod_reference_richards_legacy_binding.f90 \
  src/runtime/mod_a23bu_worker_execution_context.f90 \
  tests/fmr/mod_fmr04_fixed_top_provider.f90 \
  || fail 'production source changed during Gate C'
echo 'FSI24_GATE_C_PRODUCTION_SOURCE_UNCHANGED=PASS'
echo 'FSI24_GATE_C PASS'
