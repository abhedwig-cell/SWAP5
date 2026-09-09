#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi20-temporal-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FVQ27=1dc8219beda37fbcd6fd4232c964208fa0f17c8f
BACKEND_BLOB=6f39d60a87c1987ae95d7faec2f55f865af90a08
FGC02_BRANCH=origin/work/f-gc02-physical-coupling-seam
FGC02_FIXTURE_BLOB=d8c3863a1acb08eb60712c7dd58bafc4cc5de5a6

fail() { echo "FSI20_TEMPORAL_CHARACTERIZATION_FAIL $*" >&2; exit 1; }

git diff --quiet "$FVQ27" -- src || {
  echo 'FSI20_PRODUCTION_IMMUTABILITY_TO_FVQ27=FAIL' >&2
  git diff --name-only "$FVQ27" -- src >&2
  exit 1
}
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == "$BACKEND_BLOB" ]] || fail 'backend blob drift'
echo 'FSI20_PRODUCTION_IMMUTABILITY_TO_FVQ27=PASS'
echo 'FSI20_BINARY_TEMPORAL_BACKEND_SOURCE_LOCK=PASS'

[[ "$(git rev-parse "$FGC02_BRANCH:tests/fgc/test_fgc02_physical_coupling.f90")" == "$FGC02_FIXTURE_BLOB" ]] || fail 'F-GC02 fixture blob drift'
git show "$FGC02_BRANCH:tests/fgc/test_fgc02_physical_coupling.f90" > "$BUILD/fgc02.f90"
grep -Fq 'real(real64), parameter :: t0 = 4100.125_real64' "$BUILD/fgc02.f90"
grep -Fq 'real(real64), parameter :: t1 = 4100.375_real64' "$BUILD/fgc02.f90"
grep -Fq 'real(real64), parameter :: head_corrector_cm = -75.0_real64' "$BUILD/fgc02.f90"
grep -Fq 'real(real64), parameter :: head_predictor_cm = head_corrector_cm + 0.01_real64' "$BUILD/fgc02.f90"
grep -Fq 'p%bottom_mode = 5' "$BUILD/fgc02.f90"
grep -Fq 'forcing_predictor%bottom_head = head_predictor_cm' "$BUILD/fgc02.f90"
echo 'FSI20_FGC02_PREDICTOR_PROVENANCE_LOCK=PASS'

cp src/runtime/mod_fmr_serialized_reference_backend.f90 "$BUILD/mod_fmr_serialized_reference_backend_probe.f90"
python3 - "$BUILD/mod_fmr_serialized_reference_backend_probe.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
old='''    type(fmr_serialized_physical_observation_t) :: last_observation\n  contains\n'''
new='''    type(fmr_serialized_physical_observation_t) :: last_observation\n    real(real64) :: observer_last_step_duration = 0.0_real64\n  contains\n'''
assert s.count(old)==1
s=s.replace(old,new,1)
old='''    step_duration = t1 - t0\n    if (step_duration <= 0.0_real64) return\n\n    call bind_b110_default_mvg_provider'''
new='''    step_duration = t1 - t0\n    if (step_duration <= 0.0_real64) return\n    self%observer_last_step_duration = step_duration\n\n    call bind_b110_default_mvg_provider'''
assert s.count(old)==1
s=s.replace(old,new,1)
old='''    class(fmr_serialized_reference_model_t), intent(in) :: self\n    class(transaction_state_t), intent(in) :: full_state, half_state\n    logical :: same\n'''
new='''    class(fmr_serialized_reference_model_t), intent(in) :: self\n    class(transaction_state_t), intent(in) :: full_state, half_state\n    logical :: same\n    integer :: k, imaxh, imaxt\n    real(real64) :: dhead, dtheta, dpond, dgwl, dstorage, attempt_dt\n'''
assert s.count(old)==1
s=s.replace(old,new,1)
old='''          if (same) same = all(full%pressure_head == half%pressure_head) .and. &\n                           all(full%water_content == half%water_content) .and. &\n                           full%ponding_depth == half%ponding_depth .and. &\n                           full%groundwater_level == half%groundwater_level\n          if (same) same = allocated(full%snow) .eqv. allocated(half%snow)\n'''
new='''          if (same) then\n            attempt_dt = 2.0_real64*self%observer_last_step_duration\n            dhead = maxval(abs(full%pressure_head-half%pressure_head))\n            dtheta = maxval(abs(full%water_content-half%water_content))\n            imaxh = maxloc(abs(full%pressure_head-half%pressure_head),dim=1)\n            imaxt = maxloc(abs(full%water_content-half%water_content),dim=1)\n            dstorage = sum(self%soil_parameters%dz*(full%water_content-half%water_content))\n            dpond = full%ponding_depth-half%ponding_depth\n            dgwl = full%groundwater_level-half%groundwater_level\n            write(*,'(A,1X,ES26.17E3,1X,ES26.17E3,1X,ES26.17E3,1X,I0,1X,ES26.17E3,1X,I0,3(1X,ES26.17E3))') &\n                 'FSI20_TEMPORAL_SUMMARY', attempt_dt, self%head_rel_tolerance, dhead, imaxh, dtheta, imaxt, &\n                 dstorage, dpond, dgwl\n            do k = 1, full%active_nodes\n              write(*,'(A,1X,ES26.17E3,1X,I0,3(1X,ES26.17E3))') 'FSI20_NODE_DELTA', attempt_dt, k, &\n                   full%pressure_head(k)-half%pressure_head(k), &\n                   full%water_content(k)-half%water_content(k), self%soil_parameters%dz(k)\n            end do\n          end if\n          if (same) same = all(full%pressure_head == half%pressure_head) .and. &\n                           all(full%water_content == half%water_content) .and. &\n                           full%ponding_depth == half%ponding_depth .and. &\n                           full%groundwater_level == half%groundwater_level\n          if (same) same = allocated(full%snow) .eqv. allocated(half%snow)\n'''
assert s.count(old)==1
s=s.replace(old,new,1)
p.write_text(s)
print('FSI20_TEMPORAL_OBSERVER_COPY_GENERATED=PASS')
PY

python3 - "$BUILD/mod_fmr_serialized_reference_backend_probe.f90" <<'PY'
from pathlib import Path
import sys
probe=Path(sys.argv[1]).read_text()
prod=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
probe=probe.replace('    real(real64) :: observer_last_step_duration = 0.0_real64\n','',1)
probe=probe.replace('    self%observer_last_step_duration = step_duration\n','',1)
probe=probe.replace('    integer :: k, imaxh, imaxt\n    real(real64) :: dhead, dtheta, dpond, dgwl, dstorage, attempt_dt\n','',1)
block='''          if (same) then\n            attempt_dt = 2.0_real64*self%observer_last_step_duration\n            dhead = maxval(abs(full%pressure_head-half%pressure_head))\n            dtheta = maxval(abs(full%water_content-half%water_content))\n            imaxh = maxloc(abs(full%pressure_head-half%pressure_head),dim=1)\n            imaxt = maxloc(abs(full%water_content-half%water_content),dim=1)\n            dstorage = sum(self%soil_parameters%dz*(full%water_content-half%water_content))\n            dpond = full%ponding_depth-half%ponding_depth\n            dgwl = full%groundwater_level-half%groundwater_level\n            write(*,'(A,1X,ES26.17E3,1X,ES26.17E3,1X,ES26.17E3,1X,I0,1X,ES26.17E3,1X,I0,3(1X,ES26.17E3))') &\n                 'FSI20_TEMPORAL_SUMMARY', attempt_dt, self%head_rel_tolerance, dhead, imaxh, dtheta, imaxt, &\n                 dstorage, dpond, dgwl\n            do k = 1, full%active_nodes\n              write(*,'(A,1X,ES26.17E3,1X,I0,3(1X,ES26.17E3))') 'FSI20_NODE_DELTA', attempt_dt, k, &\n                   full%pressure_head(k)-half%pressure_head(k), &\n                   full%water_content(k)-half%water_content(k), self%soil_parameters%dz(k)\n            end do\n          end if\n'''
assert probe.count(block)==1
probe=probe.replace(block,'',1)
assert probe==prod
print('FSI20_OBSERVER_COPY_NORMALIZES_BITWISE_TO_PRODUCTION=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
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
  "$BUILD/mod_fmr_serialized_reference_backend_probe.f90"
  src/runtime/mod_fmr_process_hydraulic_view_binding.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/process/mod_irrigation_process.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fsi/test_fsi20_prescribed_head_temporal_characterization.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  timeout 120s "$OUT/test" > "$OUT/run1.txt" 2>&1 || { cat "$OUT/run1.txt" >&2; exit 1; }
  timeout 120s "$OUT/test" > "$OUT/run2.txt" 2>&1 || { cat "$OUT/run2.txt" >&2; exit 1; }
  grep -Fq 'FSI20_PRESCRIBED_HEAD_TEMPORAL_CHARACTERIZATION_DRIVER PASS' "$OUT/run1.txt"
  grep -Fq 'FSI20_TEMPORAL_SUMMARY' "$OUT/run1.txt"
  cmp "$OUT/run1.txt" "$OUT/run2.txt"
  echo "FSI20_REPEAT_DETERMINISM_O${opt}=PASS"
done
cmp "$BUILD/o0/run1.txt" "$BUILD/o2/run1.txt"
echo 'FSI20_O0_O2_IDENTITY=PASS'

python3 - "$BUILD/o0/run1.txt" <<'PY'
from pathlib import Path
import math,re,sys
lines=Path(sys.argv[1]).read_text().splitlines()
cases={}
current=None
for line in lines:
    if line.startswith('FSI20_CASE_BEGIN='):
        m=re.match(r'FSI20_CASE_BEGIN=(\d+):NONLINEAR_TOL=([^:]+):T0=([^:]+):REQUESTED_DT=(.+)',line)
        if not m: raise SystemExit('bad case begin')
        current=int(m.group(1)); cases[current]={'tol':float(m.group(2)),'rows':[],'end':None}
    elif line.startswith('FSI20_TEMPORAL_SUMMARY'):
        if current is None: raise SystemExit('summary without case')
        p=line.split()
        if len(p)!=10: raise SystemExit(f'bad summary fields {len(p)}')
        row={'dt':float(p[1]),'tol':float(p[2]),'dhead':float(p[3]),'imaxh':int(p[4]),
             'dtheta':float(p[5]),'imaxt':int(p[6]),'dstorage':float(p[7]),'dpond':float(p[8]),'dgwl':float(p[9]),'nodes':[]}
        cases[current]['rows'].append(row)
    elif line.startswith('FSI20_NODE_DELTA'):
        if current is None or not cases[current]['rows']: raise SystemExit('node row without summary')
        p=line.split()
        if len(p)!=6: raise SystemExit('bad node fields')
        cases[current]['rows'][-1]['nodes'].append((float(p[1]),int(p[2]),float(p[3]),float(p[4]),float(p[5])))
    elif line.startswith('FSI20_CASE_END='):
        if current is None: raise SystemExit('case end without begin')
        cases[current]['end']=line
        current=None
if set(cases)!={1,2,3}: raise SystemExit(f'unexpected cases {sorted(cases)}')
if not cases[2]['rows']: raise SystemExit('qualified-tolerance baseline produced no temporal comparison rows')
node_counts=set()
for cid,c in sorted(cases.items()):
    print(f"FSI20_CASE={cid}:NONLINEAR_TOL={c['tol']:.17e}:TEMPORAL_COMPARISONS={len(c['rows'])}")
    previous=None
    for j,r in enumerate(c['rows'],1):
        vals=[r['dt'],r['tol'],r['dhead'],r['dtheta'],r['dstorage'],r['dpond'],r['dgwl']]
        if not all(math.isfinite(x) for x in vals): raise SystemExit('nonfinite summary')
        node_counts.add(len(r['nodes']))
        if not r['nodes']: raise SystemExit('summary without node rows')
        bynode={n:(dh,dt,dz) for _,n,dh,dt,dz in r['nodes']}
        calc_h=max(bynode, key=lambda n: abs(bynode[n][0]))
        calc_t=max(bynode, key=lambda n: abs(bynode[n][1]))
        if calc_h!=r['imaxh'] or calc_t!=r['imaxt']: raise SystemExit('maximizing node mismatch')
        calc_storage=sum(dz*dth for _,dth,dz in bynode.values())
        scale=max(1.0,abs(calc_storage),abs(r['dstorage']))
        if abs(calc_storage-r['dstorage']) > 256*2.220446049250313e-16*scale:
            raise SystemExit('integrated theta difference mismatch')
        order='NA'
        if previous and r['dhead']>0 and previous['dhead']>0 and r['dt']>0 and previous['dt']>0:
            order=f"{math.log(previous['dhead']/r['dhead'],2)/math.log(previous['dt']/r['dt'],2):.9e}"
        print(f"FSI20_CASE={cid}:COMPARE={j}:DT={r['dt']:.17e}:DHEAD={r['dhead']:.17e}:IMAXH={r['imaxh']}:DTHETA={r['dtheta']:.17e}:IMAXTHETA={r['imaxt']}:DSTORAGE={r['dstorage']:.17e}:DPOND={r['dpond']:.17e}:DGWL={r['dgwl']:.17e}:APPARENT_ORDER={order}")
        previous=r
if len(node_counts)!=1: raise SystemExit(f'inconsistent node counts {node_counts}')
print(f'FSI20_NODEWISE_ROWS_PER_COMPARISON={next(iter(node_counts))}')
common=set(round(r['dt'],15) for r in cases[1]['rows']) & set(round(r['dt'],15) for r in cases[2]['rows']) & set(round(r['dt'],15) for r in cases[3]['rows'])
for dt in sorted(common,reverse=True):
    rows=[]
    for cid in (1,2,3):
        rows.append(next(r for r in cases[cid]['rows'] if round(r['dt'],15)==dt))
    print('FSI20_TOLERANCE_SENSITIVITY:DT='+f'{dt:.17e}'+':DHEAD='+','.join(f"{r['dhead']:.17e}" for r in rows)+':DTHETA='+','.join(f"{r['dtheta']:.17e}" for r in rows))
print('FSI20_NODEWISE_AND_INTEGRATED_TEMPORAL_EVIDENCE=PASS')
print('FSI20_NONMONOTONE_BEHAVIOR_IS_CHARACTERIZATION_NOT_FAILURE=PASS')
print('FSI20_NO_PRODUCTION_METRIC_SELECTED=PASS')
PY

echo 'FSI20_PRODUCTION_ACCEPTANCE_CHANGED=NO'
echo 'FSI20_MASS_REQUIREMENT_CHANGED=NO'
echo 'FSI20_FKT_TRANSACTION_SEMANTICS_CHANGED=NO'
echo 'FSI20_PRESCRIBED_HEAD_TEMPORAL_CHARACTERIZATION PASS'
