#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq28-refreach-$$"
mkdir -p "$BUILD"; trap 'rm -rf "$BUILD"' EXIT; cd "$ROOT"
FVQ27=1dc8219beda37fbcd6fd4232c964208fa0f17c8f
FSI18_BRANCH=origin/work/f-si18-reference-convergence-cliff
STUB_BLOB=23c00e4a188e88bc36ef95cbe4faaacdd6aad639
GEN_BLOB=bf25c4c7fefaa59811255b0bc25c041522ab008e
fail(){ echo "FVQ28R_FAIL $*" >&2; exit 1; }
git diff --quiet "$FVQ27" -- src || fail 'production source drift'
[[ "$(git rev-parse HEAD:tests/fsi/fsi04_real_headcalc_stubs.f90)" == "$STUB_BLOB" ]] || fail 'stub drift'
[[ "$(git rev-parse "$FSI18_BRANCH:tests/fsi/fsi18_make_reference_tridag_stubs.py")" == "$GEN_BLOB" ]] || fail 'TRIDAG generator drift'
grep -Fq 'integer, parameter :: nrefs(nn) = [64,128,256,512]' tests/fvq/test_fvq28_reference_reachability.f90
grep -Fq 'horizons(na) = [ 0.25_real64,0.125_real64,0.0625_real64 ]' tests/fvq/test_fvq28_reference_reachability.f90
grep -Fq 'request%numerical%max_iterations=8' tests/fvq/test_fvq28_reference_reachability.f90
grep -Fq 'request%numerical%max_backtracking=4' tests/fvq/test_fvq28_reference_reachability.f90
echo 'FVQ28R_SOURCE_AND_MATRIX_LOCK=PASS'
git show "$FSI18_BRANCH:tests/fsi/fsi18_make_reference_tridag_stubs.py" > "$BUILD/make_ref.py"
python3 "$BUILD/make_ref.py" tests/fsi/fsi04_real_headcalc_stubs.f90 "$BUILD/fsi04_reference_tridag_stubs.f90"
grep -Fq 'SWAP 4.3.1 tridag.f90' "$BUILD/fsi04_reference_tridag_stubs.f90" || fail 'TRIDAG marker missing'
echo 'FVQ28R_REFERENCE_TRIDAG=PASS'
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULES=(
 "$BUILD/fsi04_reference_tridag_stubs.f90"
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
build_run(){
 local opt="$1" tag="$2" out="$BUILD/$tag"; mkdir -p "$out"; local objs=()
 for src in "${MODULES[@]}"; do local obj="$out/$(basename "${src%.*}").o"; gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$src" -o "$obj"; objs+=("$obj"); done
 gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c tests/fvq/test_fvq28_reference_reachability.f90 -o "$out/test.o"
 gfortran "$opt" "${objs[@]}" "$out/test.o" -o "$out/test"
 timeout 480s "$out/test" > "$out/run1.txt" 2>&1; timeout 480s "$out/test" > "$out/run2.txt" 2>&1; cmp "$out/run1.txt" "$out/run2.txt"
 grep -Fq 'FVQ28R_REFERENCE_REACHABILITY_DRIVER PASS CASES=24:ROWS=288' "$out/run1.txt"
 echo "FVQ28R_REPEAT_${tag}=PASS"
}
build_run -O0 o0
build_run -O2 o2
cmp "$BUILD/o0/run1.txt" "$BUILD/o2/run1.txt"
echo 'FVQ28R_O0_O2_IDENTITY=PASS'
cat "$BUILD/o0/run1.txt"
python3 - "$BUILD/o0/run1.txt" <<'PY'
from pathlib import Path
import re,sys,collections
lines=Path(sys.argv[1]).read_text().splitlines()
pat=re.compile(r'FVQ28R_ROW:CASE=(\d+):STATE=(\d+):JUMP_ID=(\d+):ATTEMPT=(\d+):NREF_ID=(\d+):H0=\s*([^:]+):JUMP=\s*([^:]+):N=(\d+):SUBDT=\s*([^:]+):SUCCESS=([TF]):FAILURE_CLASS=(\d+):FIRST_FAILED_STEP=(\d+):FAIL_STATUS=(\d+):MAX_MASS=\s*([^:]+):MAX_SOLVER_RES=\s*([^:]+):MAX_NITER=(\d+):MAX_NBACK=(\d+)')
rows=[]
for line in lines:
 if line.startswith('FVQ28R_ROW:'):
  m=pat.match(line)
  if not m: raise SystemExit('bad row '+line)
  rows.append(dict(case=int(m.group(1)),state=int(m.group(2)),jump=int(m.group(3)),attempt=int(m.group(4)),nid=int(m.group(5)),h0=float(m.group(6)),j=float(m.group(7)),n=int(m.group(8)),subdt=float(m.group(9)),ok=m.group(10)=='T',fclass=int(m.group(11)),fstep=int(m.group(12)),status=int(m.group(13)),mass=float(m.group(14)),solver=float(m.group(15)),nit=int(m.group(16)),nback=int(m.group(17))))
if len(rows)!=288: raise SystemExit(f'expected 288 rows, got {len(rows)}')
if any(r['fclass']==2 for r in rows): raise SystemExit('mass failure found')
print(f"FVQ28R_ROWS={len(rows)}:SOLVER_FAILURE_ROWS={sum(not r['ok'] for r in rows)}:MASS_FAILURE_ROWS=0")
for n in (64,128,256,512):
 rr=[r for r in rows if r['n']==n]
 print(f"FVQ28R_N_SUMMARY:N={n}:SUCCESS={sum(r['ok'] for r in rr)}:FAIL={sum(not r['ok'] for r in rr)}")
for a,dt in ((1,.25),(2,.125),(3,.0625)):
 for n in (64,128,256,512):
  rr=[r for r in rows if r['attempt']==a and r['n']==n]
  print(f"FVQ28R_HORIZON_N:ATTEMPT={a}:DT={dt:.8f}:N={n}:SUCCESS={sum(r['ok'] for r in rr)}:FAIL={sum(not r['ok'] for r in rr)}")
for state in range(1,7):
 for n in (64,128,256,512):
  rr=[r for r in rows if r['state']==state and r['n']==n]
  print(f"FVQ28R_STATE_N:STATE={state}:H0={rr[0]['h0']:.1f}:N={n}:SUCCESS={sum(r['ok'] for r in rr)}:FAIL={sum(not r['ok'] for r in rr)}")
universal=[]
for n in (64,128,256,512):
 if all(r['ok'] for r in rows if r['n']==n): universal.append(n)
print('FVQ28R_UNIVERSALLY_REACHABLE_LEVELS='+(','.join(map(str,universal)) if universal else 'NONE'))
if universal: print(f'FVQ28R_FINEST_UNIVERSALLY_REACHABLE_N={max(universal)}')
fails=[r for r in rows if not r['ok']]
if fails:
 first=min(fails,key=lambda r:(r['subdt'],r['case'],r['attempt'],r['n']))
 print(f"FVQ28R_FAILURE_SUBDT_MIN={min(r['subdt'] for r in fails):.17e}:MAX={max(r['subdt'] for r in fails):.17e}")
 for r in fails[:40]: print(f"FVQ28R_FAILURE:CASE={r['case']}:STATE={r['state']}:H0={r['h0']:.1f}:JUMP_ID={r['jump']}:ATTEMPT={r['attempt']}:N={r['n']}:SUBDT={r['subdt']:.17e}:FIRST_STEP={r['fstep']}:STATUS={r['status']}:NITER={r['nit']}:NBACK={r['nback']}")
print(f"FVQ28R_MAX_MASS_ON_SUCCESS={max(r['mass'] for r in rows if r['ok']):.17e}")
print(f"FVQ28R_MAX_NITER={max(r['nit'] for r in rows)}:MAX_NBACK={max(r['nback'] for r in rows)}")
print('FVQ28R_REFERENCE_REACHABILITY_ATTRIBUTION PASS')
PY
git diff --quiet "$FVQ27" -- src || fail 'production source changed'
echo 'FVQ28R_PRODUCTION_SOURCE_UNCHANGED=PASS'
