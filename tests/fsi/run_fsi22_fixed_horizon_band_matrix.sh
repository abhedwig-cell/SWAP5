#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi22-fixed-band-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=0ffd4e304ac5cf66fe7738cac3a1c07308d6c687
DRIVER=tests/fsi/test_fsi20_fixed_horizon_reference.f90
DRIVER_BLOB=5c8ea89bfedd16a57fdfcf38d188a093a2999525
STUB=tests/fsi/fsi04_real_headcalc_stubs.f90
STUB_BLOB=23c00e4a188e88bc36ef95cbe4faaacdd6aad639
FSI18_BRANCH=origin/work/f-si18-reference-convergence-cliff
FSI18_GENERATOR=tests/fsi/fsi18_make_reference_tridag_stubs.py
FSI18_GENERATOR_BLOB=bf25c4c7fefaa59811255b0bc25c041522ab008e

fail() { echo "FSI22_FIXED_BAND_FAIL $*" >&2; exit 1; }

# F-SI22 Gate A is characterization only. Lock the Richards implementation and
# its direct-solver dependencies to the F-KT09-qualified base. Generic F-KT
# transaction changes are outside this direct fixed-horizon driver.
git diff --quiet "$BASE" -- \
  src/solver \
  src/legacy/b1_10_port/headcalc.f90 \
  src/adapter/mod_reference_richards_legacy_binding.f90 \
  src/runtime/mod_a23bu_worker_execution_context.f90 \
  tests/fmr/mod_fmr04_fixed_top_provider.f90 \
  || fail 'Richards/direct-solver source drift from F-SI22 base'
[[ "$(git rev-parse HEAD:$DRIVER)" == "$DRIVER_BLOB" ]] || fail 'fixed-horizon driver drift'
[[ "$(git rev-parse HEAD:$STUB)" == "$STUB_BLOB" ]] || fail 'HeadCalc stub drift'
echo 'FSI22_FIXED_BAND_SOURCE_LOCK=PASS'

git fetch --quiet --no-tags origin work/f-si18-reference-convergence-cliff:refs/remotes/origin/work/f-si18-reference-convergence-cliff
[[ "$(git rev-parse "$FSI18_BRANCH:$FSI18_GENERATOR")" == "$FSI18_GENERATOR_BLOB" ]] || fail 'F-SI18 TRIDAG generator drift'
git show "$FSI18_BRANCH:$FSI18_GENERATOR" > "$BUILD/make_reference_tridag.py"
python3 "$BUILD/make_reference_tridag.py" "$STUB" "$BUILD/reference_tridag_stubs.f90"
grep -Fq 'SWAP 4.3.1 tridag.f90' "$BUILD/reference_tridag_stubs.f90" || fail 'reference TRIDAG marker missing'
if grep -Fq 'solution(i) = 0.0d0' "$BUILD/reference_tridag_stubs.f90"; then
  fail 'zero-correction TRIDAG survived reference replacement'
fi
echo 'FSI22_FIXED_BAND_REFERENCE_TRIDAG=PASS'

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
  local opt="$1" tag="$2" out="$BUILD/$tag"
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
  'real(real64), parameter :: predictor_bottom_head_cm = -74.99_real64':f'real(real64), parameter :: predictor_bottom_head_cm = {hb:.17e}_real64',
  'integer, parameter :: nlevels = 11':'integer, parameter :: nlevels = 10',
  'integer, parameter :: nsteps(nlevels) = [1,2,4,8,16,32,64,128,256,512,1024]':
      'integer, parameter :: nsteps(nlevels) = [1,2,4,8,16,32,64,128,256,512]'
}
for old,new in repls.items():
    if s.count(old)!=1: raise SystemExit('driver token drift: '+old)
    s=s.replace(old,new,1)
p.write_text(s)
PY
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$driver" -o "$out/case_${case_id}.o"
    gfortran "$opt" "${objects[@]}" "$out/case_${case_id}.o" -o "$out/case_${case_id}"
    timeout 300s "$out/case_${case_id}" > "$out/case_${case_id}.txt" 2>&1 || {
      cat "$out/case_${case_id}.txt" >&2
      fail "case $case_id execution"
    }
    grep -Fq 'FSI20_FIXED_HORIZON_REFERENCE_DRIVER PASS' "$out/case_${case_id}.txt" || fail "case $case_id missing PASS"
    echo "FSI22_FIXED_BAND_CASE_RUN=PASS:OPT=$tag:CASE=$case_id:H0=$h0:JUMP=$jump"
  done
}

run_matrix -O0 o0
run_matrix -O2 o2
for i in $(seq 1 ${#CASES[@]}); do
  cmp "$BUILD/o0/case_${i}.txt" "$BUILD/o2/case_${i}.txt" || fail "O0/O2 drift case $i"
done
echo 'FSI22_FIXED_BAND_O0_O2_IDENTITY=PASS'

# Repeat one middle-state and one dry-state case to protect deterministic
# characterization without doubling the full matrix runtime.
for i in 9 14; do
  timeout 300s "$BUILD/o0/case_${i}" > "$BUILD/o0/case_${i}_repeat.txt" 2>&1 || fail "repeat case $i"
  cmp "$BUILD/o0/case_${i}.txt" "$BUILD/o0/case_${i}_repeat.txt" || fail "repeat drift case $i"
done
echo 'FSI22_FIXED_BAND_SELECTED_REPEAT_DETERMINISM=PASS'

python3 - "$BUILD" "${CASES[@]}" <<'PY'
from pathlib import Path
import math,re,sys
build=Path(sys.argv[1]); specs=sys.argv[2:]
eps=sys.float_info.epsilon
rows=[]
all_mass=[]
for cid,spec in enumerate(specs,1):
    h0,jump=map(float,spec.split()); hb=h0+jump
    lines=(build/'o0'/f'case_{cid}.txt').read_text().splitlines()
    endpoints=[]; comps=[]
    for line in lines:
        if line.startswith('FSI20_FIXED_ENDPOINT:'):
            m=re.match(r'FSI20_FIXED_ENDPOINT:N=(\d+):SUB_DT=\s*([^:]+):MAX_MASS_RESIDUAL=\s*([^:]+):MAX_SOLVER_RESIDUAL=\s*(\S+)',line)
            if not m: raise SystemExit('bad endpoint row: '+line)
            endpoints.append((int(m.group(1)),float(m.group(2)),float(m.group(3)),float(m.group(4))))
        elif line.startswith('FSI20_FIXED_COMPARE:'):
            m=re.match(r'FSI20_FIXED_COMPARE:N=(\d+):N2=(\d+):DHEAD_N_N2=\s*([^:]+):DTHETA_N_N2=\s*([^:]+):EHEAD_N_REF=\s*([^:]+):ETHETA_N_REF=\s*([^:]+):EHEAD_N2_REF=\s*([^:]+):ETHETA_N2_REF=\s*([^:]+):SIGNED_STORAGE_N_REF=\s*(\S+)',line)
            if not m: raise SystemExit('bad compare row: '+line)
            comps.append((int(m.group(1)),int(m.group(2)),*(float(m.group(i)) for i in range(3,10))))
    if len(endpoints)!=10 or len(comps)!=9:
        raise SystemExit(f'case {cid}: expected 10 endpoints/9 comparisons, got {len(endpoints)}/{len(comps)}')
    masses=[abs(x[2]) for x in endpoints]
    if max(masses)>1e-12: raise SystemExit(f'case {cid}: hard mass gate exceeded {max(masses)}')
    all_mass.extend(masses)
    d=[x[2] for x in comps]
    if not all(math.isfinite(x) and x>=0.0 for x in d): raise SystemExit(f'case {cid}: invalid dhead')
    floor=128.0*eps*max(1.0,abs(h0),abs(hb))
    resolved=[x>floor for x in d]
    ratios=[]
    for a,b in zip(d[:-1],d[1:]):
        ratios.append(b/a if a>floor and b>floor else math.nan)
    first_two=None
    for j in range(len(d)-2):
        if d[j]>floor and d[j+1]>floor and d[j+2]>floor and d[j+1]<d[j] and d[j+2]<d[j+1]:
            first_two=comps[j][0]; break
    first_three=None
    for j in range(len(d)-3):
        if all(d[j+k]>floor for k in range(4)) and d[j+1]<d[j] and d[j+2]<d[j+1] and d[j+3]<d[j+2]:
            first_three=comps[j][0]; break
    resolved_pairs=sum(1 for a,b in zip(d[:-1],d[1:]) if a>floor and b>floor)
    resolved_contractions=sum(1 for a,b in zip(d[:-1],d[1:]) if a>floor and b>floor and b<a)
    increases=[(comps[j][0],d[j],d[j+1]) for j in range(len(d)-1) if d[j]>floor and d[j+1]>floor and d[j+1]>=d[j]]
    first_conservative=None
    for c in comps:
        n,n2,dhead,_,_,_,ehead2,_,_=c
        if dhead>floor and dhead>=ehead2:
            first_conservative=n; break
    hit_floor=any(x<=floor for x in d)
    ratio_values=[r for r in ratios if math.isfinite(r)]
    row={
      'case':cid,'h0':h0,'jump':jump,'floor':floor,'d':d,'ratios':ratios,
      'first_two':first_two,'first_three':first_three,'pairs':resolved_pairs,
      'contractions':resolved_contractions,'increases':increases,
      'first_conservative':first_conservative,'hit_floor':hit_floor,
      'max_mass':max(masses), 'ratio_min':min(ratio_values) if ratio_values else math.nan,
      'ratio_max':max(ratio_values) if ratio_values else math.nan
    }
    rows.append(row)
    print('FSI22_FIXED_BAND_ROW:CASE='+str(cid)+':H0_CM='+f'{h0:.17e}'+':JUMP_CM='+f'{jump:.17e}'+
          ':DHEADS_CM='+','.join(f'{x:.17e}' for x in d)+
          ':FIRST_TWO_CONSECUTIVE_DECREASE_N='+str(first_two or 0)+
          ':FIRST_THREE_CONSECUTIVE_DECREASE_N='+str(first_three or 0)+
          ':RESOLVED_PAIRS='+str(resolved_pairs)+':RESOLVED_CONTRACTIONS='+str(resolved_contractions)+
          ':RESOLVED_INCREASES='+str(len(increases))+':FIRST_DEFECT_GE_REMAINING_ERROR_N='+str(first_conservative or 0)+
          ':MACHINE_FLOOR_REACHED='+('YES' if hit_floor else 'NO')+
          ':CONTRACTION_RATIO_MIN='+f'{row["ratio_min"]:.17e}'+':CONTRACTION_RATIO_MAX='+f'{row["ratio_max"]:.17e}'+
          ':MAX_EXTERNAL_MASS_RESIDUAL='+f'{max(masses):.17e}')

print('FSI22_FIXED_BAND_CASES='+str(len(rows)))
print('FSI22_FIXED_BAND_ALL_HARD_MASS_PASS='+('YES' if max(all_mass)<=1e-12 else 'NO'))
print('FSI22_FIXED_BAND_CASES_WITH_TWO_CONSECUTIVE_DECREASES='+str(sum(r['first_two'] is not None for r in rows)))
print('FSI22_FIXED_BAND_CASES_WITH_THREE_CONSECUTIVE_DECREASES='+str(sum(r['first_three'] is not None for r in rows)))
print('FSI22_FIXED_BAND_CASES_WITH_RESOLVED_INCREASE='+str(sum(bool(r['increases']) for r in rows)))
print('FSI22_FIXED_BAND_CASES_REACHING_MACHINE_FLOOR='+str(sum(r['hit_floor'] for r in rows)))
print('FSI22_FIXED_BAND_MAX_FIRST_TWO_DECREASE_N='+str(max((r['first_two'] or 0) for r in rows)))
print('FSI22_FIXED_BAND_MAX_FIRST_THREE_DECREASE_N='+str(max((r['first_three'] or 0) for r in rows)))
print('FSI22_FIXED_BAND_PRODUCTION_TOLERANCE_SELECTED=NO')
print('FSI22_FIXED_BAND_NORMALIZATION_SELECTED=NO')
print('FSI22_FIXED_BAND_CERTIFICATE_INDICATOR_SELECTED=NO')
print('FSI22_FIXED_BAND_CHARACTERIZATION_ONLY=PASS')
PY

git diff --quiet "$BASE" -- \
  src/solver \
  src/legacy/b1_10_port/headcalc.f90 \
  src/adapter/mod_reference_richards_legacy_binding.f90 \
  src/runtime/mod_a23bu_worker_execution_context.f90 \
  tests/fmr/mod_fmr04_fixed_top_provider.f90 \
  || fail 'Richards/direct-solver source changed during gate'
echo 'FSI22_FIXED_BAND_PRODUCTION_RICHARDS_SOURCE_UNCHANGED=PASS'
echo 'FSI22_FIXED_HORIZON_BAND_MATRIX PASS'
