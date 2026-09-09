#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq28-heldout-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=99f57db11ba30ffbc8b2bd44936b212f66cced9d
FVQ27=1dc8219beda37fbcd6fd4232c964208fa0f17c8f
BACKEND_BLOB=6f39d60a87c1987ae95d7faec2f55f865af90a08
FGC02_BRANCH=origin/work/f-gc02-physical-coupling-seam
FGC02_FIXTURE=tests/fgc/test_fgc02_physical_coupling.f90
FGC02_FIXTURE_BLOB=d8c3863a1acb08eb60712c7dd58bafc4cc5de5a6
STUB_BLOB=23c00e4a188e88bc36ef95cbe4faaacdd6aad639
FSI18_BRANCH=origin/work/f-si18-reference-convergence-cliff
FSI18_GENERATOR_BLOB=bf25c4c7fefaa59811255b0bc25c041522ab008e
FSI18_REFERENCE_EVIDENCE_BLOB=bf433c7adff71ce9d10463d53a55a92fe4599655

fail() { echo "FVQ28_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$BASE" HEAD || fail 'F-VQ28 base is not an ancestor'
git diff --quiet "$FVQ27" -- src || fail 'production source drift from F-VQ27'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == "$BACKEND_BLOB" ]] || fail 'serialized backend blob drift'
[[ "$(git rev-parse "$FGC02_BRANCH:$FGC02_FIXTURE")" == "$FGC02_FIXTURE_BLOB" ]] || fail 'F-GC02 fixture drift'
[[ "$(git rev-parse HEAD:tests/fsi/fsi04_real_headcalc_stubs.f90)" == "$STUB_BLOB" ]] || fail 'local zero-correction stub drift'
[[ "$(git rev-parse "$FSI18_BRANCH:tests/fsi/fsi18_make_reference_tridag_stubs.py")" == "$FSI18_GENERATOR_BLOB" ]] || fail 'F-SI18 reference generator drift'
[[ "$(git rev-parse "$FSI18_BRANCH:integration/f-si/F-SI18_REFERENCE_TRIDAG_EVIDENCE.json")" == "$FSI18_REFERENCE_EVIDENCE_BLOB" ]] || fail 'F-SI18 reference evidence drift'

grep -Fq 'initial_heads(nh) = [' tests/fvq/test_fvq28_heldout_temporal_profile.f90
grep -Fq -- '-40.0_real64, -55.0_real64, -110.0_real64, -160.0_real64, -210.0_real64, -320.0_real64' tests/fvq/test_fvq28_heldout_temporal_profile.f90
grep -Fq 'head_jumps(nj) = [ -0.05_real64, -0.01_real64, 0.01_real64, 0.05_real64 ]' tests/fvq/test_fvq28_heldout_temporal_profile.f90
grep -Fq 'integer, parameter :: nsteps(nlevels) = [1,2,4,8,16,32,64,128,256,512]' tests/fvq/test_fvq28_heldout_temporal_profile.f90
grep -Fq 'request%numerical%max_iterations = 8' tests/fvq/test_fvq28_heldout_temporal_profile.f90
grep -Fq 'request%numerical%max_backtracking = 4' tests/fvq/test_fvq28_heldout_temporal_profile.f90
grep -Fq 'request%numerical%min_step_duration = 1.0e-6_real64' tests/fvq/test_fvq28_heldout_temporal_profile.f90
grep -Fq 'request%numerical%compartment_balance_tolerance = hard_mass_gate' tests/fvq/test_fvq28_heldout_temporal_profile.f90

echo 'FVQ28_SOURCE_LOCK=PASS'
echo 'FVQ28_FROZEN_HELDOUT_MATRIX=PASS'
echo 'FVQ28_EXACT_SOLVER_AND_MASS_CONTROLS=PASS'

git show "$FSI18_BRANCH:tests/fsi/fsi18_make_reference_tridag_stubs.py" > "$BUILD/make_reference_tridag.py"
python3 "$BUILD/make_reference_tridag.py" tests/fsi/fsi04_real_headcalc_stubs.f90 "$BUILD/fsi04_reference_tridag_stubs.f90"
if grep -Fq 'solution(i) = 0.0d0' "$BUILD/fsi04_reference_tridag_stubs.f90"; then fail 'zero-correction TRIDAG survived replacement'; fi
grep -Fq 'SWAP 4.3.1 tridag.f90' "$BUILD/fsi04_reference_tridag_stubs.f90" || fail 'reference TRIDAG marker missing'
echo 'FVQ28_REFERENCE_TRIDAG_CONTROL=PASS'

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
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c tests/fvq/test_fvq28_heldout_temporal_profile.f90 -o "$out/test.o"
  gfortran "$opt" "${objects[@]}" "$out/test.o" -o "$out/test"
  timeout 480s "$out/test" > "$out/run1.txt" 2>&1 || { cat "$out/run1.txt" >&2; exit 1; }
  timeout 480s "$out/test" > "$out/run2.txt" 2>&1 || { cat "$out/run2.txt" >&2; exit 1; }
  cmp "$out/run1.txt" "$out/run2.txt"
  grep -Fq 'FVQ28_HELDOUT_TEMPORAL_PROFILE_DRIVER PASS CASES=24' "$out/run1.txt"
  echo "FVQ28_REPEAT_${tag}=PASS"
}

build_and_run -O0 o0
build_and_run -O2 o2
cmp "$BUILD/o0/run1.txt" "$BUILD/o2/run1.txt"
echo 'FVQ28_O0_O2_IDENTITY=PASS'
cat "$BUILD/o0/run1.txt"

python3 - "$BUILD/o0/run1.txt" <<'PY'
from pathlib import Path
import re,sys
lines=Path(sys.argv[1]).read_text().splitlines()
cases={}
endpoints=[]
compares=[]
for line in lines:
    if line.startswith('FVQ28_CASE='):
        m=re.match(r'FVQ28_CASE=(\d+):STATE=(\d+):JUMP_ID=(\d+):H0=\s*([^:]+):JUMP=\s*([^:]+):HBOT=\s*([^:]+):K0=\s*(\S+)',line)
        if not m: raise SystemExit('bad case row: '+line)
        cases[int(m.group(1))]={'state':int(m.group(2)),'jump_id':int(m.group(3)),'h0':float(m.group(4)),
                                'jump':float(m.group(5)),'hbot':float(m.group(6)),'k0':float(m.group(7))}
    elif line.startswith('FVQ28_ENDPOINT:'):
        m=re.match(r'FVQ28_ENDPOINT:CASE=(\d+):N=(\d+):MAX_MASS=\s*([^:]+):MAX_SOLVER_RES=\s*([^:]+):MAX_NITER=(\d+):MAX_NBACK=(\d+)',line)
        if not m: raise SystemExit('bad endpoint row: '+line)
        endpoints.append({'case':int(m.group(1)),'n':int(m.group(2)),'mass':float(m.group(3)),'solver':float(m.group(4)),
                          'niter':int(m.group(5)),'nback':int(m.group(6))})
    elif line.startswith('FVQ28_COMPARE:'):
        m=re.match(r'FVQ28_COMPARE:CASE=(\d+):N=(\d+):N2=(\d+):DHEAD=\s*([^:]+):DTHETA=\s*([^:]+):EHEAD_N2_REF=\s*([^:]+):ETHETA_N2_REF=\s*([^:]+):DHEAD_OVER_E2=\s*([^:]+):SIGNED_STORAGE_N2_REF=\s*(\S+)',line)
        if not m: raise SystemExit('bad compare row: '+line)
        compares.append({'case':int(m.group(1)),'n':int(m.group(2)),'n2':int(m.group(3)),
                         'dhead':float(m.group(4)),'dtheta':float(m.group(5)),'e2h':float(m.group(6)),
                         'e2t':float(m.group(7)),'ratio':float(m.group(8)),'storage':float(m.group(9))})
if len(cases)!=24 or len(endpoints)!=240 or len(compares)!=216:
    raise SystemExit(f'unexpected counts cases={len(cases)} endpoints={len(endpoints)} compares={len(compares)}')
max_mass=max(r['mass'] for r in endpoints)
if max_mass>1e-12: raise SystemExit(f'hard mass gate exceeded: {max_mass}')
print(f'FVQ28_ALL_24_CASES_MASS_HARD=PASS:MAX_MASS={max_mass:.17e}')
print(f"FVQ28_SOLVER_COST_MAX_NITER={max(r['niter'] for r in endpoints)}:MAX_NBACK={max(r['nback'] for r in endpoints)}")

entries={}
monotone={}
for cid in sorted(cases):
    rr=sorted((r for r in compares if r['case']==cid),key=lambda r:r['n'])
    resolved=[r for r in rr if r['n2']<512 and r['dhead']>1e-12 and r['e2h']>1e-12]
    monotone[cid]=all(resolved[i+1]['dhead'] <= resolved[i]['dhead'] for i in range(len(resolved)-1))
    entry=None
    for i,r in enumerate(resolved):
        if r['ratio']>=1.0 and all(x['ratio']>=1.0 for x in resolved[i:]):
            entry=r['n']; break
    entries[cid]=entry
    c=cases[cid]
    r1=rr[0]
    print(f"FVQ28_CASE_SUMMARY:CASE={cid}:STATE={c['state']}:JUMP_ID={c['jump_id']}:H0={c['h0']:.17e}:JUMP={c['jump']:.17e}:K0={c['k0']:.17e}:DHEAD_N1={r1['dhead']:.17e}:RATIO_N1={r1['ratio']:.17e}:RESOLVED_LEVELS={len(resolved)}:MONOTONE={str(monotone[cid]).upper()}:PERSISTENT_CONSERVATIVE_ENTRY_N={entry if entry is not None else 'NONE'}")

missing=[cid for cid,e in entries.items() if e is None]
if missing:
    print('FVQ28_BOUNDED_PROFILE_CANDIDATE=NO:MISSING_CASES='+','.join(map(str,missing)))
else:
    print(f'FVQ28_BOUNDED_PROFILE_CANDIDATE=YES:MAX_ENTRY_N={max(entries.values())}')

for state in range(1,7):
    cids=[cid for cid,c in cases.items() if c['state']==state]
    es=[entries[cid] for cid in cids if entries[cid] is not None]
    h0=cases[cids[0]]['h0']
    if len(es)==len(cids):
        print(f'FVQ28_STATE_ENTRY_RANGE:STATE={state}:H0={h0:.17e}:MIN_N={min(es)}:MAX_N={max(es)}')
    else:
        print(f'FVQ28_STATE_ENTRY_RANGE:STATE={state}:H0={h0:.17e}:MIN_N=NA:MAX_N=NA:MISSING={len(cids)-len(es)}')
print('FVQ28_PRODUCTION_TOLERANCE_SELECTED=NO')
print('FVQ28_NORMALIZATION_SELECTED=NO')
print('FVQ28_RETRY_POLICY_CHANGED=NO')
PY

git diff --quiet "$FVQ27" -- src || fail 'production source changed during F-VQ28'
echo 'FVQ28_PRODUCTION_SOURCE_UNCHANGED=PASS'
echo 'FVQ28_HELDOUT_GATE_A PASS'
