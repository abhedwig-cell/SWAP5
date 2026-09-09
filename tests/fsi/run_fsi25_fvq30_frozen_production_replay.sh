#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi25-fvq30-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

PLAN=integration/f-vq/F-VQ30_QUALIFICATION_PLAN.json
PLAN_BLOB=8bf40e19ba547ec93c4d8ce18d7ac6111707afe7
EVIDENCE=integration/f-vq/F-VQ30_HELD_OUT_EVIDENCE.json
EVIDENCE_BLOB=39832173174271f4ad97278662467eb4dab13599
LINEAR=tests/fvq/test_fvq30_exact_linear_regression.py
LINEAR_BLOB=18efc3b8fb8d4610e9a2bd4dbb30a9edf23b3528
DRIVER=tests/fsi/test_fsi25_reference_indicator_production_seam.f90
DRIVER_BLOB=c125c6a2ab706920b7e2a5c6f1c855520b192223
CONTRACT=integration/f-si/F-SI25_WORK_UNIT_CONTRACT.json
INDICATOR=src/solver/mod_reference_richards_temporal_indicator.f90
STUB=tests/fsi/fsi04_real_headcalc_stubs.f90
FSI18_BRANCH=origin/work/f-si18-reference-convergence-cliff
FSI18_GENERATOR=tests/fsi/fsi18_make_reference_tridag_stubs.py
FSI18_GENERATOR_BLOB=bf25c4c7fefaa59811255b0bc25c041522ab008e

fail() { echo "FSI25_FVQ30_REPLAY_FAIL $*" >&2; exit 1; }

[[ "$(git rev-parse HEAD:$PLAN)" == "$PLAN_BLOB" ]] || fail 'F-VQ30 frozen plan drift'
[[ "$(git rev-parse HEAD:$EVIDENCE)" == "$EVIDENCE_BLOB" ]] || fail 'F-VQ30 held-out evidence drift'
[[ "$(git rev-parse HEAD:$LINEAR)" == "$LINEAR_BLOB" ]] || fail 'F-VQ30 exact-linear oracle drift'
[[ "$(git rev-parse HEAD:$DRIVER)" == "$DRIVER_BLOB" ]] || fail 'F-SI25 production driver drift'
python3 - "$CONTRACT" "$PLAN" "$EVIDENCE" "$BUILD/cases.tsv" <<'PY'
import json,sys
contract,plan,evidence,out=sys.argv[1:]
c=json.load(open(contract)); p=json.load(open(plan)); e=json.load(open(evidence))
assert c['gates']['F_owner_replay'].startswith('Replay the exact-linear formula regression and the frozen 16-case F-VQ30 matrix')
assert c['fixed_candidate_semantics']['analytic_factor']==2.0
assert c['fixed_candidate_semantics']['empirical_factor_fitted'] is False
assert c['fixed_candidate_semantics']['scientific_tolerance_selected'] is False
assert p['frozen_before_execution'] is True
assert p['held_out_matrix']['case_count']==16
assert p['held_out_matrix']['exact_triplet_overlap_with_owner_matrix']==0
assert e['qualification_plan']['case_count']==16
assert e['held_out_matrix']['negative_transfer_cases']==0
rows=e['case_rows']
assert len(rows)==16
by_case={r['case']:r for r in rows}
with open(out,'w') as f:
    for cse in p['held_out_matrix']['cases']:
        r=by_case[cse['case']]
        assert r['h0_cm']==cse['h0_cm']
        assert r['jump_cm']==cse['jump_cm']
        assert r['horizon_day']==cse['horizon_day']
        f.write(f"{cse['case']}\t{cse['h0_cm']:.17e}\t{cse['jump_cm']:.17e}\t{cse['horizon_day']:.17e}\t{r['B_inf']:.17e}\n")
print('FSI25_GATE_F_FVQ30_MATRIX_LOCK=PASS')
print('FSI25_GATE_F_FVQ30_CASES=16')
PY

python3 "$LINEAR" | tee "$BUILD/exact_linear.txt"
grep -Fq 'FVQ30_G02_EXACT_LINEAR_REGRESSION PASS' "$BUILD/exact_linear.txt" || fail 'exact-linear formula regression failed'
echo 'FSI25_GATE_F_EXACT_LINEAR_REPLAY=PASS'

# Production cost and ownership must remain local and bounded. Qualification-only
# N128/N256/N512 trajectories are deliberately not executed by this runner.
[[ "$(grep -c 'call reference_tridag' "$INDICATOR")" -eq 1 ]] || fail 'production indicator must contain exactly one defect TRIDAG call site'
if grep -Eq 'N128|N256|N512|run_trajectory|nsteps|call[[:space:]].*%solve' "$INDICATOR"; then
  fail 'qualification/deep nonlinear trajectory leaked into production indicator'
fi
echo 'FSI25_GATE_F_NO_DEEP_PRODUCTION_REPLAY=PASS'

git fetch --quiet --no-tags origin work/f-si18-reference-convergence-cliff:refs/remotes/origin/work/f-si18-reference-convergence-cliff
[[ "$(git rev-parse "$FSI18_BRANCH:$FSI18_GENERATOR")" == "$FSI18_GENERATOR_BLOB" ]] || fail 'F-SI18 TRIDAG generator drift'
git show "$FSI18_BRANCH:$FSI18_GENERATOR" > "$BUILD/make_reference_tridag.py"
python3 "$BUILD/make_reference_tridag.py" "$STUB" "$BUILD/reference_tridag_stubs.f90"
grep -Fq 'SWAP 4.3.1 tridag.f90' "$BUILD/reference_tridag_stubs.f90" || fail 'reference TRIDAG marker missing'
if grep -Fq 'solution(i) = 0.0d0' "$BUILD/reference_tridag_stubs.f90"; then
  fail 'zero-correction TRIDAG survived reference replacement'
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
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

build_and_run() {
  local opt="$1"
  local tag="$2"
  local out="$BUILD/$tag"
  mkdir -p "$out"
  local objects=()
  local src obj cid h0 jump horizon expected generated exe runout

  for src in "${MODULE_SRC[@]}"; do
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done

  while IFS=$'\t' read -r cid h0 jump horizon expected; do
    generated="$out/production_case_${cid}.f90"
    cp "$DRIVER" "$generated"
    python3 - "$generated" "$horizon" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); dt=float(sys.argv[2]); s=p.read_text()
old='real(real64), parameter :: total_dt = 0.25_real64, hard_mass_gate = 1.0e-12_real64'
new=f'real(real64), parameter :: total_dt = {dt:.17e}_real64, hard_mass_gate = 1.0e-12_real64'
if s.count(old)!=1:
    raise SystemExit('FSI25 frozen replay driver horizon token drift')
p.write_text(s.replace(old,new,1))
PY
    obj="$out/production_case_${cid}.o"
    exe="$out/production_case_${cid}"
    runout="$out/production_case_${cid}.txt"
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$generated" -o "$obj"
    gfortran "$opt" "${objects[@]}" "$obj" -o "$exe"
    timeout 180s "$exe" "$h0" "$jump" > "$runout" 2>&1 || {
      cat "$runout" >&2
      fail "production frozen case failed opt=$tag case=$cid"
    }
    grep -Fq 'FSI25_REFERENCE_INDICATOR_CASE PASS' "$runout" || fail "production PASS marker missing opt=$tag case=$cid"
    echo "FSI25_GATE_F_CASE_RUN=PASS:OPT=$tag:CASE=$cid:H0=$h0:JUMP=$jump:HORIZON=$horizon:EXPECTED_BINF=$expected"
  done < "$BUILD/cases.tsv"
}

build_and_run -O0 o0
build_and_run -O2 o2

for i in $(seq 1 16); do
  cmp "$BUILD/o0/production_case_${i}.txt" "$BUILD/o2/production_case_${i}.txt" || {
    diff -u "$BUILD/o0/production_case_${i}.txt" "$BUILD/o2/production_case_${i}.txt" >&2 || true
    fail "frozen production O0/O2 drift case=$i"
  }
done
echo 'FSI25_GATE_F_O0_O2_FROZEN_MATRIX_IDENTITY=PASS'

python3 - "$BUILD" "$BUILD/cases.tsv" <<'PY'
from pathlib import Path
import math,re,sys
b=Path(sys.argv[1]); cases=Path(sys.argv[2]).read_text().splitlines()
rowpat=re.compile(r'^FSI25_PROD_ROW:H0=\s*([^:]+):JUMP=\s*([^:]+):RAW_M=\s*([^:]+):D2_M=\s*([^:]+):BM=\s*([^:]+):BINF=\s*([^:]+):MIN_M=\s*([^:]+):ROUTE=(\S+)$')
diagpat=re.compile(r'^FSI25_PROD_DIAG:MASS=\s*([^:]+):EXTRA_NONLINEAR=(\d+):EXTRA_TRIDAG=(\d+):PRINCIPAL_LINEAR=(\d+)$')
maxdiff=0.0
maxmass=0.0
for line in cases:
    cid_s,h0_s,jump_s,dt_s,expected_s=line.split('\t')
    cid=int(cid_s); expected=float(expected_s)
    text=(b/'o0'/f'production_case_{cid}.txt').read_text().splitlines()
    rows=[rowpat.match(x) for x in text if x.startswith('FSI25_PROD_ROW:')]
    diags=[diagpat.match(x) for x in text if x.startswith('FSI25_PROD_DIAG:')]
    if len(rows)!=1 or rows[0] is None or len(diags)!=1 or diags[0] is None:
        raise SystemExit(f'case {cid}: production row parse failure')
    r=rows[0]; d=diags[0]
    got=float(r.group(6)); mass=float(d.group(1)); extra_nl=int(d.group(2)); extra_tri=int(d.group(3))
    if not math.isfinite(got) or not math.isfinite(mass): raise SystemExit(f'case {cid}: nonfinite output')
    diff=abs(got-expected); scale=max(1.0,abs(got),abs(expected))
    if diff > 65536.0*sys.float_info.epsilon*scale:
        raise SystemExit(f'case {cid}: F-VQ30 B_inf replay drift got={got} expected={expected} diff={diff}')
    if mass > 1.0e-12: raise SystemExit(f'case {cid}: hard mass gate failed {mass}')
    if extra_nl != 0 or extra_tri != 1: raise SystemExit(f'case {cid}: bounded-cost counters nl={extra_nl} tri={extra_tri}')
    maxdiff=max(maxdiff,diff); maxmass=max(maxmass,mass)
    print(f'FSI25_GATE_F_FROZEN_ROW:CASE={cid}:H0={float(h0_s):.17e}:JUMP={float(jump_s):.17e}:DT={float(dt_s):.17e}:BINF={got:.17e}:EXPECTED={expected:.17e}:ABS_DIFF={diff:.17e}:MASS={mass:.17e}:ROUTE={r.group(8)}')
print('FSI25_GATE_F_FROZEN_CASES=16')
print(f'FSI25_GATE_F_MAX_BINF_ABS_DIFF={maxdiff:.17e}')
print(f'FSI25_GATE_F_MAX_MASS={maxmass:.17e}')
print('FSI25_GATE_F_BOUNDED_COST=PASS')
print('FSI25_GATE_F_FVQ30_PRODUCTION_REPLAY=PASS')
PY

echo 'FSI25_FVQ30_FROZEN_PRODUCTION_REPLAY PASS'
