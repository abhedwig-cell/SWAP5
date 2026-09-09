#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq30-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=52e53c956d575fc6fb16423a8ab0a566118b83df
PLAN=integration/f-vq/F-VQ30_QUALIFICATION_PLAN.json
PLAN_COMMIT=c8f56d352cfd485f4bf33e3ce0a593a1a2ca2112
OWNER_PROFILE=integration/f-si/F-SI24_OWNER_CANDIDATE_PROFILE.json
OWNER_PROFILE_BLOB=e3d16aec6e74892ddfb1ff050994b04389c54214
GATE_B_EVIDENCE=integration/f-si/F-SI24_GATE_B_EXACT_MANUFACTURED_EVIDENCE.json
GATE_B_EVIDENCE_BLOB=be5a552660e0383f3e6a45801ca48a3a5d14a24f
GATE_C_PLAN=integration/f-si/F-SI24_GATE_C_NONLINEAR_B110_PLAN.json
GATE_C_PLAN_BLOB=c349d12b4de84d0f503c475ba308bd92ce1f8afd
GATE_C_EVIDENCE=integration/f-si/F-SI24_GATE_C_NONLINEAR_B110_EVIDENCE.json
GATE_C_EVIDENCE_BLOB=efffd6fced5443462c5a46c571dcc15bf039317b
LINEAR=tests/fvq/test_fvq30_exact_linear_regression.py
C2_DRIVER=tests/fsi/test_fsi23_gate_c2_physical_transfer.f90
C2_DRIVER_BLOB=746ecc7f8d76b1deec0572e890d1e302deadbf92
CAND_DRIVER=tests/fsi/test_fsi24_gate_c_nonlinear_b110.f90
CAND_DRIVER_BLOB=ecacaf1c004c7118f1ada388c672166d9ad19345
STUB=tests/fsi/fsi04_real_headcalc_stubs.f90
FSI18_BRANCH=origin/work/f-si18-reference-convergence-cliff
FSI18_GENERATOR=tests/fsi/fsi18_make_reference_tridag_stubs.py
FSI18_GENERATOR_BLOB=bf25c4c7fefaa59811255b0bc25c041522ab008e

fail() { echo "FVQ30_RUNNER_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PLAN_COMMIT" HEAD || fail 'frozen plan commit not in branch history'
git diff --quiet "$PLAN_COMMIT" -- "$PLAN" || fail 'held-out plan drift after freeze'
[[ "$(git rev-parse "$BASE:$OWNER_PROFILE")" == "$OWNER_PROFILE_BLOB" ]] || fail 'owner profile source lock drift'
[[ "$(git rev-parse "$BASE:$GATE_B_EVIDENCE")" == "$GATE_B_EVIDENCE_BLOB" ]] || fail 'Gate-B evidence source lock drift'
[[ "$(git rev-parse "$BASE:$GATE_C_PLAN")" == "$GATE_C_PLAN_BLOB" ]] || fail 'Gate-C plan source lock drift'
[[ "$(git rev-parse "$BASE:$GATE_C_EVIDENCE")" == "$GATE_C_EVIDENCE_BLOB" ]] || fail 'Gate-C evidence source lock drift'
[[ "$(git rev-parse "$BASE:$C2_DRIVER")" == "$C2_DRIVER_BLOB" ]] || fail 'finite-comparator driver drift'
[[ "$(git rev-parse "$BASE:$CAND_DRIVER")" == "$CAND_DRIVER_BLOB" ]] || fail 'candidate driver drift'

git diff --quiet "$BASE" -- \
  src/solver \
  src/legacy/b1_10_port/headcalc.f90 \
  src/adapter/mod_reference_richards_legacy_binding.f90 \
  src/runtime/mod_a23bu_worker_execution_context.f90 \
  tests/fmr/mod_fmr04_fixed_top_provider.f90 \
  || fail 'production Richards/runtime/adapter source changed from frozen owner head'
echo 'FVQ30_G01_SOURCE_LOCK=PASS'

python3 - "$PLAN" "$OWNER_PROFILE" "$GATE_C_PLAN" "$BUILD/cases.tsv" <<'PY'
import json,sys
plan_path,profile_path,owner_plan_path,out=sys.argv[1:]
p=json.load(open(plan_path)); profile=json.load(open(profile_path)); op=json.load(open(owner_plan_path))
assert p['frozen_before_execution'] is True
assert p['base_commit']=='52e53c956d575fc6fb16423a8ab0a566118b83df'
assert profile['candidate_id']=='F_SI24_LINEAR_MNORM_MIN_RAW_OR_DOUBLE_DEFECT_BOUND'
sem=p['candidate_semantics']
assert sem['analytic_factor']==2.0 and sem['factor_fitted'] is False
assert sem['global_scale_fitted'] is False and sem['state_normalization_fitted'] is False
assert sem['scientific_tolerance_selected'] is False
m=p['held_out_matrix']; cases=m['cases']
assert len(cases)==16 and m['case_count']==16
owner_h=set(op['matrix']['initial_uniform_heads_cm'])
owner_j=set(op['matrix']['prescribed_bottom_head_jumps_cm'])
owner_t={op['matrix']['attempt_horizon_day']}
overlap=[]
for c in cases:
    if c['h0_cm'] in owner_h and c['jump_cm'] in owner_j and c['horizon_day'] in owner_t:
        overlap.append(c['case'])
assert not overlap
assert m['exact_triplet_overlap_with_owner_matrix']==0
assert p['finite_comparator_semantics']['N512_exact_truth'] is False
assert p['finite_comparator_semantics']['deep_reference_trajectories_are_candidate_production_cost'] is False
assert p['gates']['VQ30_G09_FVQ28_RECONCILIATION'].startswith('This candidate is not raw step-doubling')
with open(out,'w') as f:
    for c in cases:
        f.write(f"{c['case']}\t{c['h0_cm']:.17e}\t{c['jump_cm']:.17e}\t{c['horizon_day']:.17e}\n")
print('FVQ30_FROZEN_MATRIX_CASES=16')
print('FVQ30_OWNER_EXACT_TRIPLET_OVERLAP=0')
print('FVQ30_G08_NO_EMPIRICAL_RESCUE_PRELOCK=PASS')
print('FVQ30_G09_FVQ28_RECONCILIATION_PRELOCK=PASS')
PY

python3 "$LINEAR" | tee "$BUILD/exact_linear.txt"
grep -Fq 'FVQ30_G02_EXACT_LINEAR_REGRESSION PASS' "$BUILD/exact_linear.txt" || fail 'independent exact-linear regression did not pass'

git fetch --quiet --no-tags origin work/f-si18-reference-convergence-cliff:refs/remotes/origin/work/f-si18-reference-convergence-cliff
[[ "$(git rev-parse "$FSI18_BRANCH:$FSI18_GENERATOR")" == "$FSI18_GENERATOR_BLOB" ]] || fail 'F-SI18 TRIDAG generator drift'
git show "$FSI18_BRANCH:$FSI18_GENERATOR" > "$BUILD/make_reference_tridag.py"
python3 "$BUILD/make_reference_tridag.py" "$STUB" "$BUILD/reference_tridag_stubs.f90"
grep -Fq 'SWAP 4.3.1 tridag.f90' "$BUILD/reference_tridag_stubs.f90" || fail 'reference TRIDAG marker missing'
if grep -Fq 'solution(i) = 0.0d0' "$BUILD/reference_tridag_stubs.f90"; then
  fail 'zero-correction TRIDAG survived reference replacement'
fi
echo 'FVQ30_REFERENCE_TRIDAG=PASS'

[[ "$(grep -c 'call solver%solve' "$CAND_DRIVER")" -eq 1 ]] || fail 'candidate characterization driver nonlinear solve call count drift'
[[ "$(grep -c 'call reference_tridag' "$CAND_DRIVER")" -eq 1 ]] || fail 'candidate characterization driver tridiagonal solve call count drift'
if grep -Eq 'nsteps|run_trajectory|N512|512' "$CAND_DRIVER"; then
  fail 'candidate driver unexpectedly contains a refinement trajectory'
fi
python3 - "$OWNER_PROFILE" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
o=p['observer_and_companion']; shape=p['candidate_production_shape_if_later_qualified']; op=p['operator_contract_boundary']
assert o['extra_full_nonlinear_solves']==0
assert o['extra_tridiagonal_solves']==1
assert shape['full_refinement_ladder_in_normal_path'] is False
assert op['existing_workspace_dfdh_is_exact_accepted_state_J'] is False
assert op['invariant_22_binding'] is True
assert 'solver-owned' in op['production_requirement']
print('FVQ30_G04_BOUNDED_COST_OWNER_SHAPE=PASS')
print('FVQ30_G07_OPERATOR_OWNERSHIP=PASS')
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

build_modules() {
  local opt="$1" out="$2"
  mkdir -p "$out"
  : > "$out/objects.txt"
  for src in "${MODULE_SRC[@]}"; do
    local obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    echo "$obj" >> "$out/objects.txt"
  done
}

run_matrix() {
  local opt="$1" tag="$2" out="$BUILD/$tag"
  build_modules "$opt" "$out"
  mapfile -t objects < "$out/objects.txt"
  while IFS=$'\t' read -r cid h0 jump horizon; do
    local hbot c2src c2obj c2exe c2out candsrc candobj candexe candout vals eobs e1512
    hbot="$(python3 - <<PY
print(f'{float("$h0")+float("$jump"):.17e}')
PY
)"
    c2src="$out/c2_case_${cid}.f90"
    cp "$C2_DRIVER" "$c2src"
    python3 - "$c2src" "$h0" "$hbot" "$horizon" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); h0=float(sys.argv[2]); hb=float(sys.argv[3]); dt=float(sys.argv[4]); s=p.read_text()
repls={
 'real(real64), parameter :: total_dt = 0.25_real64':f'real(real64), parameter :: total_dt = {dt:.17e}_real64',
 'real(real64), parameter :: initial_head_cm = -75.0_real64':f'real(real64), parameter :: initial_head_cm = {h0:.17e}_real64',
 'real(real64), parameter :: predictor_bottom_head_cm = -74.99_real64':f'real(real64), parameter :: predictor_bottom_head_cm = {hb:.17e}_real64'
}
for old,new in repls.items():
    if s.count(old)!=1: raise SystemExit('FVQ30 comparator source token drift: '+old)
    s=s.replace(old,new,1)
p.write_text(s)
PY
    c2obj="$out/c2_case_${cid}.o"; c2exe="$out/c2_case_${cid}"; c2out="$out/c2_case_${cid}.txt"
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$c2src" -o "$c2obj"
    gfortran "$opt" "${objects[@]}" "$c2obj" -o "$c2exe"
    timeout 360s "$c2exe" > "$c2out" 2>&1 || { cat "$c2out" >&2; fail "qualification comparator failed case=$cid opt=$tag"; }
    grep -Fq 'FSI23_C2_PHYSICAL_TRANSFER_CASE PASS' "$c2out" || { cat "$c2out" >&2; fail "comparator PASS marker missing case=$cid opt=$tag"; }
    vals="$(python3 - "$c2out" <<'PY'
import re,sys
s=open(sys.argv[1]).read().splitlines()
pat=re.compile(r'^FSI23_C2_ROW:H0=\s*([^:]+):JUMP=\s*([^:]+):EOBS=\s*([^:]+):E1_512=\s*([^:]+):D128_256=\s*([^:]+):D256_512=\s*([^:]+):FLOOR=\s*([^:]+):RATIO_AVAILABLE=(YES|NO\s*):EOBS_GE_E1_512=(YES|NO\s*):R512=\s*([^:]+):MAX_MASS=\s*(\S+)$')
rows=[pat.match(x) for x in s if x.startswith('FSI23_C2_ROW:')]
if len(rows)!=1 or rows[0] is None: raise SystemExit('malformed comparator row')
m=rows[0]
print(m.group(3),m.group(4),m.group(5),m.group(6),m.group(7),m.group(11))
PY
)"
    read -r eobs e1512 _ <<<"$vals"

    candsrc="$out/candidate_case_${cid}.f90"
    cp "$CAND_DRIVER" "$candsrc"
    python3 - "$candsrc" "$horizon" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); dt=float(sys.argv[2]); s=p.read_text()
old='real(real64), parameter :: total_dt=0.25_real64, hard_mass_gate=1.0e-12_real64'
new=f'real(real64), parameter :: total_dt={dt:.17e}_real64, hard_mass_gate=1.0e-12_real64'
if s.count(old)!=1: raise SystemExit('FVQ30 candidate horizon token drift')
p.write_text(s.replace(old,new,1))
PY
    candobj="$out/candidate_case_${cid}.o"; candexe="$out/candidate_case_${cid}"; candout="$out/candidate_case_${cid}.txt"
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$candsrc" -o "$candobj"
    gfortran "$opt" "${objects[@]}" "$candobj" -o "$candexe"
    timeout 180s "$candexe" "$h0" "$jump" "$eobs" "$e1512" > "$candout" 2>&1 || { cat "$candout" >&2; fail "candidate indicator failed case=$cid opt=$tag"; }
    grep -Fq 'FSI24_GATE_C_NONLINEAR_CASE PASS' "$candout" || { cat "$candout" >&2; fail "candidate PASS marker missing case=$cid opt=$tag"; }
    cat "$c2out" "$candout" > "$out/combined_case_${cid}.txt"
    echo "FVQ30_CASE_RUN=PASS:OPT=$tag:CASE=$cid:H0=$h0:JUMP=$jump:HORIZON=$horizon"
  done < "$BUILD/cases.tsv"
}

run_matrix -O0 o0
run_matrix -O2 o2
for i in $(seq 1 16); do
  cmp "$BUILD/o0/combined_case_${i}.txt" "$BUILD/o2/combined_case_${i}.txt" || {
    diff -u "$BUILD/o0/combined_case_${i}.txt" "$BUILD/o2/combined_case_${i}.txt" >&2 || true
    fail "O0/O2 output drift case=$i"
  }
done
echo 'FVQ30_G06_O0_O2_IDENTITY=PASS'

python3 - "$PLAN" "$BUILD" <<'PY'
from pathlib import Path
import json,math,re,sys
plan=json.load(open(sys.argv[1])); b=Path(sys.argv[2]); cases=plan['held_out_matrix']['cases']
c2pat=re.compile(r'^FSI23_C2_ROW:H0=\s*([^:]+):JUMP=\s*([^:]+):EOBS=\s*([^:]+):E1_512=\s*([^:]+):D128_256=\s*([^:]+):D256_512=\s*([^:]+):FLOOR=\s*([^:]+):RATIO_AVAILABLE=(YES|NO\s*):EOBS_GE_E1_512=(YES|NO\s*):R512=\s*([^:]+):MAX_MASS=\s*(\S+)$')
gcpat=re.compile(r'^FSI24_GC_ROW:H0=\s*([^:]+):JUMP=\s*([^:]+):EOBS=\s*([^:]+):E1_512=\s*([^:]+):RAW_M=\s*([^:]+):D2_M=\s*([^:]+):BM=\s*([^:]+):BINF=\s*([^:]+):DINF=\s*([^:]+):MIN_M=\s*([^:]+):BINF_GE_E1_512=(YES|NO\s*):RAW_RATIO=\s*([^:]+):BINF_RATIO=\s*([^:]+):DINF_RATIO=\s*(\S+)$')
diagpat=re.compile(r'^FSI24_GC_DIAG:MAX_M=\s*([^:]+):RAW_TO_BINF=\s*([^:]+):MASS=\s*([^:]+):EOBS_REPRO_DIFF=\s*([^:]+):WATER_PROVIDER_DIFF=\s*([^:]+):EXPLICIT_BOTTOM_DISTANCE=\s*(\S+)$')
rows=[]
for c in cases:
    cid=c['case']; lines=(b/'o0'/f'combined_case_{cid}.txt').read_text().splitlines()
    c2=[c2pat.match(x) for x in lines if x.startswith('FSI23_C2_ROW:')]
    gc=[gcpat.match(x) for x in lines if x.startswith('FSI24_GC_ROW:')]
    dg=[diagpat.match(x) for x in lines if x.startswith('FSI24_GC_DIAG:')]
    if len(c2)!=1 or c2[0] is None or len(gc)!=1 or gc[0] is None or len(dg)!=1 or dg[0] is None:
        raise SystemExit(f'case {cid}: malformed combined evidence')
    a,g,d=c2[0],gc[0],dg[0]
    eobs=float(a.group(3)); e1512=float(a.group(4)); d128=float(a.group(5)); d256=float(a.group(6)); floor=float(a.group(7)); refmass=float(a.group(11))
    binf=float(g.group(8)); rawratio=float(g.group(12)); binfratio=float(g.group(13)); candmass=float(d.group(3)); raw_to_binf=float(d.group(2))
    ge=g.group(11).strip()=='YES'
    vals=[eobs,e1512,d128,d256,floor,refmass,binf,rawratio,binfratio,candmass,raw_to_binf]
    if not all(math.isfinite(x) for x in vals): raise SystemExit(f'case {cid}: nonfinite evidence')
    if min(eobs,e1512,d128,d256,floor,refmass,binf,candmass)<0.0: raise SystemExit(f'case {cid}: negative metric')
    if e1512<=0.0: raise SystemExit(f'case {cid}: finite comparator unavailable')
    if refmass>1e-12 or candmass>1e-12: raise SystemExit(f'case {cid}: hard mass gate exceeded')
    rows.append(dict(case=cid,h0=c['h0_cm'],jump=c['jump_cm'],dt=c['horizon_day'],e1512=e1512,d128=d128,d256=d256,floor=floor,binf=binf,ge=ge,rawratio=rawratio,binfratio=binfratio,raw_to_binf=raw_to_binf,refmass=refmass,candmass=candmass))
    print('FVQ30_G03_ROW:CASE='+str(cid)+':H0='+f"{c['h0_cm']:.17e}"+':JUMP='+f"{c['jump_cm']:.17e}"+':HORIZON='+f"{c['horizon_day']:.17e}"+':E1_512='+f'{e1512:.17e}'+':BINF='+f'{binf:.17e}'+':BINF_RATIO='+f'{binfratio:.17e}'+':RAW_RATIO='+f'{rawratio:.17e}'+':RAW_TO_BINF='+f'{raw_to_binf:.17e}'+':D128_256='+f'{d128:.17e}'+':D256_512='+f'{d256:.17e}'+':FLOOR='+f'{floor:.17e}'+':BINF_GE_E1_512='+('YES' if ge else 'NO')+':MAX_REF_MASS='+f'{refmass:.17e}'+':CAND_MASS='+f'{candmass:.17e}')
neg=sum(not r['ge'] for r in rows)
print('FVQ30_G03_CASES='+str(len(rows)))
print('FVQ30_G03_FINITE_COMPARATOR_CASES='+str(sum(r['e1512']>0 for r in rows)))
print('FVQ30_G03_NEGATIVE_TRANSFER='+str(neg))
print('FVQ30_G03_BINF_RATIO_MIN='+f"{min(r['binfratio'] for r in rows):.17e}")
print('FVQ30_G03_BINF_RATIO_MAX='+f"{max(r['binfratio'] for r in rows):.17e}")
print('FVQ30_G03_RAW_TO_BINF_MIN='+f"{min(r['raw_to_binf'] for r in rows):.17e}")
print('FVQ30_G03_RAW_TO_BINF_MAX='+f"{max(r['raw_to_binf'] for r in rows):.17e}")
print('FVQ30_G05_MAX_REFERENCE_MASS='+f"{max(r['refmass'] for r in rows):.17e}")
print('FVQ30_G05_MAX_CANDIDATE_MASS='+f"{max(r['candmass'] for r in rows):.17e}")
for h in sorted(set(r['h0'] for r in rows)):
    s=[r for r in rows if r['h0']==h]
    print('FVQ30_STATE:H0='+f'{h:.17e}'+':BINF_RATIO_MIN='+f"{min(r['binfratio'] for r in s):.17e}"+':BINF_RATIO_MAX='+f"{max(r['binfratio'] for r in s):.17e}")
for dt in sorted(set(r['dt'] for r in rows)):
    s=[r for r in rows if r['dt']==dt]
    print('FVQ30_HORIZON:DT='+f'{dt:.17e}'+':BINF_RATIO_MIN='+f"{min(r['binfratio'] for r in s):.17e}"+':BINF_RATIO_MAX='+f"{max(r['binfratio'] for r in s):.17e}")
print('FVQ30_N512_EXACT_TRUTH=NO')
print('FVQ30_TRUE_NONLINEAR_ERROR_BOUND_QUALIFIED=NO')
print('FVQ30_SCIENTIFIC_TEMPORAL_TOLERANCE_SELECTED=NO')
print('FVQ30_EMPIRICAL_RESCUE_APPLIED=NO')
if neg:
    raise SystemExit('FVQ30_G03_FAIL negative held-out transfer')
print('FVQ30_G03_HELD_OUT_NONLINEAR_TRANSFER=PASS')
print('FVQ30_G05_HARD_MASS=PASS')
PY

git diff --quiet "$BASE" -- \
  src/solver \
  src/legacy/b1_10_port/headcalc.f90 \
  src/adapter/mod_reference_richards_legacy_binding.f90 \
  src/runtime/mod_a23bu_worker_execution_context.f90 \
  tests/fmr/mod_fmr04_fixed_top_provider.f90 \
  || fail 'production source changed during VQ30'
echo 'FVQ30_PRODUCTION_SOURCE_UNCHANGED=PASS'
echo 'FVQ30_ALL_FROZEN_GATES PASS'
