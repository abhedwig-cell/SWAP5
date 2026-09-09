#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq28-gateb-v2-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=99f57db11ba30ffbc8b2bd44936b212f66cced9d
FVQ27=1dc8219beda37fbcd6fd4232c964208fa0f17c8f
BACKEND_BLOB=6f39d60a87c1987ae95d7faec2f55f865af90a08
TX_DRIVER_BLOB=eeab63e9ac304b9f519d5b56b6b56b83f8a20b98
REF_DRIVER_BLOB=68d347550c9f9caaa69c3190e5c7484c12a9d8a6
STUB_BLOB=23c00e4a188e88bc36ef95cbe4faaacdd6aad639
FGC02_FIXTURE_BLOB=d8c3863a1acb08eb60712c7dd58bafc4cc5de5a6
FSI18_GENERATOR_BLOB=bf25c4c7fefaa59811255b0bc25c041522ab008e
FGC02_BRANCH=origin/work/f-gc02-physical-coupling-seam
FSI18_BRANCH=origin/work/f-si18-reference-convergence-cliff
fail(){ echo "FVQ28B_V2_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$BASE" HEAD || fail 'base not ancestor'
git diff --quiet "$FVQ27" -- src || fail 'production source drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == "$BACKEND_BLOB" ]] || fail 'backend drift'
[[ "$(git rev-parse HEAD:tests/fvq/test_fvq28_transaction_shape_matrix.f90)" == "$TX_DRIVER_BLOB" ]] || fail 'transaction driver drift'
[[ "$(git rev-parse HEAD:tests/fvq/test_fvq28_transaction_shape_reference.f90)" == "$REF_DRIVER_BLOB" ]] || fail 'reference driver drift'
[[ "$(git rev-parse HEAD:tests/fsi/fsi04_real_headcalc_stubs.f90)" == "$STUB_BLOB" ]] || fail 'stub drift'
[[ "$(git rev-parse "$FGC02_BRANCH:tests/fgc/test_fgc02_physical_coupling.f90")" == "$FGC02_FIXTURE_BLOB" ]] || fail 'FGC02 fixture drift'
[[ "$(git rev-parse "$FSI18_BRANCH:tests/fsi/fsi18_make_reference_tridag_stubs.py")" == "$FSI18_GENERATOR_BLOB" ]] || fail 'TRIDAG generator drift'
grep -Fq 'cfg%transaction%retry_scale = 0.5_real64' tests/fvq/test_fvq28_transaction_shape_matrix.f90
grep -Fq 'cfg%transaction%max_retries = 2' tests/fvq/test_fvq28_transaction_shape_matrix.f90
grep -Fq 'cfg%max_committed_substeps = 1' tests/fvq/test_fvq28_transaction_shape_matrix.f90
grep -Fq 'attempt_dt(na) = [0.25_real64,0.125_real64,0.0625_real64]' tests/fvq/test_fvq28_transaction_shape_reference.f90
grep -Fq 'integer, parameter :: nref = 512' tests/fvq/test_fvq28_transaction_shape_reference.f90
echo 'FVQ28B_V2_SOURCE_LOCK=PASS'
echo 'FVQ28B_V2_FROZEN_GATE_B=PASS'

git show "$FSI18_BRANCH:tests/fsi/fsi18_make_reference_tridag_stubs.py" > "$BUILD/make_reference_tridag.py"
python3 "$BUILD/make_reference_tridag.py" tests/fsi/fsi04_real_headcalc_stubs.f90 "$BUILD/fsi04_reference_tridag_stubs.f90"
grep -Fq 'SWAP 4.3.1 tridag.f90' "$BUILD/fsi04_reference_tridag_stubs.f90" || fail 'reference TRIDAG marker missing'
if grep -Fq 'solution(i) = 0.0d0' "$BUILD/fsi04_reference_tridag_stubs.f90"; then fail 'zero correction survived'; fi
echo 'FVQ28B_V2_REFERENCE_TRIDAG=PASS'

cp src/runtime/mod_fmr_serialized_reference_backend.f90 "$BUILD/backend_probe.f90"
python3 - "$BUILD/backend_probe.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
a='    type(fmr_serialized_physical_observation_t) :: last_observation\n  contains\n'
b='    type(fmr_serialized_physical_observation_t) :: last_observation\n    real(real64) :: observer_last_step_duration = 0.0_real64\n  contains\n'
assert s.count(a)==1; s=s.replace(a,b,1)
a='    step_duration = t1 - t0\n    if (step_duration <= 0.0_real64) return\n\n    call bind_b110_default_mvg_provider'
b='    step_duration = t1 - t0\n    if (step_duration <= 0.0_real64) return\n    self%observer_last_step_duration = step_duration\n\n    call bind_b110_default_mvg_provider'
assert s.count(a)==1; s=s.replace(a,b,1)
a='    class(transaction_state_t), intent(in) :: full_state, half_state\n    logical :: same\n'
b='    class(transaction_state_t), intent(in) :: full_state, half_state\n    logical :: same\n    integer :: imaxh\n    real(real64) :: dhead, attempt_dt\n'
assert s.count(a)==1; s=s.replace(a,b,1)
a='''          if (same) same = all(full%pressure_head == half%pressure_head) .and. &
                           all(full%water_content == half%water_content) .and. &
                           full%ponding_depth == half%ponding_depth .and. &
                           full%groundwater_level == half%groundwater_level
'''
b='''          if (same) then
            attempt_dt = 2.0_real64*self%observer_last_step_duration
            dhead = maxval(abs(full%pressure_head-half%pressure_head))
            imaxh = maxloc(abs(full%pressure_head-half%pressure_head),dim=1)
            write(*,'(A,1X,ES26.17E3,1X,ES26.17E3,1X,I0)') 'FVQ28B_TX_DEFECT', attempt_dt, dhead, imaxh
          end if
          if (same) same = all(full%pressure_head == half%pressure_head) .and. &
                           all(full%water_content == half%water_content) .and. &
                           full%ponding_depth == half%ponding_depth .and. &
                           full%groundwater_level == half%groundwater_level
'''
assert s.count(a)==1; s=s.replace(a,b,1)
p.write_text(s)
PY
python3 - "$BUILD/backend_probe.f90" <<'PY'
from pathlib import Path
import sys
probe=Path(sys.argv[1]).read_text(); prod=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
probe=probe.replace('    real(real64) :: observer_last_step_duration = 0.0_real64\n','',1)
probe=probe.replace('    self%observer_last_step_duration = step_duration\n','',1)
probe=probe.replace('    integer :: imaxh\n    real(real64) :: dhead, attempt_dt\n','',1)
block='''          if (same) then
            attempt_dt = 2.0_real64*self%observer_last_step_duration
            dhead = maxval(abs(full%pressure_head-half%pressure_head))
            imaxh = maxloc(abs(full%pressure_head-half%pressure_head),dim=1)
            write(*,'(A,1X,ES26.17E3,1X,ES26.17E3,1X,I0)') 'FVQ28B_TX_DEFECT', attempt_dt, dhead, imaxh
          end if
'''
assert probe.count(block)==1; probe=probe.replace(block,'',1)
assert probe==prod
print('FVQ28B_V2_OBSERVER_NORMALIZES_TO_PRODUCTION=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
TX_MODULES=("$BUILD/fsi04_reference_tridag_stubs.f90" src/runtime/mod_a23bu_worker_execution_context.f90 src/transaction/mod_transaction_reference.f90 src/runtime/mod_canonical_contracts.f90 src/runtime/mod_canonical_interval_runtime.f90 src/kernel/mod_kernel_transactions.f90 src/runtime/mod_fmr_runtime_core.f90 src/runtime/mod_fmr_checkpoint_orchestrator.f90 src/solver/mod_soil_water_solver_contract.f90 src/solver/mod_process_hydraulic_view.f90 src/solver/mod_reference_linear_solver.f90 src/solver/mod_reference_richards_workspace.f90 src/solver/mod_reference_richards_state_binding.f90 src/solver/mod_b110_default_mvg_provider.f90 src/solver/mod_b110_source_sink_provider.f90 src/solver/mod_b110_root_sink_provider.f90 src/legacy/b1_10_port/headcalc.f90 src/adapter/mod_reference_richards_legacy_binding.f90 src/adapter/mod_b110_serialized_context_binding.f90 src/process/mod_snow_process.f90 "$BUILD/backend_probe.f90" src/runtime/mod_fmr_process_hydraulic_view_binding.f90 src/runtime/mod_fmr_serialized_multiswap_runtime.f90 src/process/mod_irrigation_process.f90 tests/fmr/mod_fmr04_fixed_top_provider.f90)
REF_MODULES=("$BUILD/fsi04_reference_tridag_stubs.f90" src/runtime/mod_a23bu_worker_execution_context.f90 src/solver/mod_soil_water_solver_contract.f90 src/solver/mod_process_hydraulic_view.f90 src/solver/mod_reference_linear_solver.f90 src/solver/mod_reference_richards_workspace.f90 src/solver/mod_reference_richards_state_binding.f90 src/solver/mod_b110_default_mvg_provider.f90 src/solver/mod_b110_source_sink_provider.f90 src/legacy/b1_10_port/headcalc.f90 src/adapter/mod_reference_richards_legacy_binding.f90 tests/fmr/mod_fmr04_fixed_top_provider.f90)

build(){ local opt="$1" tag="$2" kind="$3" driver="$4"; shift 4; local out="$BUILD/${kind}_${tag}"; mkdir -p "$out"; local objs=(); for src in "$@"; do local obj="$out/$(basename "${src%.*}").o"; gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$src" -o "$obj"; objs+=("$obj"); done; gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$driver" -o "$out/test.o"; gfortran "$opt" "${objs[@]}" "$out/test.o" -o "$out/test"; timeout 480s "$out/test" > "$out/run1.txt" 2>&1; timeout 480s "$out/test" > "$out/run2.txt" 2>&1; cmp "$out/run1.txt" "$out/run2.txt"; }
for opt in -O0 -O2; do tag="o${opt#-O}"; build "$opt" "$tag" tx tests/fvq/test_fvq28_transaction_shape_matrix.f90 "${TX_MODULES[@]}"; build "$opt" "$tag" ref tests/fvq/test_fvq28_transaction_shape_reference.f90 "${REF_MODULES[@]}"; done
cmp "$BUILD/tx_o0/run1.txt" "$BUILD/tx_o2/run1.txt"
cmp "$BUILD/ref_o0/run1.txt" "$BUILD/ref_o2/run1.txt"
grep -Fq 'FVQ28B_TRANSACTION_SHAPE_DRIVER PASS CASES=24' "$BUILD/tx_o0/run1.txt"
grep -Fq 'FVQ28B_REFERENCE_DRIVER PASS CASES=24:ATTEMPTS_PER_CASE=3' "$BUILD/ref_o0/run1.txt"
echo 'FVQ28B_V2_REPEAT_AND_O0_O2_IDENTITY=PASS'

python3 - "$BUILD/tx_o0/run1.txt" "$BUILD/ref_o0/run1.txt" <<'PY'
from pathlib import Path
import math,re,sys
cases={}; current=None
for line in Path(sys.argv[1]).read_text().splitlines():
    if line.startswith('FVQ28B_TX_CASE_BEGIN='):
        m=re.match(r'FVQ28B_TX_CASE_BEGIN=(\d+):STATE=(\d+):JUMP_ID=(\d+):H0=\s*([^:]+):JUMP=\s*([^:]+):K0=\s*(\S+)',line)
        if not m: raise SystemExit('bad tx begin')
        current=int(m.group(1)); cases[current]={'state':int(m.group(2)),'jump_id':int(m.group(3)),'h0':float(m.group(4)),'jump':float(m.group(5)),'rows':[],'end':None}
    elif line.startswith('FVQ28B_TX_DEFECT'):
        p=line.split(); cases[current]['rows'].append((float(p[1]),float(p[2])))
    elif line.startswith('FVQ28B_TX_CASE_END='):
        m=re.match(r'FVQ28B_TX_CASE_END=(\d+):STATUS=(\d+):COMPLETED=([TF]):ATTEMPTS=(\d+):RETRIES=(\d+):SOLVER_REJECTIONS=(\d+):TEMPORAL_REJECTIONS=(\d+):MASS_REJECTIONS=(\d+):ACCEPTED_SUBSTEPS=(\d+)',line)
        if not m: raise SystemExit('bad tx end')
        cid=int(m.group(1)); cases[cid]['end']=tuple(int(m.group(i)) for i in range(4,10)); current=None
if len(cases)!=24: raise SystemExit(f'tx case count {len(cases)}')
for cid,c in cases.items():
    if len(c['rows'])!=3: raise SystemExit(f'case {cid} tx rows {len(c["rows"])}')
    if c['end']!=(3,2,0,3,0,0): raise SystemExit(f'case {cid} tx topology {c["end"]}')
    for (dt,_),e in zip(c['rows'],[0.25,0.125,0.0625]):
        if abs(dt-e)>1e-15: raise SystemExit('tx dt drift')
print('FVQ28B_V2_ALL_24_EXACT_RETRY_TOPOLOGY=PASS')

refs={}; unavailable=[]
for line in Path(sys.argv[2]).read_text().splitlines():
    if line.startswith('FVQ28B_REF_OK:'):
        m=re.match(r'FVQ28B_REF_OK:CASE=(\d+):STATE=(\d+):JUMP_ID=(\d+):ATTEMPT=(\d+):DT=\s*([^:]+):DHEAD=\s*([^:]+):E2=\s*([^:]+):MAX_MASS=\s*([^:]+):MAX_SOLVER_RES=\s*([^:]+):H0=\s*([^:]+):MAX_NITER=(\d+):MAX_NBACK=(\d+)',line)
        if not m: raise SystemExit('bad ref ok row: '+line)
        key=(int(m.group(1)),int(m.group(4))); refs[key]={'available':True,'dt':float(m.group(5)),'dhead':float(m.group(6)),'e2':float(m.group(7)),'mass':float(m.group(8)),'solver':float(m.group(9)),'niter':int(m.group(11)),'nback':int(m.group(12))}
    elif line.startswith('FVQ28B_REF_UNAVAILABLE:'):
        m=re.match(r'FVQ28B_REF_UNAVAILABLE:CASE=(\d+):STATE=(\d+):JUMP_ID=(\d+):ATTEMPT=(\d+):DT=\s*([^:]+):DHEAD=\s*([^:]+):FULL_OK=([TF]):HALF_OK=([TF]):REF_OK=([TF]):FULL_FAIL_STEP=(\d+):FULL_STATUS=(-?\d+):HALF_FAIL_STEP=(\d+):HALF_STATUS=(-?\d+):REF_FAIL_STEP=(\d+):REF_STATUS=(-?\d+):MAX_MASS=\s*(\S+)',line)
        if not m: raise SystemExit('bad unavailable row: '+line)
        key=(int(m.group(1)),int(m.group(4))); refs[key]={'available':False,'dt':float(m.group(5)),'dhead':float(m.group(6)),'e2':None,'mass':float(m.group(16)),'full_ok':m.group(7)=='T','half_ok':m.group(8)=='T','ref_ok':m.group(9)=='T','ref_fail_step':int(m.group(14)),'ref_status':int(m.group(15))}; unavailable.append(key)
if len(refs)!=72: raise SystemExit(f'reference rows {len(refs)}')
print(f'FVQ28B_V2_REFERENCE_ROWS=72:AVAILABLE={72-len(unavailable)}:UNAVAILABLE={len(unavailable)}')
max_mass=max(r['mass'] for r in refs.values())
if max_mass>1e-12: raise SystemExit(f'mass gate exceeded {max_mass}')
print(f'FVQ28B_V2_REFERENCE_MASS_HARD=PASS:MAX_MASS={max_mass:.17e}')

under=0; resolved=0; lost=[]; mismatch=0
for cid in sorted(cases):
    flags=[]; ratios=[]; pattern=[]
    for ia,(_,txdh) in enumerate(cases[cid]['rows'],1):
        q=refs[(cid,ia)]
        if q['dhead']>=0:
            scale=max(1.0,abs(txdh),abs(q['dhead']))
            if abs(txdh-q['dhead'])>512*2.220446049250313e-16*scale: mismatch+=1
        if not q['available']:
            flags.append(None); ratios.append(None); pattern.append('X'); continue
        ratio=txdh/q['e2'] if q['e2']>0 else math.inf
        ratios.append(ratio)
        f=None if txdh<=1e-12 or q['e2']<=1e-12 else ratio>=1.0
        flags.append(f); pattern.append('F' if f is None else ('C' if f else 'U'))
        if f is not None: resolved+=1; under+=int(not f)
    seen=False; lose=False
    for f in flags:
        if f is True: seen=True
        elif f is False and seen: lose=True
    if lose: lost.append(cid)
    c=cases[cid]
    def fmt(x): return 'NA' if x is None else f'{x:.17e}'
    print(f"FVQ28B_V2_CASE_SUMMARY:CASE={cid}:STATE={c['state']}:JUMP_ID={c['jump_id']}:H0={c['h0']:.17e}:JUMP={c['jump']:.17e}:RATIO_A1={fmt(ratios[0])}:RATIO_A2={fmt(ratios[1])}:RATIO_A3={fmt(ratios[2])}:PATTERN={''.join(pattern)}:LOSES_CONSERVATIVE_ON_RETRY={str(lose).upper()}")
if mismatch: raise SystemExit(f'transaction/direct defect mismatches {mismatch}')
print('FVQ28B_V2_TRANSACTION_DIRECT_DEFECT_IDENTITY=PASS')
print(f'FVQ28B_V2_RESOLVED_ATTEMPTS={resolved}:UNDERCONSERVATIVE_ATTEMPTS={under}:UNAVAILABLE_REFERENCE_ATTEMPTS={len(unavailable)}:CASES_LOSING_CONSERVATIVE_ON_RETRY={len(lost)}')
if under==0 and not lost and not unavailable:
    print('FVQ28B_RUNTIME_TRANSLATION_SAFE=YES')
    print('FVQ28B_GATE_B_DECISION=PASS_EXISTING_TRANSACTION_TOPOLOGY_TRANSLATES_HELDOUT_PROFILE')
elif under>0 or lost:
    print('FVQ28B_RUNTIME_TRANSLATION_SAFE=NO')
    print('FVQ28B_GATE_B_DECISION=FAIL_TRANSLATION_EXISTING_RETRY_TOPOLOGY_DOES_NOT_PRESERVE_CONSERVATIVE_RELATION')
else:
    print('FVQ28B_RUNTIME_TRANSLATION_SAFE=NOT_QUALIFIED')
    print('FVQ28B_GATE_B_DECISION=FAIL_CLOSED_REFERENCE_CEILING_PREVENTS_RUNTIME_TRANSLATION_QUALIFICATION')
for cid,ia in unavailable:
    q=refs[(cid,ia)]; c=cases[cid]
    print(f"FVQ28B_V2_REF_CEILING:CASE={cid}:STATE={c['state']}:JUMP_ID={c['jump_id']}:ATTEMPT={ia}:DT={q['dt']:.17e}:REF_FAIL_STEP={q.get('ref_fail_step',0)}:REF_STATUS={q.get('ref_status',0)}")
print('FVQ28B_PRODUCTION_TOLERANCE_SELECTED=NO')
print('FVQ28B_NORMALIZATION_SELECTED=NO')
print('FVQ28B_RETRY_POLICY_CHANGED=NO')
PY

git diff --quiet "$FVQ27" -- src || fail 'production source changed during Gate B'
echo 'FVQ28B_V2_PRODUCTION_SOURCE_UNCHANGED=PASS'
echo 'FVQ28B_V2_GATE_EXECUTED=PASS'
