#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq32-normalization-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

PLAN=integration/f-vq/F-VQ32_QUALIFICATION_PLAN.json
PLAN_BLOB=e47b71d25133902967294583801df720cac9cd63
DIRECT_DRIVER=tests/fsi/test_fsi25_reference_indicator_production_seam.f90
DIRECT_DRIVER_BLOB=c125c6a2ab706920b7e2a5c6f1c855520b192223
TX_DRIVER=tests/fkt/test_fkt10_transactional_fvq30_replay.f90
TX_DRIVER_BLOB=c42765b89b5dd9140aa492ab56abbbf2077be50e
INDICATOR=src/solver/mod_reference_richards_temporal_indicator.f90
INDICATOR_BLOB=fe8f87d11257d4c6bc019f1d628ac41ba3106d4e
STUB=tests/fsi/fsi04_real_headcalc_stubs.f90
FSI18_BRANCH=origin/work/f-si18-reference-convergence-cliff
FSI18_GENERATOR=tests/fsi/fsi18_make_reference_tridag_stubs.py
FSI18_GENERATOR_BLOB=bf25c4c7fefaa59811255b0bc25c041522ab008e

fail() { echo "FVQ32_NONLINEAR_FAIL $*" >&2; exit 1; }

[[ "$(git rev-parse HEAD:$PLAN)" == "$PLAN_BLOB" ]] || fail 'frozen F-VQ32 plan drift'
[[ "$(git rev-parse HEAD:$DIRECT_DRIVER)" == "$DIRECT_DRIVER_BLOB" ]] || fail 'F-SI25 direct driver drift'
[[ "$(git rev-parse HEAD:$TX_DRIVER)" == "$TX_DRIVER_BLOB" ]] || fail 'F-KT10 transaction driver drift'
[[ "$(git rev-parse HEAD:$INDICATOR)" == "$INDICATOR_BLOB" ]] || fail 'production indicator drift'

echo 'FVQ32_G01_SOURCE_AND_CANDIDATE_LOCK=PASS'

python3 - "$PLAN" "$BUILD/cases.tsv" "$BUILD/budgets.tsv" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
m=p['fresh_nonlinear_production_matrix']
b=p['synthetic_budget_probe_set_cm']
assert p['frozen_before_execution'] is True
assert p['candidate_lock']['formula']=='C_h=B_inf/H_budget'
assert p['candidate_lock']['default_H_budget'] is None
assert m['case_count']==12 and len(m['cases'])==12
assert b==[0.01,0.1,1.0]
assert m['exact_triplet_overlap_with_F_SI24_owner_matrix']==0
assert m['exact_triplet_overlap_with_F_VQ30_matrix']==0
assert m['exact_triplet_overlap_with_F_VQ31_matrix']==0
assert m['exact_triplet_overlap_with_F_KT10_real_fixture']==0
fsi24={(h,j,0.25) for h in (-25.0,-75.0,-250.0) for j in (-0.1,-0.01,0.001,0.01,0.1)}
fvq30={(h,j,dt) for h in (-35.0,-95.0,-185.0,-300.0) for j in (-0.075,0.075) for dt in (0.125,0.5)}
fvq31={(h,j,dt) for h in (-55.0,-140.0,-240.0) for j in (-0.04,0.04) for dt in (0.2,0.375)}
fkt10={(-75.0,0.01,0.25)}
seen=set()
with open(sys.argv[2],'w') as f:
    for c in m['cases']:
        t=(float(c['h0_cm']),float(c['jump_cm']),float(c['horizon_day']))
        assert t not in fsi24 and t not in fvq30 and t not in fvq31 and t not in fkt10 and t not in seen
        seen.add(t)
        f.write(f"{c['case']}\t{t[0]:.17e}\t{t[1]:.17e}\t{t[2]:.17e}\n")
with open(sys.argv[3],'w') as f:
    for H in b: f.write(f'{float(H):.17e}\n')
print('FVQ32_G05_FRESH_CASES=12')
print('FVQ32_G05_EXACT_TRIPLET_OVERLAP_PRIOR=0')
print('FVQ32_G03_SYNTHETIC_BUDGET_PROBES=3')
PY

python3 - <<'PY'
from pathlib import Path
indicator=Path('src/solver/mod_reference_richards_temporal_indicator.f90').read_text().lower()
backend=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text().lower()
assert 'indicator_result%current_right_derivative = &' in indicator
assert 'indicator_request%previous_right_derivative = previous_derivative' in backend
assert 'call self%solver%evaluate_temporal_indicator(request, solve_result, indicator_request' in backend
assert 'outcome%temporal_certificate_available = .true.' not in backend
assert 'h_budget' not in indicator
print('FVQ32_G05_PRODUCTION_INDICATOR_UNCHANGED=PASS')
print('FVQ32_G10_NO_FKT09_CERTIFICATE_ACTIVATION=PASS')
PY

git fetch --quiet --no-tags origin work/f-si18-reference-convergence-cliff:refs/remotes/origin/work/f-si18-reference-convergence-cliff
[[ "$(git rev-parse "$FSI18_BRANCH:$FSI18_GENERATOR")" == "$FSI18_GENERATOR_BLOB" ]] || fail 'F-SI18 TRIDAG generator drift'
git show "$FSI18_BRANCH:$FSI18_GENERATOR" > "$BUILD/make_reference_tridag.py"
python3 "$BUILD/make_reference_tridag.py" "$STUB" "$BUILD/reference_tridag_stubs.f90"
grep -Fq 'SWAP 4.3.1 tridag.f90' "$BUILD/reference_tridag_stubs.f90" || fail 'reference TRIDAG marker missing'
if grep -Fq 'solution(i) = 0.0d0' "$BUILD/reference_tridag_stubs.f90"; then fail 'zero-correction TRIDAG survived reference replacement'; fi

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  "$BUILD/reference_tridag_stubs.f90"
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
)

build_and_run() {
  local opt="$1" tag="$2" out="$BUILD/$2"
  mkdir -p "$out"
  local objects=() src obj cid h0 jump dt direct_src direct_obj direct_exe direct_out tx_out direct_binf
  for src in "${MODULE_SRC[@]}"; do
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$TX_DRIVER" -o "$out/tx.o"
  gfortran "$opt" "${objects[@]}" "$out/tx.o" -o "$out/tx"

  while IFS=$'\t' read -r cid h0 jump dt; do
    direct_src="$out/direct_${cid}.f90"
    cp "$DIRECT_DRIVER" "$direct_src"
    python3 - "$direct_src" "$dt" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); dt=float(sys.argv[2]); s=p.read_text()
old='real(real64), parameter :: total_dt = 0.25_real64, hard_mass_gate = 1.0e-12_real64'
new=f'real(real64), parameter :: total_dt = {dt:.17e}_real64, hard_mass_gate = 1.0e-12_real64'
if s.count(old)!=1: raise SystemExit('FVQ32 direct-driver dt token drift')
p.write_text(s.replace(old,new,1))
PY
    direct_obj="$out/direct_${cid}.o"; direct_exe="$out/direct_${cid}"; direct_out="$out/direct_${cid}.txt"
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$direct_src" -o "$direct_obj"
    gfortran "$opt" "${objects[@]}" "$direct_obj" -o "$direct_exe"
    timeout 180s "$direct_exe" "$h0" "$jump" > "$direct_out" 2>&1 || { cat "$direct_out" >&2; fail "direct route failed opt=$tag case=$cid"; }
    grep -Fq 'FSI25_REFERENCE_INDICATOR_CASE PASS' "$direct_out" || fail "direct PASS missing opt=$tag case=$cid"
    direct_binf="$(python3 - "$direct_out" <<'PY'
import re,sys
lines=open(sys.argv[1]).read().splitlines(); row=[x for x in lines if x.startswith('FSI25_PROD_ROW:')]
if len(row)!=1: raise SystemExit('direct row parse')
m=re.search(r':BINF=\s*([^:]+):MIN_M=',row[0])
if not m: raise SystemExit('direct BINF parse')
print(f'{float(m.group(1)):.17e}')
PY
)"
    tx_out="$out/tx_${cid}.txt"
    timeout 180s "$out/tx" "$h0" "$jump" "$dt" "$direct_binf" > "$tx_out" 2>&1 || { cat "$tx_out" >&2; fail "transaction route failed opt=$tag case=$cid"; }
    grep -Fq 'FKT10_GATE_G_TRANSACTIONAL_FROZEN_CASE PASS' "$tx_out" || fail "transaction PASS missing opt=$tag case=$cid"
  done < "$BUILD/cases.tsv"
}

build_and_run -O0 o0
build_and_run -O2 o2

python3 - "$BUILD" "$PLAN" <<'PY'
from pathlib import Path
import json,math,re,sys
b=Path(sys.argv[1]); p=json.load(open(sys.argv[2])); budgets=[float(x) for x in p['synthetic_budget_probe_set_cm']]
drow=re.compile(r'^FSI25_PROD_ROW:H0=\s*([^:]+):JUMP=\s*([^:]+):RAW_M=\s*([^:]+):D2_M=\s*([^:]+):BM=\s*([^:]+):BINF=\s*([^:]+):MIN_M=\s*([^:]+):ROUTE=(\S+)$')
ddiag=re.compile(r'^FSI25_PROD_DIAG:MASS=\s*([^:]+):EXTRA_NONLINEAR=(\d+):EXTRA_TRIDAG=(\d+):PRINCIPAL_LINEAR=(\d+)$')
trow=re.compile(r'^FKT10_G_ROW:H0=\s*([^:]+):JUMP=\s*([^:]+):DT=\s*([^:]+):BINF=\s*([^:]+):EXPECTED=\s*([^:]+):EXTRA_TRIDAG=(\d+):EXTRA_NONLINEAR=(\d+)$')
tdiag=re.compile(r'^FKT10_G_DIAG:BINF_ABS_DIFF=\s*([^:]+):MAX_STEP_MASS=\s*([^:]+):HEADCALC_CALLS=(\d+)$')
summary={}
for tag in ('o0','o2'):
    rows=[]
    for cid in range(1,13):
        dl=(b/tag/f'direct_{cid}.txt').read_text().splitlines(); tl=(b/tag/f'tx_{cid}.txt').read_text().splitlines()
        dr=[drow.match(x) for x in dl if x.startswith('FSI25_PROD_ROW:')]; dd=[ddiag.match(x) for x in dl if x.startswith('FSI25_PROD_DIAG:')]
        tr=[trow.match(x) for x in tl if x.startswith('FKT10_G_ROW:')]; td=[tdiag.match(x) for x in tl if x.startswith('FKT10_G_DIAG:')]
        if len(dr)!=1 or dr[0] is None or len(dd)!=1 or dd[0] is None or len(tr)!=1 or tr[0] is None or len(td)!=1 or td[0] is None:
            raise SystemExit(f'{tag} case {cid}: parse failure')
        direct=float(dr[0].group(6)); tx=float(tr[0].group(4)); diff=abs(direct-tx)
        scale=max(1.0,abs(direct),abs(tx))
        if not math.isfinite(direct) or direct<0.0 or not math.isfinite(tx) or tx<0.0 or diff>65536.0*sys.float_info.epsilon*scale:
            raise SystemExit(f'{tag} case {cid}: direct/transaction B_inf mismatch {direct} {tx}')
        dmass=float(dd[0].group(1)); tmass=float(td[0].group(2))
        if dmass>1e-12 or tmass>1e-12: raise SystemExit(f'{tag} case {cid}: mass fail direct={dmass} tx={tmass}')
        if int(dd[0].group(2))!=0 or int(dd[0].group(3))!=1: raise SystemExit(f'{tag} case {cid}: direct cost shape')
        if int(tr[0].group(6))!=1 or int(tr[0].group(7))!=0 or int(td[0].group(3))!=1: raise SystemExit(f'{tag} case {cid}: transaction cost shape')
        certs=[]
        for H in budgets:
            C=tx/H
            if not math.isfinite(C) or C<0.0: raise SystemExit(f'{tag} case {cid}: invalid normalized C')
            if (C<=1.0)!=(tx<=H): raise SystemExit(f'{tag} case {cid}: threshold equivalence H={H}')
            certs.append(C)
        if abs(certs[0]/10.0-certs[1])>64.0*sys.float_info.epsilon*max(1.0,abs(certs[1])): raise SystemExit(f'{tag} case {cid}: scaling 0.01->0.1')
        if abs(certs[1]/10.0-certs[2])>64.0*sys.float_info.epsilon*max(1.0,abs(certs[2])): raise SystemExit(f'{tag} case {cid}: scaling 0.1->1')
        rows.append((cid,direct,tx,diff,dmass,tmass,certs[0],certs[1],certs[2],dr[0].group(8)))
    summary[tag]=rows
if summary['o0']!=summary['o2']: raise SystemExit('O0/O2 normalized summary drift')
maxdiff=max(r[3] for r in summary['o0']); maxmass=max(max(r[4],r[5]) for r in summary['o0'])
for r in summary['o0']:
    print(f'FVQ32_G05_ROW:CASE={r[0]}:BINF={r[2]:.17e}:C_0P01={r[6]:.17e}:C_0P1={r[7]:.17e}:C_1={r[8]:.17e}:MASS={max(r[4],r[5]):.17e}:ROUTE={r[9]}')
print('FVQ32_G05_FRESH_NONLINEAR_CASES=12')
print(f'FVQ32_G05_MAX_DIRECT_TX_BINF_DIFF={maxdiff:.17e}')
print(f'FVQ32_G06_MAX_MASS={maxmass:.17e}')
print('FVQ32_G03_DIMENSIONLESS_BUDGET_ALGEBRA_NONLINEAR=PASS')
print('FVQ32_G05_FRESH_NONLINEAR_PRODUCTION_NORMALIZATION=PASS')
print('FVQ32_G06_NONINTERFERENCE_AND_COST=PASS')
print('FVQ32_G07_O0_O2=PASS')
print('FVQ32_G08_NONLINEAR_CLAIM_BOUNDARY=PASS_NO_REFERENCE_RUN')
PY

[[ -z "$(git diff --name-only e6c103ebb69bb9fa6eb631f8c1d41fb2708372b2..HEAD -- src)" ]] || fail 'production src changed in F-VQ32'
echo 'FVQ32_G11_PRODUCTION_SOURCE_UNCHANGED=PASS'
echo 'FVQ32_FRESH_HEAD_BUDGET_NORMALIZATION PASS'
