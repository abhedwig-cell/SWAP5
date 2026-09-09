#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fci21-si25-replay-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=ed0219402072f121856d82cb6068ab74c70f34d1
SOURCE_COMMIT=a0331164a8dfc2642becdbe96cab969eabead392
ORACLE=tests/fsi/test_fsi24_gate_c_nonlinear_b110.f90
ORACLE_BLOB=ecacaf1c004c7118f1ada388c672166d9ad19345
DRIVER=tests/fsi/test_fsi25_reference_indicator_production_seam.f90
DRIVER_BLOB=c125c6a2ab706920b7e2a5c6f1c855520b192223
C2_EVIDENCE=integration/f-si/F-SI23_GATE_C2_PHYSICAL_TRANSFER_EVIDENCE.json
C2_EVIDENCE_BLOB=cac160dbbdbb89b172d2afa055994d918abb0bbc
GENERATOR=tests/fsi/fsi18_make_reference_tridag_stubs.py
GENERATOR_BLOB=bf25c4c7fefaa59811255b0bc25c041522ab008e
STUB=tests/fsi/fsi04_real_headcalc_stubs.f90
STUB_BLOB=23c00ed17b2031bec6097a08d04fd95a775ff29a
FIXED_TOP=tests/fmr/mod_fmr04_fixed_top_provider.f90
FIXED_TOP_BLOB=942c56e3ba2b1739506e1d5b0ac889e6fd163ea7
INDICATOR=src/solver/mod_reference_richards_temporal_indicator.f90

fail() { echo "FCI21_SI25_REPLAY_FAIL $*" >&2; exit 1; }

[[ "$(git rev-parse HEAD:$ORACLE)" == "$ORACLE_BLOB" ]] || fail 'F-SI24 oracle drift'
[[ "$(git rev-parse HEAD:$DRIVER)" == "$DRIVER_BLOB" ]] || fail 'F-SI25 production driver drift'
[[ "$(git rev-parse HEAD:$C2_EVIDENCE)" == "$C2_EVIDENCE_BLOB" ]] || fail 'F-SI23 C2 evidence drift'
[[ "$(git rev-parse HEAD:$GENERATOR)" == "$GENERATOR_BLOB" ]] || fail 'F-SI18 TRIDAG generator drift'
[[ "$(git rev-parse HEAD:$STUB)" == "$STUB_BLOB" ]] || fail 'real HeadCalc stub drift'
[[ "$(git rev-parse HEAD:$FIXED_TOP)" == "$FIXED_TOP_BLOB" ]] || fail 'F-MR04 fixed-top fixture drift'
git merge-base --is-ancestor "$BASE" HEAD || fail 'not descended from exact WOF42 base'
git merge-base --is-ancestor "$SOURCE_COMMIT" HEAD || fail 'materialized source postimage not in tested history'

# Lock the scientific production seam against accidental drift during replay.
[[ "$(git rev-parse HEAD:src/solver/mod_soil_water_solver_contract.f90)" == dc7b14a06f64c8ab0af9747f707b3394a5f5cbe0 ]] || fail 'solver contract drift'
[[ "$(git rev-parse HEAD:src/solver/mod_reference_richards_temporal_indicator.f90)" == fe8f87d11257d4c6bc019f1d628ac41ba3106d4e ]] || fail 'indicator source drift'
[[ "$(git rev-parse HEAD:src/adapter/mod_reference_richards_legacy_binding.f90)" == 6eda1fec1bd03c03a1c0a8f2df29a273f70d962f ]] || fail 'reference adapter drift'

if grep -Eiq 'dfdh|old_head|delta_head' "$INDICATOR"; then
  fail 'indicator reads prohibited HeadCalc/Newton internals'
fi
[[ "$(grep -Eic 'call[[:space:]]+reference_tridag' "$INDICATOR")" -eq 1 ]] || fail 'indicator must contain exactly one defect TRIDAG call'
if grep -Eiq 'call[[:space:]].*%solve|N128|N256|N512|nsteps|run_trajectory' "$INDICATOR"; then
  fail 'deep/full nonlinear refinement leaked into production indicator'
fi
echo 'FCI21_SI25_OPERATOR_OWNERSHIP_AND_COST_GUARD=PASS'

python3 "$GENERATOR" "$STUB" "$BUILD/reference_tridag_stubs.f90"
grep -Fq 'SWAP 4.3.1 tridag.f90' "$BUILD/reference_tridag_stubs.f90" || fail 'reference TRIDAG marker missing'
if grep -Fq 'solution(i) = 0.0d0' "$BUILD/reference_tridag_stubs.f90"; then
  fail 'zero-correction fixture TRIDAG survived reference replacement'
fi

python3 - "$C2_EVIDENCE" "$BUILD/cases.tsv" <<'PY'
import json,sys
src,out=sys.argv[1:]
d=json.load(open(src))
rows=d['rows']
if len(rows)!=15:
    raise SystemExit(f'expected 15 F-SI23 C2 rows, got {len(rows)}')
with open(out,'w') as f:
    for r in rows:
        f.write(f"{r['case']}\t{r['h0_cm']:.17e}\t{r['jump_cm']:.17e}\t{r['EOBS_cm']:.17e}\t{r['E1_512_cm']:.17e}\n")
print('FCI21_SI25_CASESET_LOCK=PASS:CASES=15')
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
  "$FIXED_TOP"
)

build_and_run() {
  local opt="$1" tag="$2" out="$BUILD/$2"
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
      fail "owner oracle failed opt=$tag case=$cid"
    }
    timeout 120s "$out/production" "$h0" "$jump" > "$out/production_${cid}.txt" 2>&1 || {
      cat "$out/production_${cid}.txt" >&2
      fail "production seam failed opt=$tag case=$cid"
    }
    grep -Fq 'FSI24_GATE_C_NONLINEAR_CASE PASS' "$out/oracle_${cid}.txt" || fail "owner marker missing case=$cid opt=$tag"
    grep -Fq 'FSI25_REFERENCE_INDICATOR_CASE PASS' "$out/production_${cid}.txt" || fail "production marker missing case=$cid opt=$tag"
    echo "FCI21_SI25_CASE=PASS:OPT=$tag:CASE=$cid"
  done < "$BUILD/cases.tsv"
}

build_and_run -O0 o0
build_and_run -O2 o2

for i in $(seq 1 15); do
  cmp "$BUILD/o0/production_${i}.txt" "$BUILD/o2/production_${i}.txt" || {
    diff -u "$BUILD/o0/production_${i}.txt" "$BUILD/o2/production_${i}.txt" >&2 || true
    fail "production O0/O2 drift case=$i"
  }
done
echo 'FCI21_SI25_O0_O2_IDENTITY=PASS'

python3 - "$BUILD" <<'PY'
from pathlib import Path
import math,re,sys
b=Path(sys.argv[1])
old=re.compile(r'^FSI24_GC_ROW:H0=\s*([^:]+):JUMP=\s*([^:]+):EOBS=\s*([^:]+):E1_512=\s*([^:]+):RAW_M=\s*([^:]+):D2_M=\s*([^:]+):BM=\s*([^:]+):BINF=\s*([^:]+):DINF=\s*([^:]+):MIN_M=\s*([^:]+):')
new=re.compile(r'^FSI25_PROD_ROW:H0=\s*([^:]+):JUMP=\s*([^:]+):RAW_M=\s*([^:]+):D2_M=\s*([^:]+):BM=\s*([^:]+):BINF=\s*([^:]+):MIN_M=\s*([^:]+):ROUTE=(\S+)$')
maxdiff=0.0
for cid in range(1,16):
    om=[old.match(x) for x in (b/'o0'/f'oracle_{cid}.txt').read_text().splitlines() if x.startswith('FSI24_GC_ROW:')]
    nm=[new.match(x) for x in (b/'o0'/f'production_{cid}.txt').read_text().splitlines() if x.startswith('FSI25_PROD_ROW:')]
    if len(om)!=1 or om[0] is None or len(nm)!=1 or nm[0] is None:
        raise SystemExit(f'case {cid}: replay row parse failure')
    o=om[0]; n=nm[0]
    oval=[float(o.group(i)) for i in (5,6,7,8,10)]
    nval=[float(n.group(i)) for i in (3,4,5,6,7)]
    if not all(math.isfinite(x) for x in oval+nval):
        raise SystemExit(f'case {cid}: nonfinite replay metric')
    diffs=[]
    for a,c in zip(oval,nval):
        scale=max(1.0,abs(a),abs(c))
        diff=abs(a-c)
        diffs.append(diff)
        if diff > 65536.0*sys.float_info.epsilon*scale:
            raise SystemExit(f'case {cid}: owner/production drift {a} {c} diff={diff}')
    maxdiff=max(maxdiff,max(diffs))
    print(f'FCI21_SI25_OWNER_REPLAY_ROW:CASE={cid}:BINF={nval[3]:.17e}:MAX_ABS_DIFF={max(diffs):.17e}:ROUTE={n.group(8)}')
print('FCI21_SI25_OWNER_REPLAY_CASES=15')
print(f'FCI21_SI25_OWNER_REPLAY_MAX_ABS_DIFF={maxdiff:.17e}')
print('FCI21_SI25_OWNER_REPLAY=PASS')
PY

echo 'FCI21_SI25_NONINTERFERENCE_AND_COST=PASS'
echo 'FCI21_SI25_SCIENTIFIC_REPLAY PASS'
