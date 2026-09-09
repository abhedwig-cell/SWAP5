#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi23-c2-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=394d064a0dad0a7f7852b129bae99713b9aeb4c0
PLAN=integration/f-si/F-SI23_GATE_C2_PHYSICAL_TRANSFER_PLAN.json
PLAN_BLOB=dc11fab1985cb523b59aaa49d33badcb0a37f3a4
DRIVER=tests/fsi/test_fsi23_gate_c2_physical_transfer.f90
STUB=tests/fsi/fsi04_real_headcalc_stubs.f90
FSI18_BRANCH=origin/work/f-si18-reference-convergence-cliff
FSI18_GENERATOR=tests/fsi/fsi18_make_reference_tridag_stubs.py
FSI18_GENERATOR_BLOB=bf25c4c7fefaa59811255b0bc25c041522ab008e

fail() { echo "FSI23_C2_GATE_FAIL $*" >&2; exit 1; }

git diff --quiet "$BASE" -- \
  src/solver \
  src/legacy/b1_10_port/headcalc.f90 \
  src/adapter/mod_reference_richards_legacy_binding.f90 \
  src/runtime/mod_a23bu_worker_execution_context.f90 \
  tests/fmr/mod_fmr04_fixed_top_provider.f90 \
  || fail 'production Richards/runtime source drift from F-VQ29 base'
[[ "$(git rev-parse HEAD:$PLAN)" == "$PLAN_BLOB" ]] || fail 'C2 plan drift after freeze'
echo 'FSI23_C2_SOURCE_AND_PLAN_LOCK=PASS'

git fetch --quiet --no-tags origin work/f-si18-reference-convergence-cliff:refs/remotes/origin/work/f-si18-reference-convergence-cliff
[[ "$(git rev-parse "$FSI18_BRANCH:$FSI18_GENERATOR")" == "$FSI18_GENERATOR_BLOB" ]] || fail 'F-SI18 TRIDAG generator drift'
git show "$FSI18_BRANCH:$FSI18_GENERATOR" > "$BUILD/make_reference_tridag.py"
python3 "$BUILD/make_reference_tridag.py" "$STUB" "$BUILD/reference_tridag_stubs.f90"
grep -Fq 'SWAP 4.3.1 tridag.f90' "$BUILD/reference_tridag_stubs.f90" || fail 'reference TRIDAG marker missing'
if grep -Fq 'solution(i) = 0.0d0' "$BUILD/reference_tridag_stubs.f90"; then
  fail 'zero-correction TRIDAG survived reference replacement'
fi
echo 'FSI23_C2_REFERENCE_TRIDAG=PASS'

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
  local opt="$1"
  local out="$2"
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
    local driver="$out/case_${case_id}.f90"
    local hb
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
    if s.count(old)!=1: raise SystemExit('C2 driver token drift: '+old)
    s=s.replace(old,new,1)
p.write_text(s)
PY
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$driver" -o "$out/case_${case_id}.o"
    gfortran "$opt" "${objects[@]}" "$out/case_${case_id}.o" -o "$out/case_${case_id}"
    timeout 300s "$out/case_${case_id}" > "$out/case_${case_id}.txt" 2>&1 || {
      cat "$out/case_${case_id}.txt" >&2
      fail "case $case_id execution opt=$tag"
    }
    grep -Fq 'FSI23_C2_PHYSICAL_TRANSFER_CASE PASS' "$out/case_${case_id}.txt" || {
      cat "$out/case_${case_id}.txt" >&2
      fail "case $case_id PASS marker missing opt=$tag"
    }
    [[ "$(grep -c '^FSI23_C2_ROW:' "$out/case_${case_id}.txt")" -eq 1 ]] || fail "case $case_id row count opt=$tag"
    echo "FSI23_C2_CASE_RUN=PASS:OPT=$tag:CASE=$case_id:H0=$h0:JUMP=$jump"
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
echo 'FSI23_C2_O0_O2_IDENTITY=PASS'

python3 - "$BUILD" <<'PY'
from pathlib import Path
import math,re,sys
build=Path(sys.argv[1])
rows=[]
pat=re.compile(
 r'^FSI23_C2_ROW:H0=\s*([^:]+):JUMP=\s*([^:]+):EOBS=\s*([^:]+):E1_512=\s*([^:]+)'
 r':D128_256=\s*([^:]+):D256_512=\s*([^:]+):FLOOR=\s*([^:]+)'
 r':RATIO_AVAILABLE=(YES|NO\s*):EOBS_GE_E1_512=(YES|NO\s*):R512=\s*([^:]+):MAX_MASS=\s*(\S+)$')
for cid in range(1,16):
    lines=(build/'o0'/f'case_{cid}.txt').read_text().splitlines()
    matches=[pat.match(x) for x in lines if x.startswith('FSI23_C2_ROW:')]
    if len(matches)!=1 or matches[0] is None:
        raise SystemExit(f'case {cid}: malformed C2 row')
    m=matches[0]
    h0,jump,eobs,e1512,d128,d256,floor=(float(m.group(i)) for i in range(1,8))
    ravail=m.group(8).strip()=='YES'
    ge=m.group(9).strip()=='YES'
    r512=float(m.group(10)); mass=float(m.group(11))
    vals=[eobs,e1512,d128,d256,floor,mass]
    if not all(math.isfinite(x) for x in vals): raise SystemExit(f'case {cid}: nonfinite observable')
    if min(eobs,e1512,d128,d256,floor)<0.0: raise SystemExit(f'case {cid}: negative observable')
    if mass>1e-12: raise SystemExit(f'case {cid}: mass gate exceeded')
    if ravail and (not math.isfinite(r512) or r512<0.0): raise SystemExit(f'case {cid}: invalid available ratio')
    rows.append(dict(case=cid,h0=h0,jump=jump,eobs=eobs,e1512=e1512,d128=d128,d256=d256,
                     floor=floor,ratio_available=ravail,ge=ge,r512=r512,mass=mass))

for r in rows:
    relation='FINITE_REFERENCE_CONSISTENT' if r['ge'] else 'NEGATIVE_TRANSFER_EVIDENCE'
    print('FSI23_C2_AGG_ROW:CASE='+str(r['case'])+
          ':H0_CM='+f"{r['h0']:.17e}"+':JUMP_CM='+f"{r['jump']:.17e}"+
          ':EOBS_CM='+f"{r['eobs']:.17e}"+':E1_512_CM='+f"{r['e1512']:.17e}"+
          ':R512='+f"{r['r512']:.17e}"+':RATIO_AVAILABLE='+('YES' if r['ratio_available'] else 'NO')+
          ':D128_256_CM='+f"{r['d128']:.17e}"+':D256_512_CM='+f"{r['d256']:.17e}"+
          ':FLOOR_CM='+f"{r['floor']:.17e}"+':RELATION='+relation+
          ':MAX_MASS='+f"{r['mass']:.17e}")

print('FSI23_C2_CASES=15')
print('FSI23_C2_FINITE_REFERENCE_CONSISTENT_CASES='+str(sum(r['ge'] for r in rows)))
print('FSI23_C2_NEGATIVE_TRANSFER_CASES='+str(sum(not r['ge'] for r in rows)))
for h0 in (-25.0,-75.0,-250.0):
    sub=[r for r in rows if r['h0']==h0]
    ratios=[r['r512'] for r in sub if r['ratio_available']]
    print('FSI23_C2_STATE:H0_CM='+f'{h0:.17e}'+
          ':CONSISTENT='+str(sum(r['ge'] for r in sub))+':NEGATIVE='+str(sum(not r['ge'] for r in sub))+
          ':R512_MIN='+(f'{min(ratios):.17e}' if ratios else 'NA')+
          ':R512_MAX='+(f'{max(ratios):.17e}' if ratios else 'NA'))
print('FSI23_C2_N512_EXACT_REFERENCE=NO')
print('FSI23_C2_TRUE_ERROR_BOUND_QUALIFIED=NO')
print('FSI23_C2_TEMPORAL_THRESHOLD_SELECTED=NO')
print('FSI23_C2_CERTIFICATE_NORMALIZATION_SELECTED=NO')
print('FSI23_C2_CHARACTERIZATION PASS')
PY

git diff --quiet "$BASE" -- \
  src/solver \
  src/legacy/b1_10_port/headcalc.f90 \
  src/adapter/mod_reference_richards_legacy_binding.f90 \
  src/runtime/mod_a23bu_worker_execution_context.f90 \
  tests/fmr/mod_fmr04_fixed_top_provider.f90 \
  || fail 'production source changed during C2'
echo 'FSI23_C2_PRODUCTION_SOURCE_UNCHANGED=PASS'
echo 'FSI23_C2_GATE PASS'
