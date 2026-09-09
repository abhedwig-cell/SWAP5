#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fci21-vq30-replay-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

SOURCE_COMMIT=a0331164a8dfc2642becdbe96cab969eabead392
POSTIMAGE=integration/f-ci/F-CI21_MATERIALIZED_SOURCE_POSTIMAGE.json
POSTIMAGE_BLOB=868cf8c52c02a6a9b40bd09ad9f51b7c0b635de4
VQ30_BRANCH=qualification/f-vq30-bounded-stiffness-aware-temporal-indicator
VQ30_PLAN=integration/f-vq/F-VQ30_QUALIFICATION_PLAN.json
VQ30_PLAN_BLOB=8bf40e19ba547ec93c4d8ce18d7ac6111707afe7
VQ30_EVIDENCE=integration/f-vq/F-VQ30_HELD_OUT_EVIDENCE.json
VQ30_EVIDENCE_BLOB=39832173174271f4ad97278662467eb4dab13599
VQ30_CLOSEOUT=integration/f-vq/F-VQ30_CLOSEOUT.json
VQ30_CLOSEOUT_BLOB=6663bcc1149f07962bb9921840958d6d7de628a4
DRIVER=tests/fsi/test_fsi25_reference_indicator_production_seam.f90
DRIVER_BLOB=c125c6a2ab706920b7e2a5c6f1c855520b192223
GENERATOR=tests/fsi/fsi18_make_reference_tridag_stubs.py
GENERATOR_BLOB=bf25c4c7fefaa59811255b0bc25c041522ab008e
STUB=tests/fsi/fsi04_real_headcalc_stubs.f90
STUB_BLOB=23c00e4a188e88bc36ef95cbe4faaacdd6aad639
FIXED_TOP=tests/fmr/mod_fmr04_fixed_top_provider.f90
FIXED_TOP_BLOB=942c56e3ba2b1739506e1d5b0ac889e6fd163ea7
INDICATOR=src/solver/mod_reference_richards_temporal_indicator.f90

fail() { echo "FCI21_VQ30_REPLAY_FAIL $*" >&2; exit 1; }

# Exact materialized production postimage locks.
git merge-base --is-ancestor "$SOURCE_COMMIT" HEAD || fail 'materialized source commit not in tested history'
[[ "$(git rev-parse HEAD:$POSTIMAGE)" == "$POSTIMAGE_BLOB" ]] || fail 'F-CI21 postimage manifest drift'
[[ "$(git rev-parse HEAD:src/solver/mod_soil_water_solver_contract.f90)" == dc7b14a06f64c8ab0af9747f707b3394a5f5cbe0 ]] || fail 'solver contract drift'
[[ "$(git rev-parse HEAD:src/solver/mod_fixed_flux_top_boundary_provider.f90)" == fb226f133bd48d8ab945f111c76897aeff49facf ]] || fail 'fixed-flux provider drift'
[[ "$(git rev-parse HEAD:src/solver/mod_reference_richards_temporal_indicator.f90)" == fe8f87d11257d4c6bc019f1d628ac41ba3106d4e ]] || fail 'temporal indicator drift'
[[ "$(git rev-parse HEAD:src/adapter/mod_reference_richards_legacy_binding.f90)" == 6eda1fec1bd03c03a1c0a8f2df29a273f70d962f ]] || fail 'reference adapter drift'
[[ "$(git rev-parse HEAD:$DRIVER)" == "$DRIVER_BLOB" ]] || fail 'F-SI25 production driver drift'
[[ "$(git rev-parse HEAD:$GENERATOR)" == "$GENERATOR_BLOB" ]] || fail 'TRIDAG generator drift'
[[ "$(git rev-parse HEAD:$STUB)" == "$STUB_BLOB" ]] || fail 'HeadCalc stub drift'
[[ "$(git rev-parse HEAD:$FIXED_TOP)" == "$FIXED_TOP_BLOB" ]] || fail 'fixed-top fixture drift'
git diff --quiet "$SOURCE_COMMIT" HEAD -- \
  src/solver \
  src/legacy/b1_10_port/headcalc.f90 \
  src/adapter/mod_reference_richards_legacy_binding.f90 \
  src/runtime/mod_a23bu_worker_execution_context.f90 || fail 'materialized operator source changed after source postimage'
echo 'FCI21_VQ30_POSTIMAGE_LOCK=PASS'

# Pull only the frozen qualification authority. It remains test/evidence input, never production code.
git fetch --quiet --no-tags origin "$VQ30_BRANCH:refs/remotes/origin/fci21-vq30-authority"
VQREF=refs/remotes/origin/fci21-vq30-authority
[[ "$(git rev-parse "$VQREF:$VQ30_PLAN")" == "$VQ30_PLAN_BLOB" ]] || fail 'F-VQ30 plan drift'
[[ "$(git rev-parse "$VQREF:$VQ30_EVIDENCE")" == "$VQ30_EVIDENCE_BLOB" ]] || fail 'F-VQ30 evidence drift'
[[ "$(git rev-parse "$VQREF:$VQ30_CLOSEOUT")" == "$VQ30_CLOSEOUT_BLOB" ]] || fail 'F-VQ30 closeout drift'
git show "$VQREF:$VQ30_PLAN" > "$BUILD/vq30_plan.json"
git show "$VQREF:$VQ30_EVIDENCE" > "$BUILD/vq30_evidence.json"
git show "$VQREF:$VQ30_CLOSEOUT" > "$BUILD/vq30_closeout.json"

python3 - "$BUILD/vq30_plan.json" "$BUILD/vq30_evidence.json" "$BUILD/vq30_closeout.json" "$BUILD/cases.tsv" <<'PY'
import json,sys
plan_path,evidence_path,closeout_path,out=sys.argv[1:]
p=json.load(open(plan_path)); e=json.load(open(evidence_path)); c=json.load(open(closeout_path))
expected_decision='QUALIFIED_HELD_OUT_TRANSFER_OF_BOUNDED_STIFFNESS_AWARE_RICHARDS_INDICATOR_READY_FOR_PRODUCTION_OPERATOR_SEAM'
if c.get('decision') != expected_decision:
    raise SystemExit('unexpected F-VQ30 closeout decision')
if p['owner_source_lock']['candidate_id'] != 'F_SI24_LINEAR_MNORM_MIN_RAW_OR_DOUBLE_DEFECT_BOUND':
    raise SystemExit('candidate identity drift')
sem=p['candidate_semantics']
if sem['analytic_factor'] != 2.0 or sem['factor_fitted'] or sem['global_scale_fitted'] or sem['state_normalization_fitted']:
    raise SystemExit('candidate coefficient/rescue drift')
cases=p['held_out_matrix']['cases']; rows=e['case_rows']
if len(cases)!=16 or len(rows)!=16:
    raise SystemExit('held-out case count drift')
if e['held_out_matrix']['exact_triplet_overlap_with_F_SI24_owner_matrix'] != 0:
    raise SystemExit('owner overlap is no longer zero')
if e['held_out_matrix']['negative_transfer_cases'] != 0:
    raise SystemExit('frozen VQ30 evidence contains negative transfer')
by_case={int(r['case']):r for r in rows}
with open(out,'w') as f:
    for case in cases:
        cid=int(case['case']); r=by_case[cid]
        trip=(float(case['h0_cm']),float(case['jump_cm']),float(case['horizon_day']))
        rtrip=(float(r['h0_cm']),float(r['jump_cm']),float(r['horizon_day']))
        if trip != rtrip:
            raise SystemExit(f'case {cid}: plan/evidence triplet mismatch')
        if not (float(r['B_inf']) >= float(r['E1_512']) > 0.0):
            raise SystemExit(f'case {cid}: frozen transfer inconsistency')
        if abs(float(r['candidate_mass'])) > 1.0e-12:
            raise SystemExit(f'case {cid}: frozen mass gate inconsistency')
        f.write(f"{cid}\t{trip[0]:.17e}\t{trip[1]:.17e}\t{trip[2]:.17e}\t{float(r['E1_512']):.17e}\t{float(r['B_inf']):.17e}\n")
print('FCI21_VQ30_AUTHORITY_LOCK=PASS:CASES=16:OVERLAP=0')
PY

# Production operator ownership and bounded-cost shape must still be explicit.
if grep -Eiq 'dfdh|old_head|delta_head' "$INDICATOR"; then
  fail 'indicator reads prohibited HeadCalc/Newton internals'
fi
[[ "$(grep -Eic 'call[[:space:]]+reference_tridag' "$INDICATOR")" -eq 1 ]] || fail 'indicator must contain exactly one defect TRIDAG call'
if grep -Eiq 'call[[:space:]].*%solve|N128|N256|N512|nsteps|run_trajectory' "$INDICATOR"; then
  fail 'deep/full nonlinear refinement leaked into production indicator'
fi
echo 'FCI21_VQ30_OPERATOR_OWNERSHIP_AND_STATIC_COST=PASS'

python3 "$GENERATOR" "$STUB" "$BUILD/reference_tridag_stubs.f90"
grep -Fq 'SWAP 4.3.1 tridag.f90' "$BUILD/reference_tridag_stubs.f90" || fail 'reference TRIDAG marker missing'
if grep -Fq 'solution(i) = 0.0d0' "$BUILD/reference_tridag_stubs.f90"; then
  fail 'zero-correction fixture TRIDAG survived reference replacement'
fi

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
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  "$FIXED_TOP"
)

build_and_run() {
  local opt="$1" tag="$2"
  local out="$BUILD/$tag"
  mkdir -p "$out"
  local objects=()
  for src in "${MODULE_SRC[@]}"; do
    local obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done

  while IFS=$'\t' read -r cid h0 jump horizon e1512 expected_binf; do
    local case_src="$out/production_${cid}.f90"
    python3 - "$DRIVER" "$case_src" "$horizon" <<'PY'
import re,sys
src,out,dt=sys.argv[1:]
s=open(src).read()
pat=r'real\(real64\), parameter :: total_dt = 0\.25_real64, hard_mass_gate = 1\.0e-12_real64'
rep=f'real(real64), parameter :: total_dt = {float(dt):.17e}_real64, hard_mass_gate = 1.0e-12_real64'
s2,n=re.subn(pat,rep,s,count=1)
if n != 1:
    raise SystemExit('failed to patch exact production-driver total_dt declaration')
open(out,'w').write(s2)
PY
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$case_src" -o "$out/production_${cid}.o"
    gfortran "$opt" "${objects[@]}" "$out/production_${cid}.o" -o "$out/production_${cid}"
    timeout 120s "$out/production_${cid}" "$h0" "$jump" > "$out/production_${cid}.txt" 2>&1 || {
      cat "$out/production_${cid}.txt" >&2
      fail "production seam failed opt=$tag case=$cid"
    }
    grep -Fq 'FSI25_REFERENCE_INDICATOR_CASE PASS' "$out/production_${cid}.txt" || fail "production PASS marker missing opt=$tag case=$cid"
    echo "FCI21_VQ30_CASE_EXECUTED=PASS:OPT=$tag:CASE=$cid:DT=$horizon"
  done < "$BUILD/cases.tsv"
}

build_and_run -O0 o0
build_and_run -O2 o2

while IFS=$'\t' read -r cid h0 jump horizon e1512 expected_binf; do
  cmp "$BUILD/o0/production_${cid}.txt" "$BUILD/o2/production_${cid}.txt" || {
    diff -u "$BUILD/o0/production_${cid}.txt" "$BUILD/o2/production_${cid}.txt" >&2 || true
    fail "production O0/O2 drift case=$cid"
  }
done < "$BUILD/cases.tsv"
echo 'FCI21_VQ30_O0_O2_IDENTITY=PASS'

python3 - "$BUILD" <<'PY'
from pathlib import Path
import math,re,sys
b=Path(sys.argv[1])
rows=[]
for line in (b/'cases.tsv').read_text().splitlines():
    cid,h0,jump,dt,e1512,expected=line.split('\t')
    rows.append((int(cid),float(h0),float(jump),float(dt),float(e1512),float(expected)))
prod=re.compile(r'^FSI25_PROD_ROW:H0=\s*([^:]+):JUMP=\s*([^:]+):RAW_M=\s*([^:]+):D2_M=\s*([^:]+):BM=\s*([^:]+):BINF=\s*([^:]+):MIN_M=\s*([^:]+):ROUTE=(\S+)$')
diag=re.compile(r'^FSI25_PROD_DIAG:MASS=\s*([^:]+):EXTRA_NONLINEAR=(\d+):EXTRA_TRIDAG=(\d+):PRINCIPAL_LINEAR=(\d+)$')
maxdiff=0.0
ratios=[]
maxmass=0.0
for cid,h0,jump,dt,e1512,expected in rows:
    text=(b/'o0'/f'production_{cid}.txt').read_text().splitlines()
    pm=[prod.match(x) for x in text if x.startswith('FSI25_PROD_ROW:')]
    dm=[diag.match(x) for x in text if x.startswith('FSI25_PROD_DIAG:')]
    if len(pm)!=1 or pm[0] is None or len(dm)!=1 or dm[0] is None:
        raise SystemExit(f'case {cid}: production row parse failure')
    p=pm[0]; d=dm[0]
    actual_h0=float(p.group(1)); actual_jump=float(p.group(2)); binf=float(p.group(6)); route=p.group(8)
    mass=abs(float(d.group(1))); extra_nl=int(d.group(2)); extra_tri=int(d.group(3))
    if actual_h0 != h0 or actual_jump != jump:
        raise SystemExit(f'case {cid}: executed state mismatch')
    if route != 'reference-richards-defect-bound':
        raise SystemExit(f'case {cid}: route drift {route}')
    if not (math.isfinite(binf) and binf >= 0.0):
        raise SystemExit(f'case {cid}: invalid B_inf')
    diff=abs(binf-expected)
    tol=65536.0*sys.float_info.epsilon*max(1.0,abs(binf),abs(expected))
    if diff > tol:
        raise SystemExit(f'case {cid}: frozen VQ30 B_inf replay drift actual={binf:.17e} expected={expected:.17e} diff={diff:.17e} tol={tol:.17e}')
    if binf < e1512:
        raise SystemExit(f'case {cid}: negative held-out transfer B_inf={binf:.17e} E1_512={e1512:.17e}')
    if mass > 1.0e-12:
        raise SystemExit(f'case {cid}: hard mass failure {mass:.17e}')
    if extra_nl != 0 or extra_tri != 1:
        raise SystemExit(f'case {cid}: bounded-cost drift extra_nonlinear={extra_nl} extra_tridag={extra_tri}')
    maxdiff=max(maxdiff,diff); maxmass=max(maxmass,mass); ratios.append(binf/e1512)
    print(f'FCI21_VQ30_REPLAY_ROW:CASE={cid}:DT={dt:.17e}:BINF={binf:.17e}:EXPECTED={expected:.17e}:E1_512={e1512:.17e}:RATIO={binf/e1512:.17e}:MASS={mass:.17e}:DIFF={diff:.17e}')
print('FCI21_VQ30_REPLAY_CASES=16')
print('FCI21_VQ30_NEGATIVE_TRANSFER_CASES=0')
print(f'FCI21_VQ30_BINF_REPLAY_MAX_ABS_DIFF={maxdiff:.17e}')
print(f'FCI21_VQ30_BINF_OVER_E1_512_MIN={min(ratios):.17e}')
print(f'FCI21_VQ30_BINF_OVER_E1_512_MAX={max(ratios):.17e}')
print(f'FCI21_VQ30_MAX_MASS_RESIDUAL={maxmass:.17e}')
print('FCI21_VQ30_COST=PASS:EXTRA_NONLINEAR=0:EXTRA_TRIDAG=1')
print('FCI21_VQ30_HELD_OUT_OPERATOR_REPLAY=PASS')
PY

echo 'FCI21_VQ30_REPLAY_NONCLAIM=BINF_NOT_GENERAL_NONLINEAR_TRUE_ERROR_BOUND'
echo 'FCI21_VQ30_REPLAY_NONCLAIM=N512_NOT_EXACT_TRUTH'
echo 'FCI21_VQ30_REPLAY_NONCLAIM=NO_SCIENTIFIC_TOLERANCE_OR_ACCEPTANCE_POLICY_ADMITTED'
echo 'FCI21_VQ30_HELD_OUT_REPLAY PASS'
