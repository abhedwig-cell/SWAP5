#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi20-solver-attribution-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FVQ27=1dc8219beda37fbcd6fd4232c964208fa0f17c8f
BACKEND_BLOB=6f39d60a87c1987ae95d7faec2f55f865af90a08
DRIVER_BLOB=98c945164b6ca7d9c2aaef332a322896f132fa79
STUB_BLOB=23c00e4a188e88bc36ef95cbe4faaacdd6aad639
FSI18_BRANCH=origin/work/f-si18-reference-convergence-cliff
FSI18_GENERATOR_BLOB=bf25c4c7fefaa59811255b0bc25c041522ab008e

fail() { echo "FSI20_SOLVER_ATTRIBUTION_FAIL $*" >&2; exit 1; }

git diff --quiet "$FVQ27" -- src || fail 'production source differs from FVQ27'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == "$BACKEND_BLOB" ]] || fail 'backend drift'
[[ "$(git rev-parse HEAD:tests/fsi/test_fsi20_prescribed_head_temporal_characterization.f90)" == "$DRIVER_BLOB" ]] || fail 'driver drift'
[[ "$(git rev-parse HEAD:tests/fsi/fsi04_real_headcalc_stubs.f90)" == "$STUB_BLOB" ]] || fail 'fixture stub drift'
[[ "$(git rev-parse "$FSI18_BRANCH:tests/fsi/fsi18_make_reference_tridag_stubs.py")" == "$FSI18_GENERATOR_BLOB" ]] || fail 'F-SI18 reference TRIDAG generator drift'
echo 'FSI20_SOLVER_ATTRIBUTION_SOURCE_LOCK=PASS'

# Generate the F-SI18-qualified test-only SWAP 4.3.1 Thomas/TRIDAG control.
git show "$FSI18_BRANCH:tests/fsi/fsi18_make_reference_tridag_stubs.py" > "$BUILD/make_reference_tridag.py"
python3 "$BUILD/make_reference_tridag.py" tests/fsi/fsi04_real_headcalc_stubs.f90 "$BUILD/fsi04_reference_tridag_stubs.f90"

# Exact F-GC02 numerical controls, with retries extended only to observe the
# existing fail-closed trajectory. No tolerance, mass gate or production source changes.
cp tests/fsi/test_fsi20_prescribed_head_temporal_characterization.f90 "$BUILD/driver.f90"
python3 - "$BUILD/driver.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
repls={
  '    p%max_iterations = 16\n':'    p%max_iterations = 8\n',
  '    p%max_backtracking = 8\n':'    p%max_backtracking = 4\n',
  '    p%min_step_duration = 1.0e-8_real64\n':'    p%min_step_duration = 1.0e-6_real64\n',
  '    cfg%transaction%max_retries = 6\n':'    cfg%transaction%max_retries = 16\n',
}
for old,new in repls.items():
    if s.count(old)!=1: raise SystemExit(f'expected one driver token: {old.strip()}')
    s=s.replace(old,new,1)
p.write_text(s)
PY
grep -Fq 'p%max_iterations = 8' "$BUILD/driver.f90"
grep -Fq 'p%max_backtracking = 4' "$BUILD/driver.f90"
grep -Fq 'p%min_step_duration = 1.0e-6_real64' "$BUILD/driver.f90"
grep -Fq 'cfg%transaction%max_retries = 16' "$BUILD/driver.f90"
echo 'FSI20_SOLVER_ATTRIBUTION_EXACT_FGC02_SOLVER_CONTROLS=PASS'

# Observer-only backend copy. It writes every direct Richards solve leg before
# transaction logic decides solver/temporal/mass acceptance.
cp src/runtime/mod_fmr_serialized_reference_backend.f90 "$BUILD/backend_probe.f90"
python3 - "$BUILD/backend_probe.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
old='''    call self%solver%solve(request, self%workspace, solve_result)\n    self%last_observation%solver_executed = .true.\n'''
new='''    call self%solver%solve(request, self%workspace, solve_result)\n    write(*,'(A,3(1X,ES26.17E3),1X,I0,4(1X,I0),2(1X,ES26.17E3))') &\n         'FSI20_SOLVE_OBSERVER', t0, t1, step_duration, solve_result%status, &\n         solve_result%diagnostics%nonlinear_iterations, solve_result%diagnostics%jacobian_builds, &\n         solve_result%diagnostics%linear_solves, solve_result%diagnostics%backtracking_attempts, &\n         solve_result%unrounded_mass_balance_residual, solve_result%bottom_flux\n    self%last_observation%solver_executed = .true.\n'''
if s.count(old)!=1: raise SystemExit('solver observer insertion target drift')
s=s.replace(old,new,1)
p.write_text(s)
PY
python3 - "$BUILD/backend_probe.f90" <<'PY'
from pathlib import Path
import sys
probe=Path(sys.argv[1]).read_text(); prod=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
block='''    write(*,'(A,3(1X,ES26.17E3),1X,I0,4(1X,I0),2(1X,ES26.17E3))') &\n         'FSI20_SOLVE_OBSERVER', t0, t1, step_duration, solve_result%status, &\n         solve_result%diagnostics%nonlinear_iterations, solve_result%diagnostics%jacobian_builds, &\n         solve_result%diagnostics%linear_solves, solve_result%diagnostics%backtracking_attempts, &\n         solve_result%unrounded_mass_balance_residual, solve_result%bottom_flux\n'''
if probe.count(block)!=1: raise SystemExit('observer block normalization drift')
probe=probe.replace(block,'',1)
if probe!=prod: raise SystemExit('observer copy does not normalize to production')
print('FSI20_SOLVER_ATTRIBUTION_OBSERVER_NORMALIZES_TO_PRODUCTION=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  "$BUILD/fsi04_reference_tridag_stubs.f90"
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
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
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  "$BUILD/backend_probe.f90"
  src/runtime/mod_fmr_process_hydraulic_view_binding.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/process/mod_irrigation_process.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

OUT="$BUILD/o0"; mkdir -p "$OUT"; objects=()
for src in "${MODULE_SRC[@]}"; do
  obj="$OUT/$(basename "${src%.*}").o"
  gfortran "${COMMON[@]}" -O0 -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -O0 -J "$OUT" -I "$OUT" -c "$BUILD/driver.f90" -o "$OUT/test.o"
gfortran -O0 "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
timeout 180s "$OUT/test" > "$OUT/run.txt" 2>&1 || { cat "$OUT/run.txt" >&2; exit 1; }
grep -Fq 'FSI20_PRESCRIBED_HEAD_TEMPORAL_CHARACTERIZATION_DRIVER PASS' "$OUT/run.txt"
grep -Fq 'FSI20_SOLVE_OBSERVER' "$OUT/run.txt"

python3 - "$OUT/run.txt" <<'PY'
from pathlib import Path
import math,sys
lines=Path(sys.argv[1]).read_text().splitlines()
case=None; calls={1:[],2:[],3:[]}; ends={}
for line in lines:
    if line.startswith('FSI20_CASE_BEGIN='):
        case=int(line.split('=',1)[1].split(':',1)[0])
    elif line.startswith('FSI20_SOLVE_OBSERVER'):
        if case not in calls: raise SystemExit('solve observer without case')
        p=line.split()
        if len(p)!=11: raise SystemExit(f'bad solve observer fields: {len(p)} {line}')
        calls[case].append(dict(t0=float(p[1]),t1=float(p[2]),dt=float(p[3]),status=int(p[4]),
            nit=int(p[5]),njac=int(p[6]),nlin=int(p[7]),nback=int(p[8]),mass=float(p[9]),qbot=float(p[10])))
    elif line.startswith('FSI20_CASE_END='):
        cid=int(line.split('=',1)[1].split(':',1)[0]); ends[cid]=line; case=None

for cid in (1,2,3):
    if cid not in ends or not calls[cid]: raise SystemExit(f'incomplete case {cid}')

base=calls[2]
print('FSI20_SOLVER_ATTRIBUTION_BASELINE_CALLS='+str(len(base)))
origin=4100.125
base_dt=0.25
max_attempts=17

def close(a,b,tol=2e-12):
    return abs(a-b) <= tol*max(1.0,abs(a),abs(b))

# Reconstruct each transaction attempt from the exact expected call geometry:
# FULL [t0,t0+D], then HALF1 [t0,t0+D/2], then HALF2 [t0+D/2,t0+D].
# A failed solver leg terminates that attempt immediately.
groups=[]; pos=0
for attempt in range(1,max_attempts+1):
    D=base_dt/(2**(attempt-1))
    if pos >= len(base): raise SystemExit(f'missing FULL call for attempt {attempt}')
    full=base[pos]; pos+=1
    if not (close(full['t0'],origin) and close(full['t1'],origin+D) and close(full['dt'],D)):
        raise SystemExit(f'FULL geometry mismatch attempt {attempt}: {full}')
    g=[('FULL',full)]
    if full['status'] == 1:
        if pos >= len(base): raise SystemExit(f'missing HALF1 call for attempt {attempt}')
        half1=base[pos]; pos+=1
        if not (close(half1['t0'],origin) and close(half1['t1'],origin+D/2) and close(half1['dt'],D/2)):
            raise SystemExit(f'HALF1 geometry mismatch attempt {attempt}: {half1}')
        g.append(('HALF1',half1))
        if half1['status'] == 1:
            if pos >= len(base): raise SystemExit(f'missing HALF2 call for attempt {attempt}')
            half2=base[pos]; pos+=1
            if not (close(half2['t0'],origin+D/2) and close(half2['t1'],origin+D) and close(half2['dt'],D/2)):
                raise SystemExit(f'HALF2 geometry mismatch attempt {attempt}: {half2}')
            g.append(('HALF2',half2))
    groups.append((attempt,D,g))
if pos != len(base): raise SystemExit(f'unconsumed solve calls: {len(base)-pos}')

failed=[]
for attempt,D,g in groups:
    for leg,c in g:
        mass='nan' if not math.isfinite(c['mass']) else f"{c['mass']:.17e}"
        print(f"FSI20_SOLVER_ATTRIBUTION_CALL:ATTEMPT={attempt}:ATTEMPT_DT={D:.17e}:LEG={leg}:SOLVE_DT={c['dt']:.17e}:STATUS={c['status']}:NITER={c['nit']}:NJAC={c['njac']}:NLIN={c['nlin']}:NBACK={c['nback']}:MASS_RES={mass}:QBOT={c['qbot']:.17e}")
    first_fail=next(((leg,c) for leg,c in g if c['status']!=1),None)
    if first_fail:
        leg,c=first_fail; failed.append((attempt,D,leg,c))
        mass='nan' if not math.isfinite(c['mass']) else f"{c['mass']:.17e}"
        print(f"FSI20_SOLVER_ATTRIBUTION_ATTEMPT:INDEX={attempt}:DT={D:.17e}:FIRST_FAILURE={leg}:STATUS={c['status']}:NITER={c['nit']}:NBACK={c['nback']}:MASS_RES={mass}")
    else:
        print(f"FSI20_SOLVER_ATTRIBUTION_ATTEMPT:INDEX={attempt}:DT={D:.17e}:FIRST_FAILURE=NONE")

print('FSI20_SOLVER_ATTRIBUTION_ATTEMPTS='+str(len(groups)))
print('FSI20_SOLVER_ATTRIBUTION_FAILED_ATTEMPTS='+str(len(failed)))
if failed:
    a,D,leg,c=failed[0]
    print(f'FSI20_SOLVER_ATTRIBUTION_FIRST_FAILED_ATTEMPT={a}')
    print(f'FSI20_SOLVER_ATTRIBUTION_FIRST_FAILED_ATTEMPT_DT={D:.17e}')
    print(f'FSI20_SOLVER_ATTRIBUTION_FIRST_FAILED_LEG={leg}')
    print(f"FSI20_SOLVER_ATTRIBUTION_FIRST_FAILED_SOLVE_DT={c['dt']:.17e}")
    print(f'FSI20_SOLVER_ATTRIBUTION_FIRST_FAILED_STATUS={c["status"]}')
    print(f'FSI20_SOLVER_ATTRIBUTION_FIRST_FAILED_NITER={c["nit"]}')
    print(f'FSI20_SOLVER_ATTRIBUTION_FIRST_FAILED_NBACK={c["nback"]}')
print('FSI20_SOLVER_ATTRIBUTION_MASS_GATE_CHANGED=NO')
print('FSI20_SOLVER_ATTRIBUTION_SOLVER_CONTROLS_CHANGED=NO')
print('FSI20_SOLVER_ATTRIBUTION_PRODUCTION_SOURCE_CHANGED=NO')
PY

cat "$OUT/run.txt" | grep -E 'FSI20_CASE_END=|FSI20_SOLVE_OBSERVER' >/dev/null
echo 'FSI20_SOLVER_REJECTION_ATTRIBUTION PASS'
