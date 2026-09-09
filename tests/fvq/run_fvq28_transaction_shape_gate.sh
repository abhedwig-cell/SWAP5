#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq28-gateb-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=99f57db11ba30ffbc8b2bd44936b212f66cced9d
FVQ27=1dc8219beda37fbcd6fd4232c964208fa0f17c8f
BACKEND_BLOB=6f39d60a87c1987ae95d7faec2f55f865af90a08
FGC02_BRANCH=origin/work/f-gc02-physical-coupling-seam
FGC02_FIXTURE_BLOB=d8c3863a1acb08eb60712c7dd58bafc4cc5de5a6
STUB_BLOB=23c00e4a188e88bc36ef95cbe4faaacdd6aad639
FSI18_BRANCH=origin/work/f-si18-reference-convergence-cliff
FSI18_GENERATOR_BLOB=bf25c4c7fefaa59811255b0bc25c041522ab008e
TX_DRIVER_BLOB=ad28a6d3cde236df55646af3e46a974aa8987aad
REF_DRIVER_BLOB=3fbd3b2c0cce8773b68dcd13b10a8a427707c98e
GATEA_DRIVER_BLOB=82e75725e8d8c159b20260cd6d68d25ee4a98823

fail() { echo "FVQ28B_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$BASE" HEAD || fail 'F-VQ28 base not ancestor'
git diff --quiet "$FVQ27" -- src || fail 'production source drift from F-VQ27'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == "$BACKEND_BLOB" ]] || fail 'backend blob drift'
[[ "$(git rev-parse "$FGC02_BRANCH:tests/fgc/test_fgc02_physical_coupling.f90")" == "$FGC02_FIXTURE_BLOB" ]] || fail 'F-GC02 fixture drift'
[[ "$(git rev-parse HEAD:tests/fsi/fsi04_real_headcalc_stubs.f90)" == "$STUB_BLOB" ]] || fail 'zero-correction stub drift'
[[ "$(git rev-parse "$FSI18_BRANCH:tests/fsi/fsi18_make_reference_tridag_stubs.py")" == "$FSI18_GENERATOR_BLOB" ]] || fail 'F-SI18 generator drift'
[[ "$(git rev-parse HEAD:tests/fvq/test_fvq28_transaction_shape_matrix.f90)" == "$TX_DRIVER_BLOB" ]] || fail 'transaction matrix drift'
[[ "$(git rev-parse HEAD:tests/fvq/test_fvq28_transaction_shape_reference.f90)" == "$REF_DRIVER_BLOB" ]] || fail 'same-endpoint reference drift'
[[ "$(git rev-parse HEAD:tests/fvq/test_fvq28_heldout_temporal_profile.f90)" == "$GATEA_DRIVER_BLOB" ]] || fail 'Gate A matrix drift'

grep -Fq 'cfg%transaction%retry_scale = 0.5_real64' tests/fvq/test_fvq28_transaction_shape_matrix.f90
grep -Fq 'cfg%transaction%max_retries = 2' tests/fvq/test_fvq28_transaction_shape_matrix.f90
grep -Fq 'cfg%max_committed_substeps = 1' tests/fvq/test_fvq28_transaction_shape_matrix.f90
grep -Fq 'p%max_iterations = 8' tests/fvq/test_fvq28_transaction_shape_matrix.f90
grep -Fq 'p%max_backtracking = 4' tests/fvq/test_fvq28_transaction_shape_matrix.f90
grep -Fq 'p%min_step_duration = 1.0e-6_real64' tests/fvq/test_fvq28_transaction_shape_matrix.f90
grep -Fq 'attempt_dt(na) = [0.25_real64,0.125_real64,0.0625_real64]' tests/fvq/test_fvq28_transaction_shape_reference.f90
grep -Fq 'integer, parameter :: nref = 512' tests/fvq/test_fvq28_transaction_shape_reference.f90

echo 'FVQ28B_SOURCE_LOCK=PASS'
echo 'FVQ28B_FROZEN_HELDOUT_MATRIX=PASS'
echo 'FVQ28B_EXACT_TRANSACTION_POLICY=PASS'

git show "$FSI18_BRANCH:tests/fsi/fsi18_make_reference_tridag_stubs.py" > "$BUILD/make_reference_tridag.py"
python3 "$BUILD/make_reference_tridag.py" tests/fsi/fsi04_real_headcalc_stubs.f90 "$BUILD/fsi04_reference_tridag_stubs.f90"
if grep -Fq 'solution(i) = 0.0d0' "$BUILD/fsi04_reference_tridag_stubs.f90"; then fail 'zero-correction TRIDAG survived'; fi
grep -Fq 'SWAP 4.3.1 tridag.f90' "$BUILD/fsi04_reference_tridag_stubs.f90" || fail 'reference TRIDAG marker missing'
echo 'FVQ28B_REFERENCE_TRIDAG=PASS'

cp src/runtime/mod_fmr_serialized_reference_backend.f90 "$BUILD/mod_fmr_serialized_reference_backend_probe.f90"
python3 - "$BUILD/mod_fmr_serialized_reference_backend_probe.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
old='''    type(fmr_serialized_physical_observation_t) :: last_observation\n  contains\n'''
new='''    type(fmr_serialized_physical_observation_t) :: last_observation\n    real(real64) :: observer_last_step_duration = 0.0_real64\n  contains\n'''
assert s.count(old)==1; s=s.replace(old,new,1)
old='''    step_duration = t1 - t0\n    if (step_duration <= 0.0_real64) return\n\n    call bind_b110_default_mvg_provider'''
new='''    step_duration = t1 - t0\n    if (step_duration <= 0.0_real64) return\n    self%observer_last_step_duration = step_duration\n\n    call bind_b110_default_mvg_provider'''
assert s.count(old)==1; s=s.replace(old,new,1)
old='''    class(fmr_serialized_reference_model_t), intent(in) :: self\n    class(transaction_state_t), intent(in) :: full_state, half_state\n    logical :: same\n'''
new='''    class(fmr_serialized_reference_model_t), intent(in) :: self\n    class(transaction_state_t), intent(in) :: full_state, half_state\n    logical :: same\n    integer :: imaxh\n    real(real64) :: dhead, attempt_dt\n'''
assert s.count(old)==1; s=s.replace(old,new,1)
old='''          if (same) same = all(full%pressure_head == half%pressure_head) .and. &\n                           all(full%water_content == half%water_content) .and. &\n                           full%ponding_depth == half%ponding_depth .and. &\n                           full%groundwater_level == half%groundwater_level\n'''
new='''          if (same) then\n            attempt_dt = 2.0_real64*self%observer_last_step_duration\n            dhead = maxval(abs(full%pressure_head-half%pressure_head))\n            imaxh = maxloc(abs(full%pressure_head-half%pressure_head),dim=1)\n            write(*,'(A,1X,ES26.17E3,1X,ES26.17E3,1X,I0)') 'FVQ28B_TX_DEFECT', attempt_dt, dhead, imaxh\n          end if\n          if (same) same = all(full%pressure_head == half%pressure_head) .and. &\n                           all(full%water_content == half%water_content) .and. &\n                           full%ponding_depth == half%ponding_depth .and. &\n                           full%groundwater_level == half%groundwater_level\n'''
assert s.count(old)==1; s=s.replace(old,new,1)
p.write_text(s)
PY
python3 - "$BUILD/mod_fmr_serialized_reference_backend_probe.f90" <<'PY'
from pathlib import Path
import sys
probe=Path(sys.argv[1]).read_text(); prod=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
probe=probe.replace('    real(real64) :: observer_last_step_duration = 0.0_real64\n','',1)
probe=probe.replace('    self%observer_last_step_duration = step_duration\n','',1)
probe=probe.replace('    integer :: imaxh\n    real(real64) :: dhead, attempt_dt\n','',1)
block='''          if (same) then\n            attempt_dt = 2.0_real64*self%observer_last_step_duration\n            dhead = maxval(abs(full%pressure_head-half%pressure_head))\n            imaxh = maxloc(abs(full%pressure_head-half%pressure_head),dim=1)\n            write(*,'(A,1X,ES26.17E3,1X,ES26.17E3,1X,I0)') 'FVQ28B_TX_DEFECT', attempt_dt, dhead, imaxh\n          end if\n'''
assert probe.count(block)==1; probe=probe.replace(block,'',1)
assert probe==prod
print('FVQ28B_OBSERVER_NORMALIZES_TO_PRODUCTION=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
TX_MODULES=(
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
  "$BUILD/mod_fmr_serialized_reference_backend_probe.f90"
  src/runtime/mod_fmr_process_hydraulic_view_binding.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/process/mod_irrigation_process.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)
REF_MODULES=(
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

build_program() {
  local opt="$1" tag="$2" kind="$3" driver="$4"
  shift 4
  local out="$BUILD/${kind}_${tag}"; mkdir -p "$out"; local objects=()
  for src in "$@"; do
    local obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$driver" -o "$out/test.o"
  gfortran "$opt" "${objects[@]}" "$out/test.o" -o "$out/test"
  timeout 480s "$out/test" > "$out/run1.txt" 2>&1 || { cat "$out/run1.txt" >&2; exit 1; }
  timeout 480s "$out/test" > "$out/run2.txt" 2>&1 || { cat "$out/run2.txt" >&2; exit 1; }
  cmp "$out/run1.txt" "$out/run2.txt"
}

for opt in -O0 -O2; do
  tag="${opt#-O}"
  build_program "$opt" "o$tag" tx tests/fvq/test_fvq28_transaction_shape_matrix.f90 "${TX_MODULES[@]}"
  build_program "$opt" "o$tag" ref tests/fvq/test_fvq28_transaction_shape_reference.f90 "${REF_MODULES[@]}"
done
cmp "$BUILD/tx_o0/run1.txt" "$BUILD/tx_o2/run1.txt"
cmp "$BUILD/ref_o0/run1.txt" "$BUILD/ref_o2/run1.txt"
grep -Fq 'FVQ28B_TRANSACTION_SHAPE_DRIVER PASS CASES=24' "$BUILD/tx_o0/run1.txt"
grep -Fq 'FVQ28B_REFERENCE_DRIVER PASS CASES=24:ATTEMPTS_PER_CASE=3' "$BUILD/ref_o0/run1.txt"
echo 'FVQ28B_REPEAT_AND_O0_O2_IDENTITY=PASS'

python3 - "$BUILD/tx_o0/run1.txt" "$BUILD/ref_o0/run1.txt" <<'PY'
from pathlib import Path
import math,re,sys
txlines=Path(sys.argv[1]).read_text().splitlines(); reflines=Path(sys.argv[2]).read_text().splitlines()
cases={}; current=None
for line in txlines:
    if line.startswith('FVQ28B_TX_CASE_BEGIN='):
        m=re.match(r'FVQ28B_TX_CASE_BEGIN=(\d+):STATE=(\d+):JUMP_ID=(\d+):H0=\s*([^:]+):JUMP=\s*([^:]+):K0=\s*(\S+)',line)
        if not m: raise SystemExit('bad tx case begin: '+line)
        current=int(m.group(1)); cases[current]={'state':int(m.group(2)),'jump_id':int(m.group(3)),'h0':float(m.group(4)),'jump':float(m.group(5)),'k0':float(m.group(6)),'rows':[],'end':None}
    elif line.startswith('FVQ28B_TX_DEFECT'):
        if current is None: raise SystemExit('tx defect outside case')
        p=line.split()
        cases[current]['rows'].append({'dt':float(p[1]),'dhead':float(p[2]),'imaxh':int(p[3])})
    elif line.startswith('FVQ28B_TX_CASE_END='):
        m=re.match(r'FVQ28B_TX_CASE_END=(\d+):STATUS=(\d+):COMPLETED=([TF]):ATTEMPTS=(\d+):RETRIES=(\d+):SOLVER_REJECTIONS=(\d+):TEMPORAL_REJECTIONS=(\d+):MASS_REJECTIONS=(\d+):ACCEPTED_SUBSTEPS=(\d+)',line)
        if not m: raise SystemExit('bad tx case end: '+line)
        cid=int(m.group(1)); cases[cid]['end']=tuple(int(m.group(i)) for i in range(4,10)); current=None
if len(cases)!=24: raise SystemExit(f'expected 24 tx cases, got {len(cases)}')
expected=[0.25,0.125,0.0625]
for cid,c in cases.items():
    if len(c['rows'])!=3: raise SystemExit(f'case {cid}: expected 3 tx defects, got {len(c["rows"])}')
    for r,e in zip(c['rows'],expected):
        if abs(r['dt']-e)>1e-15: raise SystemExit(f'case {cid}: attempt dt drift')
    if c['end']!=(3,2,0,3,0,0): raise SystemExit(f'case {cid}: topology classification {c["end"]}')
print('FVQ28B_ALL_24_EXACT_RETRY_TOPOLOGY=PASS')

refs={}
for line in reflines:
    if line.startswith('FVQ28B_REF:'):
        m=re.match(r'FVQ28B_REF:CASE=(\d+):STATE=(\d+):JUMP_ID=(\d+):ATTEMPT=(\d+):DT=\s*([^:]+):DHEAD=\s*([^:]+):E2=\s*([^:]+):MAX_MASS=\s*([^:]+):MAX_SOLVER_RES=\s*([^:]+):H0=\s*([^:]+):MAX_NITER=(\d+):MAX_NBACK=(\d+)',line)
        if not m: raise SystemExit('bad ref row: '+line)
        key=(int(m.group(1)),int(m.group(4)))
        refs[key]={'state':int(m.group(2)),'jump_id':int(m.group(3)),'dt':float(m.group(5)),'dhead':float(m.group(6)),'e2':float(m.group(7)),'mass':float(m.group(8)),'solver':float(m.group(9)),'h0':float(m.group(10)),'niter':int(m.group(11)),'nback':int(m.group(12))}
if len(refs)!=72: raise SystemExit(f'expected 72 reference rows, got {len(refs)}')
max_mass=max(r['mass'] for r in refs.values())
if max_mass>1e-12: raise SystemExit(f'hard mass gate exceeded {max_mass}')
print(f'FVQ28B_REFERENCE_MASS_HARD=PASS:MAX_MASS={max_mass:.17e}')
print(f"FVQ28B_REFERENCE_SOLVER_COST:MAX_NITER={max(r['niter'] for r in refs.values())}:MAX_NBACK={max(r['nback'] for r in refs.values())}")

under=0; resolved_total=0; lost_cases=[]; allsafe=True
for cid in sorted(cases):
    flags=[]; ratios=[]
    for ia,r in enumerate(cases[cid]['rows'],1):
        q=refs[(cid,ia)]
        scale=max(1.0,abs(r['dhead']),abs(q['dhead']))
        if abs(r['dhead']-q['dhead'])>512*2.220446049250313e-16*scale:
            raise SystemExit(f'case {cid} attempt {ia}: transaction/direct defect mismatch {r["dhead"]} {q["dhead"]}')
        resolved=r['dhead']>1e-12 and q['e2']>1e-12
        ratio=(r['dhead']/q['e2']) if q['e2']>0 else math.inf
        ratios.append(ratio)
        flags.append(None if not resolved else ratio>=1.0)
        if resolved:
            resolved_total+=1
            if ratio<1.0: under+=1; allsafe=False
    seen_safe=False; lost=False
    for f in flags:
        if f is True: seen_safe=True
        elif f is False and seen_safe: lost=True
    if lost: lost_cases.append(cid)
    c=cases[cid]
    pat=''.join('F' if f is None else ('C' if f else 'U') for f in flags)
    print(f"FVQ28B_CASE_SUMMARY:CASE={cid}:STATE={c['state']}:JUMP_ID={c['jump_id']}:H0={c['h0']:.17e}:JUMP={c['jump']:.17e}:RATIO_A1={ratios[0]:.17e}:RATIO_A2={ratios[1]:.17e}:RATIO_A3={ratios[2]:.17e}:PATTERN={pat}:LOSES_CONSERVATIVE_ON_RETRY={str(lost).upper()}")
print(f'FVQ28B_RESOLVED_ATTEMPTS={resolved_total}:UNDERCONSERVATIVE_ATTEMPTS={under}:CASES_LOSING_CONSERVATIVE_ON_RETRY={len(lost_cases)}')
if allsafe and not lost_cases:
    print('FVQ28B_RUNTIME_TRANSLATION_SAFE=YES')
else:
    print('FVQ28B_RUNTIME_TRANSLATION_SAFE=NO')
    print('FVQ28B_GATE_B_DECISION=FAIL_TRANSLATION_EXISTING_RETRY_TOPOLOGY_DOES_NOT_PRESERVE_CONSERVATIVE_RELATION')
print('FVQ28B_PRODUCTION_TOLERANCE_SELECTED=NO')
print('FVQ28B_NORMALIZATION_SELECTED=NO')
print('FVQ28B_RETRY_POLICY_CHANGED=NO')
PY

git diff --quiet "$FVQ27" -- src || fail 'production source changed during Gate B'
echo 'FVQ28B_PRODUCTION_SOURCE_UNCHANGED=PASS'
echo 'FVQ28_TRANSACTION_SHAPE_GATE_EXECUTED PASS'
