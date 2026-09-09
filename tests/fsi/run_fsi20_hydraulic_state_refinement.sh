#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi20-state-refine-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FVQ27=1dc8219beda37fbcd6fd4232c964208fa0f17c8f
BACKEND_BLOB=6f39d60a87c1987ae95d7faec2f55f865af90a08
FGC02_BRANCH=origin/work/f-gc02-physical-coupling-seam
FGC02_FIXTURE=tests/fgc/test_fgc02_physical_coupling.f90
FGC02_FIXTURE_BLOB=d8c3863a1acb08eb60712c7dd58bafc4cc5de5a6
STUB_BLOB=23c00e4a188e88bc36ef95cbe4faaacdd6aad639
FSI18_BRANCH=origin/work/f-si18-reference-convergence-cliff
FSI18_GENERATOR_BLOB=bf25c4c7fefaa59811255b0bc25c041522ab008e
FSI18_REFERENCE_EVIDENCE_BLOB=bf433c7adff71ce9d10463d53a55a92fe4599655

fail() { echo "FSI20_STATE_REFINE_FAIL $*" >&2; exit 1; }

git diff --quiet "$FVQ27" -- src || fail 'production source drift from F-VQ27'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == "$BACKEND_BLOB" ]] || fail 'backend blob drift'
[[ "$(git rev-parse "$FGC02_BRANCH:$FGC02_FIXTURE")" == "$FGC02_FIXTURE_BLOB" ]] || fail 'F-GC02 fixture drift'
[[ "$(git rev-parse HEAD:tests/fsi/fsi04_real_headcalc_stubs.f90)" == "$STUB_BLOB" ]] || fail 'local zero-correction stub drift'
[[ "$(git rev-parse "$FSI18_BRANCH:tests/fsi/fsi18_make_reference_tridag_stubs.py")" == "$FSI18_GENERATOR_BLOB" ]] || fail 'F-SI18 reference generator drift'
[[ "$(git rev-parse "$FSI18_BRANCH:integration/f-si/F-SI18_REFERENCE_TRIDAG_EVIDENCE.json")" == "$FSI18_REFERENCE_EVIDENCE_BLOB" ]] || fail 'F-SI18 reference evidence drift'
grep -Fq 'real(real64), parameter :: initial_heads(nh) = [-25.0_real64, -75.0_real64, -250.0_real64]' tests/fsi/test_fsi20_hydraulic_state_refinement.f90
grep -Fq 'real(real64), parameter :: head_jump = 0.01_real64' tests/fsi/test_fsi20_hydraulic_state_refinement.f90
grep -Fq 'integer, parameter :: nsteps(nlevels) = [1,2,4,8,16,32,64,128,256,512]' tests/fsi/test_fsi20_hydraulic_state_refinement.f90
grep -Fq 'request%numerical%max_iterations = 8' tests/fsi/test_fsi20_hydraulic_state_refinement.f90
grep -Fq 'request%numerical%max_backtracking = 4' tests/fsi/test_fsi20_hydraulic_state_refinement.f90
grep -Fq 'request%numerical%min_step_duration = 1.0e-6_real64' tests/fsi/test_fsi20_hydraulic_state_refinement.f90
echo 'FSI20_STATE_REFINE_SOURCE_LOCK=PASS'
echo 'FSI20_STATE_REFINE_EXACT_FGC02_SOLVER_CONTROLS=PASS'

git show "$FSI18_BRANCH:tests/fsi/fsi18_make_reference_tridag_stubs.py" > "$BUILD/make_reference_tridag.py"
python3 "$BUILD/make_reference_tridag.py" tests/fsi/fsi04_real_headcalc_stubs.f90 "$BUILD/fsi04_reference_tridag_stubs.f90"
if grep -Fq 'solution(i) = 0.0d0' "$BUILD/fsi04_reference_tridag_stubs.f90"; then fail 'zero-correction TRIDAG survived replacement'; fi
grep -Fq 'SWAP 4.3.1 tridag.f90' "$BUILD/fsi04_reference_tridag_stubs.f90" || fail 'reference TRIDAG marker missing'
echo 'FSI20_STATE_REFINE_REFERENCE_TRIDAG_CONTROL=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
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

build_and_run() {
  local opt="$1" tag="$2"
  local out="$BUILD/$tag"
  mkdir -p "$out"
  local objects=()
  for src in "${MODULE_SRC[@]}"; do
    local obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c tests/fsi/test_fsi20_hydraulic_state_refinement.f90 -o "$out/test.o"
  gfortran "$opt" "${objects[@]}" "$out/test.o" -o "$out/test"
  timeout 240s "$out/test" > "$out/run1.txt" 2>&1 || { cat "$out/run1.txt" >&2; exit 1; }
  timeout 240s "$out/test" > "$out/run2.txt" 2>&1 || { cat "$out/run2.txt" >&2; exit 1; }
  cmp "$out/run1.txt" "$out/run2.txt"
  grep -Fq 'FSI20_HYDRAULIC_STATE_REFINEMENT_DRIVER PASS' "$out/run1.txt"
  echo "FSI20_STATE_REFINE_REPEAT_${tag}=PASS"
}

build_and_run -O0 o0
build_and_run -O2 o2
cmp "$BUILD/o0/run1.txt" "$BUILD/o2/run1.txt"
echo 'FSI20_STATE_REFINE_O0_O2_IDENTITY=PASS'
cat "$BUILD/o0/run1.txt"

python3 - "$BUILD/o0/run1.txt" <<'PY'
from pathlib import Path
import math,re,sys
lines=Path(sys.argv[1]).read_text().splitlines()
states={}
endpoints=[]
compares=[]
for line in lines:
    if line.startswith('FSI20_STATE_REFINE_STATE='):
        m=re.match(r'FSI20_STATE_REFINE_STATE=(\d+):H0=\s*([^:]+):HBOT=\s*([^:]+):K0=\s*(\S+)',line)
        if not m: raise SystemExit('bad state row: '+line)
        states[int(m.group(1))]={'h0':float(m.group(2)),'hbot':float(m.group(3)),'k0':float(m.group(4))}
    elif line.startswith('FSI20_STATE_REFINE_ENDPOINT:'):
        m=re.match(r'FSI20_STATE_REFINE_ENDPOINT:STATE=(\d+):N=(\d+):MAX_MASS=\s*([^:]+):MAX_SOLVER_RES=\s*(\S+)',line)
        if not m: raise SystemExit('bad endpoint row: '+line)
        endpoints.append({'state':int(m.group(1)),'n':int(m.group(2)),'mass':float(m.group(3)),'solver':float(m.group(4))})
    elif line.startswith('FSI20_STATE_REFINE_COMPARE:'):
        m=re.match(r'FSI20_STATE_REFINE_COMPARE:STATE=(\d+):N=(\d+):N2=(\d+):DHEAD=\s*([^:]+):DTHETA=\s*([^:]+):EHEAD_N2_REF=\s*([^:]+):ETHETA_N2_REF=\s*([^:]+):DHEAD_OVER_E2=\s*([^:]+):SIGNED_STORAGE_N2_REF=\s*(\S+)',line)
        if not m: raise SystemExit('bad compare row: '+line)
        compares.append({'state':int(m.group(1)),'n':int(m.group(2)),'n2':int(m.group(3)),
                         'dhead':float(m.group(4)),'dtheta':float(m.group(5)),'e2h':float(m.group(6)),
                         'e2t':float(m.group(7)),'ratio':float(m.group(8)),'storage':float(m.group(9))})
if len(states)!=3 or len(endpoints)!=30 or len(compares)!=27:
    raise SystemExit(f'unexpected counts states={len(states)} endpoints={len(endpoints)} compares={len(compares)}')
if max(r['mass'] for r in endpoints)>1e-12: raise SystemExit('hard mass gate exceeded')
print('FSI20_STATE_REFINE_ALL_TRAJECTORIES_MASS_HARD=PASS')
base=[r for r in compares if r['state']==2 and r['n']==1]
if len(base)!=1: raise SystemExit('missing original F-GC02 fixed-horizon row')
expected=2.55242948426825933e-4
if abs(base[0]['dhead']-expected)>5e-15*max(1.0,abs(expected)):
    raise SystemExit('original F-GC02 DHEAD drift')
print('FSI20_STATE_REFINE_EXACT_FGC02_DHEAD_LOCK=PASS')

for sid in (1,2,3):
    rr=sorted((r for r in compares if r['state']==sid),key=lambda r:r['n'])
    usable=[r for r in rr if r['e2h']>0.0 and r['n2']<512]
    d=[r['dhead'] for r in rr]
    monotone=all(d[i+1] < d[i] for i in range(len(d)-1))
    first_cons=None
    for i,r in enumerate(usable):
        tail=usable[i:]
        if r['ratio']>=1.0 and all(x['ratio']>=1.0 for x in tail):
            first_cons=r['n']; break
    print(f"FSI20_STATE_REFINE_SUMMARY:STATE={sid}:H0={states[sid]['h0']:.17e}:DHEAD_N1={rr[0]['dhead']:.17e}:DHEAD_N2={rr[1]['dhead']:.17e}:DHEAD_N4={rr[2]['dhead']:.17e}:DHEAD_N128={next(r for r in rr if r['n']==128)['dhead']:.17e}:STRICTLY_MONOTONE={str(monotone).upper()}:FIRST_PERSISTENT_CONSERVATIVE_N={first_cons if first_cons is not None else 'NONE'}")
    for r in usable:
        print(f"FSI20_STATE_REFINE_RATIO:STATE={sid}:N={r['n']}:DHEAD={r['dhead']:.17e}:E2={r['e2h']:.17e}:RATIO={r['ratio']:.17e}")
print('FSI20_STATE_REFINE_RAW_HEADNORM_ONLY=PASS')
print('FSI20_STATE_REFINE_NORMALIZATION_SELECTED=NO')
print('FSI20_STATE_REFINE_PRODUCTION_TOLERANCE_SELECTED=NO')
PY

git diff --quiet "$FVQ27" -- src || fail 'production source changed during state refinement'
echo 'FSI20_STATE_REFINE_PRODUCTION_SOURCE_UNCHANGED=PASS'
echo 'FSI20_HYDRAULIC_STATE_REFINEMENT PASS'
