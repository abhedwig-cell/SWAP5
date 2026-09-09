#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi25-prod-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=2590820b228ca5fd3ac31c12728310a10171a144
CONTRACT=integration/f-si/F-SI25_WORK_UNIT_CONTRACT.json
CONTRACT_COMMIT=e39b2c7fae157ab73cd163bda07d642c2285588e
GATE_B=integration/f-si/F-SI25_GATE_B_CONTRACT_EVIDENCE.json
ORACLE=tests/fsi/test_fsi24_gate_c_nonlinear_b110.f90
ORACLE_BLOB=ecacaf1c004c7118f1ada388c672166d9ad19345
DRIVER=tests/fsi/test_fsi25_reference_indicator_production_seam.f90
C2_EVIDENCE=integration/f-si/F-SI23_GATE_C2_PHYSICAL_TRANSFER_EVIDENCE.json
C2_EVIDENCE_BLOB=cac160dbbdbb89b172d2afa055994d918abb0bbc
STUB=tests/fsi/fsi04_real_headcalc_stubs.f90
FSI18_BRANCH=origin/work/f-si18-reference-convergence-cliff
FSI18_GENERATOR=tests/fsi/fsi18_make_reference_tridag_stubs.py
FSI18_GENERATOR_BLOB=bf25c4c7fefaa59811255b0bc25c041522ab008e
INDICATOR=src/solver/mod_reference_richards_temporal_indicator.f90

fail() { echo "FSI25_PRODUCTION_SEAM_RUNNER_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$CONTRACT_COMMIT" HEAD || fail 'contract commit not in branch history'
[[ "$(git rev-parse HEAD:$ORACLE)" == "$ORACLE_BLOB" ]] || fail 'F-SI24 owner oracle drift'
[[ "$(git rev-parse HEAD:$C2_EVIDENCE)" == "$C2_EVIDENCE_BLOB" ]] || fail 'F-SI23 C2 evidence drift'
python3 - "$CONTRACT" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p['fixed_candidate_semantics']['analytic_factor']==2.0
assert p['fixed_candidate_semantics']['empirical_factor_fitted'] is False
assert p['fixed_candidate_semantics']['scientific_tolerance_selected'] is False
assert p['state_and_scratch_ownership']['persistent_per_column_state_added_by_F_SI25'] is False
assert p['public_contract_direction']['do_not_expose_operator_arrays'] is True
print('FSI25_CONTRACT_LOCK=PASS')
PY

# F-SI25 may change the common contract, add its bounded operator service and
# bind that service to the reference adapter. The legacy HeadCalc implementation,
# runtime transaction code and existing provider implementations must remain unchanged.
git diff --quiet "$BASE" -- \
  src/legacy/b1_10_port/headcalc.f90 \
  src/runtime/mod_a23bu_worker_execution_context.f90 \
  src/solver/mod_reference_richards_workspace.f90 \
  src/solver/mod_b110_default_mvg_provider.f90 \
  src/solver/mod_b110_source_sink_provider.f90 \
  || fail 'forbidden production source drift'
if grep -Eq 'dfdh|old_head|delta_head' "$INDICATOR"; then
  fail 'indicator service reads HeadCalc/Newton internal arrays'
fi
[[ "$(grep -c 'call reference_tridag' "$INDICATOR")" -eq 1 ]] || fail 'indicator must contain exactly one defect TRIDAG call site'
if grep -Eq 'call[[:space:]].*%solve|N128|N256|N512|nsteps|run_trajectory' "$INDICATOR"; then
  fail 'deep/full nonlinear refinement leaked into production indicator'
fi
echo 'FSI25_GATE_C_OPERATOR_OWNERSHIP_AND_COST_SOURCE_GUARDS=PASS'

bash tests/fsi/run_fsi25_temporal_indicator_contract.sh > "$BUILD/gate_b.txt"
grep -Fq 'FSI25_GATE_B_GENERIC_SOLVER_DEFAULT=PASS' "$BUILD/gate_b.txt" || fail 'Gate B regression failed'

git fetch --quiet --no-tags origin work/f-si18-reference-convergence-cliff:refs/remotes/origin/work/f-si18-reference-convergence-cliff
[[ "$(git rev-parse "$FSI18_BRANCH:$FSI18_GENERATOR")" == "$FSI18_GENERATOR_BLOB" ]] || fail 'F-SI18 TRIDAG generator drift'
git show "$FSI18_BRANCH:$FSI18_GENERATOR" > "$BUILD/make_reference_tridag.py"
python3 "$BUILD/make_reference_tridag.py" "$STUB" "$BUILD/reference_tridag_stubs.f90"
grep -Fq 'SWAP 4.3.1 tridag.f90' "$BUILD/reference_tridag_stubs.f90" || fail 'reference TRIDAG marker missing'
if grep -Fq 'solution(i) = 0.0d0' "$BUILD/reference_tridag_stubs.f90"; then
  fail 'zero-correction TRIDAG survived reference replacement'
fi

python3 - "$C2_EVIDENCE" "$BUILD/cases.tsv" <<'PY'
import json,sys
src,out=sys.argv[1:]
d=json.load(open(src))
rows=d['rows']
if len(rows)!=15: raise SystemExit('expected 15 F-SI24 owner rows')
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
  for src in "${MODULE_SRC[@]}"; do
    local obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$ORACLE" -o "$out/oracle.o"
  gfortran "$opt" "${objects[@]}" "$out/oracle.o" -o "$out/oracle"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$DRIVER" -o "$out/production.o"
  gfortran "$opt" "${objects[@]}" "$out/production.o" -o "$out/production"

  while IFS=$'\t' read -r cid h0 jump eobs e1512; do
    timeout 120s "$out/oracle" "$h0" "$jump" "$eobs" "$e1512" > "$out/oracle_${cid}.txt" 2>&1 || {
      cat "$out/oracle_${cid}.txt" >&2
      fail "owner oracle case $cid failed opt=$tag"
    }
    timeout 120s "$out/production" "$h0" "$jump" > "$out/production_${cid}.txt" 2>&1 || {
      cat "$out/production_${cid}.txt" >&2
      fail "production seam case $cid failed opt=$tag"
    }
    grep -Fq 'FSI24_GATE_C_NONLINEAR_CASE PASS' "$out/oracle_${cid}.txt" || fail "owner oracle marker missing case $cid"
    grep -Fq 'FSI25_REFERENCE_INDICATOR_CASE PASS' "$out/production_${cid}.txt" || fail "production marker missing case $cid"
    echo "FSI25_CASE_RUN=PASS:OPT=$tag:CASE=$cid:H0=$h0:JUMP=$jump"
  done < "$BUILD/cases.tsv"
}

build_and_run -O0 o0
build_and_run -O2 o2

for i in $(seq 1 15); do
  cmp "$BUILD/o0/production_${i}.txt" "$BUILD/o2/production_${i}.txt" || {
    diff -u "$BUILD/o0/production_${i}.txt" "$BUILD/o2/production_${i}.txt" >&2 || true
    fail "production O0/O2 drift case $i"
  }
done
echo 'FSI25_GATE_G_O0_O2_IDENTITY=PASS'

python3 - "$BUILD" <<'PY'
from pathlib import Path
import math,re,sys
b=Path(sys.argv[1])
old=re.compile(r'^FSI24_GC_ROW:H0=\s*([^:]+):JUMP=\s*([^:]+):EOBS=\s*([^:]+):E1_512=\s*([^:]+):RAW_M=\s*([^:]+):D2_M=\s*([^:]+):BM=\s*([^:]+):BINF=\s*([^:]+):DINF=\s*([^:]+):MIN_M=\s*([^:]+):')
new=re.compile(r'^FSI25_PROD_ROW:H0=\s*([^:]+):JUMP=\s*([^:]+):RAW_M=\s*([^:]+):D2_M=\s*([^:]+):BM=\s*([^:]+):BINF=\s*([^:]+):MIN_M=\s*([^:]+):ROUTE=(\S+)$')
maxdiff=0.0
for cid in range(1,16):
    ol=[old.match(x) for x in (b/'o0'/f'oracle_{cid}.txt').read_text().splitlines() if x.startswith('FSI24_GC_ROW:')]
    nl=[new.match(x) for x in (b/'o0'/f'production_{cid}.txt').read_text().splitlines() if x.startswith('FSI25_PROD_ROW:')]
    if len(ol)!=1 or ol[0] is None or len(nl)!=1 or nl[0] is None: raise SystemExit(f'case {cid}: row parse failure')
    om=ol[0]; nm=nl[0]
    oval=[float(om.group(i)) for i in (5,6,7,8,10)]
    nval=[float(nm.group(i)) for i in (3,4,5,6,7)]
    if not all(math.isfinite(x) for x in oval+nval): raise SystemExit(f'case {cid}: nonfinite')
    diffs=[]
    for a,c in zip(oval,nval):
        scale=max(1.0,abs(a),abs(c))
        diff=abs(a-c)
        diffs.append(diff)
        if diff > 65536.0*sys.float_info.epsilon*scale:
            raise SystemExit(f'case {cid}: production/oracle drift {a} {c} diff={diff}')
    maxdiff=max(maxdiff,max(diffs))
    print(f'FSI25_OWNER_REPLAY_ROW:CASE={cid}:BINF={nval[3]:.17e}:MAX_ABS_DIFF={max(diffs):.17e}:ROUTE={nm.group(8)}')
print('FSI25_OWNER_REPLAY_CASES=15')
print(f'FSI25_OWNER_REPLAY_MAX_ABS_DIFF={maxdiff:.17e}')
print('FSI25_GATE_C_D_F_OWNER_REPLAY=PASS')
PY

echo 'FSI25_GATE_E_NONINTERFERENCE_AND_COST=PASS'
echo 'FSI25_PRODUCTION_OPERATOR_SEAM_OWNER_VERIFICATION PASS'
