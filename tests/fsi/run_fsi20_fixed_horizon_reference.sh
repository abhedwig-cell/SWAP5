#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi20-fixed-reference-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FVQ27=1dc8219beda37fbcd6fd4232c964208fa0f17c8f
BACKEND_BLOB=6f39d60a87c1987ae95d7faec2f55f865af90a08
FGC02_BRANCH=origin/work/f-gc02-physical-coupling-seam
FGC02_FIXTURE=tests/fgc/test_fgc02_physical_coupling.f90
FGC02_FIXTURE_BLOB=d8c3863a1acb08eb60712c7dd58bafc4cc5de5a6

git diff --quiet "$FVQ27" -- src || { echo 'FSI20_FIXED_PRODUCTION_IMMUTABILITY=FAIL'; exit 1; }
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == "$BACKEND_BLOB" ]]
[[ "$(git rev-parse "$FGC02_BRANCH:$FGC02_FIXTURE")" == "$FGC02_FIXTURE_BLOB" ]]
grep -Fq 'request%numerical%max_iterations = 8' tests/fsi/test_fsi20_fixed_horizon_reference.f90
grep -Fq 'request%numerical%max_backtracking = 4' tests/fsi/test_fsi20_fixed_horizon_reference.f90
grep -Fq 'request%numerical%min_step_duration = 1.0e-6_real64' tests/fsi/test_fsi20_fixed_horizon_reference.f90
grep -Fq 'request%numerical%head_rel_tolerance = 1.0e-12_real64' tests/fsi/test_fsi20_fixed_horizon_reference.f90
echo 'FSI20_FIXED_SOURCE_LOCK=PASS'
echo 'FSI20_FIXED_FGC02_NUMERICAL_CONTROLS=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
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
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c tests/fsi/test_fsi20_fixed_horizon_reference.f90 -o "$out/test.o"
  gfortran "$opt" "${objects[@]}" "$out/test.o" -o "$out/test"
  timeout 180s "$out/test" > "$out/run1.txt"
  timeout 180s "$out/test" > "$out/run2.txt"
  cmp "$out/run1.txt" "$out/run2.txt"
  grep -Fq 'FSI20_FIXED_HORIZON_REFERENCE_DRIVER PASS' "$out/run1.txt"
  echo "FSI20_FIXED_REPEAT_${tag}=PASS"
}

build_and_run -O0 o0
build_and_run -O2 o2
cmp "$BUILD/o0/run1.txt" "$BUILD/o2/run1.txt"
echo 'FSI20_FIXED_O0_O2_IDENTITY=PASS'

cat "$BUILD/o0/run1.txt"
python3 - "$BUILD/o0/run1.txt" <<'PY'
from pathlib import Path
import math,re,sys
lines=Path(sys.argv[1]).read_text().splitlines()
endpoints=[]
comparisons=[]
for line in lines:
    if line.startswith('FSI20_FIXED_ENDPOINT:'):
        m=re.match(r'FSI20_FIXED_ENDPOINT:N=(\d+):SUB_DT=\s*([^:]+):MAX_MASS_RESIDUAL=\s*([^:]+):MAX_SOLVER_RESIDUAL=\s*(\S+)',line)
        if not m: raise SystemExit('bad endpoint row: '+line)
        endpoints.append((int(m.group(1)),float(m.group(2)),float(m.group(3)),float(m.group(4))))
    if line.startswith('FSI20_FIXED_COMPARE:'):
        m=re.match(r'FSI20_FIXED_COMPARE:N=(\d+):N2=(\d+):DHEAD_N_N2=\s*([^:]+):DTHETA_N_N2=\s*([^:]+):EHEAD_N_REF=\s*([^:]+):ETHETA_N_REF=\s*([^:]+):EHEAD_N2_REF=\s*([^:]+):ETHETA_N2_REF=\s*([^:]+):SIGNED_STORAGE_N_REF=\s*(\S+)',line)
        if not m: raise SystemExit('bad compare row: '+line)
        comparisons.append((int(m.group(1)),int(m.group(2)),*(float(m.group(i)) for i in range(3,10))))
if len(endpoints)!=11: raise SystemExit(f'expected 11 endpoint rows, got {len(endpoints)}')
if len(comparisons)!=10: raise SystemExit(f'expected 10 comparison rows, got {len(comparisons)}')
if max(x[2] for x in endpoints)>1e-12: raise SystemExit('hard mass gate exceeded')
print('FSI20_FIXED_MASS_HARD_ALL_TRAJECTORIES=PASS')
for i,row in enumerate(comparisons):
    n,n2,dhead,dtheta,ehead,etheta,ehead2,etheta2,storage=row
    ratio=ehead2/dhead if dhead>0 else float('nan')
    p_d=float('nan')
    if i+1<len(comparisons) and comparisons[i+1][2]>0 and dhead>0:
        p_d=math.log(dhead/comparisons[i+1][2],2)
    p_e=float('nan')
    if ehead2>0 and ehead>0:
        p_e=math.log(ehead/ehead2,2)
    print(f'FSI20_FIXED_DIAGNOSTIC:N={n}:N2={n2}:DHEAD={dhead:.17e}:EHEAD_N_REF={ehead:.17e}:EHEAD_N2_REF={ehead2:.17e}:E2_OVER_D={ratio:.17e}:P_D={p_d:.17e}:P_E={p_e:.17e}:STORAGE={storage:.17e}')
print(f'FSI20_FIXED_REFERENCE_TAIL_DHEAD_512_1024={comparisons[-1][2]:.17e}')
print(f'FSI20_FIXED_REFERENCE_TAIL_DTHETA_512_1024={comparisons[-1][3]:.17e}')
print('FSI20_FIXED_HORIZON_CHARACTERIZATION_ONLY=PASS')
print('FSI20_FIXED_PRODUCTION_METRIC_SELECTED=NO')
PY

echo 'FSI20_FIXED_HORIZON_REFERENCE_GATE PASS'
