#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi21-gateb-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FVQ27=1dc8219beda37fbcd6fd4232c964208fa0f17c8f
FVQ28=d8bcb1c90e897812ae8b91295be98e58023e10fb
BACKEND_BLOB=6f39d60a87c1987ae95d7faec2f55f865af90a08
TX_DRIVER_BLOB=eeab63e9ac304b9f519d5b56b6b56b83f8a20b98
MVG_BLOB=97d67eb373073b183be6d1bf5b756ecb5125dde2
GATEB_EVIDENCE_BLOB=279d50777a6fb362514818d004a5ddd23423b60d
STUB_BLOB=23c00e4a188e88bc36ef95cbe4faaacdd6aad639
FSI18_GENERATOR_BLOB=bf25c4c7fefaa59811255b0bc25c041522ab008e
FSI18_BRANCH=origin/work/f-si18-reference-convergence-cliff

fail(){ echo "FSI21_GATEB_FAIL $*" >&2; exit 1; }

git diff --quiet "$FVQ27" -- src || fail 'production source drift from exact F-VQ27 postimage'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == "$BACKEND_BLOB" ]] || fail 'serialized backend drift'
[[ "$(git rev-parse HEAD:src/solver/mod_b110_default_mvg_provider.f90)" == "$MVG_BLOB" ]] || fail 'MvG provider drift'
[[ "$(git rev-parse "$FVQ28:tests/fvq/test_fvq28_transaction_shape_matrix.f90")" == "$TX_DRIVER_BLOB" ]] || fail 'F-VQ28 transaction matrix drift'
[[ "$(git rev-parse "$FVQ28:integration/f-vq/F-VQ28_GATE_B_EVIDENCE.json")" == "$GATEB_EVIDENCE_BLOB" ]] || fail 'F-VQ28 Gate B evidence drift'
[[ "$(git rev-parse HEAD:tests/fsi/fsi04_real_headcalc_stubs.f90)" == "$STUB_BLOB" ]] || fail 'HeadCalc stub drift'
[[ "$(git rev-parse "$FSI18_BRANCH:tests/fsi/fsi18_make_reference_tridag_stubs.py")" == "$FSI18_GENERATOR_BLOB" ]] || fail 'reference TRIDAG generator drift'
python3 - <<'PY'
import json
p=json.load(open('integration/f-si/F-SI21_GATE_B_OBSERVATION_PLAN.json'))
assert p['gate']=='B_DYNAMIC_LOCAL_HYDRAULIC_CHARACTERIZATION'
assert p['observation_locations_frozen_before_execution']==[
    'CHECKPOINT_T0','FULL_ENDPOINT_T1_ATTEMPT','HALF1_MIDPOINT','HALF2_ENDPOINT_T1_ATTEMPT']
assert p['hard_restrictions']['fit_threshold'] is False
assert p['hard_restrictions']['select_normalization'] is False
assert p['hard_restrictions']['select_tolerance'] is False
assert p['hard_restrictions']['change_production_source'] is False
print('FSI21_GATEB_PREDECLARED_OBSERVATION_PLAN=PASS')
PY
echo 'FSI21_GATEB_PRODUCTION_SOURCE_IMMUTABILITY=PASS'
echo 'FSI21_GATEB_FROZEN_FVQ28_MATRIX_LOCK=PASS'

# Use the same SWAP 4.3.1 Thomas/TRIDAG test-only control already qualified in F-VQ28.
git show "$FSI18_BRANCH:tests/fsi/fsi18_make_reference_tridag_stubs.py" > "$BUILD/make_reference_tridag.py"
python3 "$BUILD/make_reference_tridag.py" tests/fsi/fsi04_real_headcalc_stubs.f90 "$BUILD/fsi04_reference_tridag_stubs.f90"
grep -Fq 'SWAP 4.3.1 tridag.f90' "$BUILD/fsi04_reference_tridag_stubs.f90" || fail 'reference TRIDAG marker missing'
if grep -Fq 'solution(i) = 0.0d0' "$BUILD/fsi04_reference_tridag_stubs.f90"; then fail 'zero-correction stub survived'; fi
echo 'FSI21_GATEB_REFERENCE_TRIDAG=PASS'

# Instrument a temporary backend copy only. Every added block is removed below and the file must then equal production byte-for-byte.
cp src/runtime/mod_fmr_serialized_reference_backend.f90 "$BUILD/backend_probe.f90"
python3 - "$BUILD/backend_probe.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
a='    real(real64) :: step_duration\n    logical :: context_ok, snow_event_applied_this_call\n'
b='''    real(real64) :: step_duration
    real(real64), allocatable :: observer_water(:), observer_k(:), observer_c(:), observer_dkdh(:)
    real(real64) :: observer_d, observer_tau, observer_l
    logical :: context_ok, snow_event_applied_this_call
'''
assert s.count(a)==1; s=s.replace(a,b,1)
a='''    call account_external_fluxes(self, step_duration, solve_result%top_flux, solve_result%bottom_flux, &
         snow_event_applied_this_call, outcome%mass_in, outcome%mass_out)
'''
b='''    select type (physical => state)
    type is (fmr_b110_physical_state_t)
      allocate(observer_water(physical%active_nodes), observer_k(physical%active_nodes), &
               observer_c(physical%active_nodes), observer_dkdh(physical%active_nodes))
      call self%constitutive%evaluate(physical%pressure_head, observer_water, observer_k, observer_c, observer_dkdh)
      observer_l = self%soil_parameters%dz(physical%active_nodes)
      observer_d = observer_k(physical%active_nodes)/observer_c(physical%active_nodes)
      observer_tau = observer_c(physical%active_nodes)*observer_l*observer_l/observer_k(physical%active_nodes)
      write(*,'(A,13(A,ES26.17E3))') 'FSI21B_ADVANCE', &
           ':T0=', t0, ':T1=', t1, ':DT=', step_duration, &
           ':H_BOTTOM=', physical%pressure_head(physical%active_nodes), &
           ':H_MIN=', minval(physical%pressure_head), ':H_MAX=', maxval(physical%pressure_head), &
           ':THETA_BOTTOM=', physical%water_content(physical%active_nodes), &
           ':THETA_MIN=', minval(physical%water_content), ':THETA_MAX=', maxval(physical%water_content), &
           ':K_BOTTOM=', observer_k(physical%active_nodes), ':C_BOTTOM=', observer_c(physical%active_nodes), &
           ':D_BOTTOM=', observer_d, ':TAU_BOTTOM=', observer_tau
    end select

    call account_external_fluxes(self, step_duration, solve_result%top_flux, solve_result%bottom_flux, &
         snow_event_applied_this_call, outcome%mass_in, outcome%mass_out)
'''
assert s.count(a)==1; s=s.replace(a,b,1)
p.write_text(s)
PY
python3 - "$BUILD/backend_probe.f90" <<'PY'
from pathlib import Path
import sys
probe=Path(sys.argv[1]).read_text(); prod=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
probe=probe.replace('''    real(real64), allocatable :: observer_water(:), observer_k(:), observer_c(:), observer_dkdh(:)
    real(real64) :: observer_d, observer_tau, observer_l
''','',1)
block='''    select type (physical => state)
    type is (fmr_b110_physical_state_t)
      allocate(observer_water(physical%active_nodes), observer_k(physical%active_nodes), &
               observer_c(physical%active_nodes), observer_dkdh(physical%active_nodes))
      call self%constitutive%evaluate(physical%pressure_head, observer_water, observer_k, observer_c, observer_dkdh)
      observer_l = self%soil_parameters%dz(physical%active_nodes)
      observer_d = observer_k(physical%active_nodes)/observer_c(physical%active_nodes)
      observer_tau = observer_c(physical%active_nodes)*observer_l*observer_l/observer_k(physical%active_nodes)
      write(*,'(A,13(A,ES26.17E3))') 'FSI21B_ADVANCE', &
           ':T0=', t0, ':T1=', t1, ':DT=', step_duration, &
           ':H_BOTTOM=', physical%pressure_head(physical%active_nodes), &
           ':H_MIN=', minval(physical%pressure_head), ':H_MAX=', maxval(physical%pressure_head), &
           ':THETA_BOTTOM=', physical%water_content(physical%active_nodes), &
           ':THETA_MIN=', minval(physical%water_content), ':THETA_MAX=', maxval(physical%water_content), &
           ':K_BOTTOM=', observer_k(physical%active_nodes), ':C_BOTTOM=', observer_c(physical%active_nodes), &
           ':D_BOTTOM=', observer_d, ':TAU_BOTTOM=', observer_tau
    end select

'''
assert probe.count(block)==1; probe=probe.replace(block,'',1)
assert probe==prod
print('FSI21_GATEB_BACKEND_OBSERVER_NORMALIZES_TO_PRODUCTION=PASS')
PY

# Transform the immutable F-VQ28 matrix driver only to print the already-predeclared checkpoint descriptors.
git show "$FVQ28:tests/fvq/test_fvq28_transaction_shape_matrix.f90" > "$BUILD/driver.f90"
python3 - "$BUILD/driver.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
s=s.replace('program test_fvq28_transaction_shape_matrix\n','program test_fsi21_dynamic_local_hydraulics\n',1)
s=s.replace('end program test_fvq28_transaction_shape_matrix\n','end program test_fsi21_dynamic_local_hydraulics\n',1)
a='    real(real64) :: conductivity0\n'
b='    real(real64) :: conductivity0, water0, capacity0, diffusivity0, lbottom, tau0\n'
assert s.count(a)==1; s=s.replace(a,b,1)
a='    call configure_case(parameters, initial_state, forcing, h0, jump, conductivity0)\n'
b='    call configure_case(parameters, initial_state, forcing, h0, jump, conductivity0, water0, capacity0)\n'
assert s.count(a)==1; s=s.replace(a,b,1)
a='    call configure_transaction(config)\n    call fmr_new_b110_committed_state'
b='''    call configure_transaction(config)
    lbottom = parameters%dz(numnod)
    diffusivity0 = conductivity0/capacity0
    tau0 = capacity0*lbottom*lbottom/conductivity0
    write(*,'(A,I0,A,I0,A,I0,10(A,ES26.17E3))') &
         'FSI21B_CHECKPOINT:CASE=', cid, ':STATE=', state_id, ':JUMP_ID=', jump_id, &
         ':H_BOTTOM=', h0, ':H_MIN=', h0, ':H_MAX=', h0, &
         ':THETA_BOTTOM=', water0, ':THETA_MIN=', water0, ':THETA_MAX=', water0, &
         ':K_BOTTOM=', conductivity0, ':C_BOTTOM=', capacity0, ':D_BOTTOM=', diffusivity0, ':TAU_BOTTOM=', tau0
    call fmr_new_b110_committed_state'''
assert s.count(a)==1; s=s.replace(a,b,1)
a='  subroutine configure_case(p, state, forcing, h0, jump, conductivity_reference)\n'
b='  subroutine configure_case(p, state, forcing, h0, jump, conductivity_reference, water_reference, capacity_reference)\n'
assert s.count(a)==1; s=s.replace(a,b,1)
a='    real(real64), intent(out) :: conductivity_reference\n'
b='    real(real64), intent(out) :: conductivity_reference, water_reference, capacity_reference\n'
assert s.count(a)==1; s=s.replace(a,b,1)
a='    conductivity_reference = conductivity(1)\n'
b='''    conductivity_reference = conductivity(1)
    water_reference = water(numnod)
    capacity_reference = capacity(numnod)
'''
assert s.count(a)==1; s=s.replace(a,b,1)
a="  write(*,'(A,I0)') 'FVQ28B_TRANSACTION_SHAPE_DRIVER PASS CASES=', case_id\n"
b="  write(*,'(A,I0)') 'FSI21_DYNAMIC_LOCAL_DRIVER PASS CASES=', case_id\n"
assert s.count(a)==1; s=s.replace(a,b,1)
p.write_text(s)
PY

git show "$FVQ28:integration/f-vq/F-VQ28_GATE_B_EVIDENCE.json" > "$BUILD/fvq28-gateb.json"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULES=(
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

build_run(){
  local opt="$1" tag="$2" out="$BUILD/$tag"
  mkdir -p "$out"
  local objs=()
  for src in "${MODULES[@]}"; do
    local obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objs+=("$obj")
  done
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$BUILD/driver.f90" -o "$out/driver.o"
  gfortran "$opt" "${objs[@]}" "$out/driver.o" -o "$out/test"
  timeout 480s "$out/test" > "$out/run1.txt" 2>&1
  timeout 480s "$out/test" > "$out/run2.txt" 2>&1
  cmp "$out/run1.txt" "$out/run2.txt"
  grep -Fq 'FSI21_DYNAMIC_LOCAL_DRIVER PASS CASES=24' "$out/run1.txt"
  echo "FSI21_GATEB_REPEAT_${tag^^}=PASS"
}
build_run -O0 o0
build_run -O2 o2
cmp "$BUILD/o0/run1.txt" "$BUILD/o2/run1.txt"
echo 'FSI21_GATEB_O0_O2_IDENTITY=PASS'

python3 - "$BUILD/o0/run1.txt" "$BUILD/fvq28-gateb.json" <<'PY'
from pathlib import Path
import json, math, re, sys
lines=Path(sys.argv[1]).read_text().splitlines()
ev=json.load(open(sys.argv[2]))
patterns=[]
for state in ev['resolved_relationship']['by_initial_state']:
    patterns.extend(state['case_patterns'])
assert len(patterns)==24

def fields(line):
    out={}
    for key,val in re.findall(r':([A-Z0-9_]+)=\s*([^:]+)',line):
        out[key]=val.strip()
    return out

cases={}; current=None
for line in lines:
    if line.startswith('FSI21B_CHECKPOINT:'):
        f=fields(line); cid=int(f['CASE'])
        cases[cid]={'checkpoint':{k:float(v) for k,v in f.items() if k not in ('CASE','STATE','JUMP_ID')},
                    'state':int(f['STATE']),'jump_id':int(f['JUMP_ID']),'adv':[]}
    elif line.startswith('FVQ28B_TX_CASE_BEGIN='):
        m=re.match(r'FVQ28B_TX_CASE_BEGIN=(\d+):',line); current=int(m.group(1))
    elif line.startswith('FSI21B_ADVANCE'):
        assert current is not None
        f=fields(line); cases[current]['adv'].append({k:float(v) for k,v in f.items()})
    elif line.startswith('FVQ28B_TX_CASE_END='):
        current=None

assert len(cases)==24
expected_dt=[0.25,0.125,0.0625]
rows=[]
for cid in range(1,25):
    c=cases[cid]; assert len(c['adv'])==9, (cid,len(c['adv']))
    pat=patterns[cid-1]; assert len(pat)==3
    tau0=c['checkpoint']['TAU_BOTTOM']
    for ia,dt in enumerate(expected_dt):
        full,mid,end=c['adv'][3*ia:3*ia+3]
        assert abs(full['DT']-dt)<1e-14
        assert abs(mid['DT']-0.5*dt)<1e-14 and abs(end['DT']-0.5*dt)<1e-14
        # Full and the two-half route terminate at the same attempt endpoint.
        assert abs(full['T1']-end['T1'])<1e-12
        assert abs(mid['T1']-end['T0'])<1e-12
        defect=abs(full['H_BOTTOM']-end['H_BOTTOM'])
        tau_ratio=full['TAU_BOTTOM']/end['TAU_BOTTOM']
        rows.append({
            'case':cid,'state':c['state'],'jump_id':c['jump_id'],'attempt':ia+1,'class':pat[ia],
            'dt':dt,'tau0':tau0,'tau_full':full['TAU_BOTTOM'],'tau_mid':mid['TAU_BOTTOM'],'tau_end':end['TAU_BOTTOM'],
            'tau_full_over_end':tau_ratio,'tau_mid_over_t0':mid['TAU_BOTTOM']/tau0,
            'tau_end_over_t0':end['TAU_BOTTOM']/tau0,'hdef_bottom':defect,
            'hfull_delta':full['H_BOTTOM']-c['checkpoint']['H_BOTTOM'],
            'hend_delta':end['H_BOTTOM']-c['checkpoint']['H_BOTTOM'],
            'd_full':full['D_BOTTOM'],'d_mid':mid['D_BOTTOM'],'d_end':end['D_BOTTOM']
        })

# Descriptive, non-fitted summaries only.
resolved=[r for r in rows if r['class']!='X']
for cls in ('C','U'):
    rr=[r for r in resolved if r['class']==cls]
    print(f'FSI21_GATEB_CLASS_{cls}_COUNT={len(rr)}')
    print(f'FSI21_GATEB_CLASS_{cls}_TAU_FULL_OVER_END_MIN={min(r["tau_full_over_end"] for r in rr):.17e}')
    print(f'FSI21_GATEB_CLASS_{cls}_TAU_FULL_OVER_END_MAX={max(r["tau_full_over_end"] for r in rr):.17e}')
    print(f'FSI21_GATEB_CLASS_{cls}_TAU_END_OVER_T0_MIN={min(r["tau_end_over_t0"] for r in rr):.17e}')
    print(f'FSI21_GATEB_CLASS_{cls}_TAU_END_OVER_T0_MAX={max(r["tau_end_over_t0"] for r in rr):.17e}')

# Exact overlap is a useful falsifier for any simple monotone single-descriptor explanation, without fitting a threshold.
cvals=[r['tau_full_over_end'] for r in resolved if r['class']=='C']
uvals=[r['tau_full_over_end'] for r in resolved if r['class']=='U']
overlap=max(min(cvals),min(uvals)) <= min(max(cvals),max(uvals))
print('FSI21_GATEB_TAU_FULL_OVER_END_CLASS_RANGES_OVERLAP='+('TRUE' if overlap else 'FALSE'))

# Across-jump coherence of dynamic trajectories for each initial state: report spread, do not fit.
for state in range(1,7):
    sr=[r for r in rows if r['state']==state]
    for attempt in range(1,4):
        ar=[r for r in sr if r['attempt']==attempt]
        vals=[r['tau_end_over_t0'] for r in ar]
        spread=max(vals)-min(vals)
        print(f'FSI21_GATEB_STATE={state}:ATTEMPT={attempt}:TAU_END_OVER_T0_SPREAD_ACROSS_JUMPS={spread:.17e}')

# The predeclared h0=-320 UCU counterexample receives an explicit dynamic trace.
for cid in range(21,25):
    cr=[r for r in rows if r['case']==cid]
    print('FSI21_GATEB_UCU_TRACE:CASE=%d:PATTERN=%s:TAU_FULL_END=%s:TAU_END_T0=%s:HDEF_BOTTOM=%s' % (
        cid, ''.join(r['class'] for r in cr),
        ','.join(f'{r["tau_full_over_end"]:.17e}' for r in cr),
        ','.join(f'{r["tau_end_over_t0"]:.17e}' for r in cr),
        ','.join(f'{r["hdef_bottom"]:.17e}' for r in cr)))

print(f'FSI21_GATEB_OBSERVED_CASES={len(cases)}')
print(f'FSI21_GATEB_OBSERVED_ATTEMPTS={len(rows)}')
print(f'FSI21_GATEB_RESOLVED_CLASSIFIED_ATTEMPTS={len(resolved)}')
print('FSI21_GATEB_THRESHOLD_FITTED=NO')
print('FSI21_GATEB_NORMALIZATION_SELECTED=NO')
print('FSI21_GATEB_TOLERANCE_SELECTED=NO')
print('FSI21_GATEB_DYNAMIC_LOCAL_CHARACTERIZATION PASS')
PY

echo 'FSI21_GATEB_PHYSICS_CHANGED=NO'
echo 'FSI21_GATEB_MASS_GATE_RELAXED=NO'
echo 'FSI21_GATEB_RETRY_POLICY_CHANGED=NO'
echo 'FSI21_GATEB_TRANSACTION_SEMANTICS_CHANGED=NO'
echo 'FSI21_DYNAMIC_LOCAL_HYDRAULIC_GATE PASS'
