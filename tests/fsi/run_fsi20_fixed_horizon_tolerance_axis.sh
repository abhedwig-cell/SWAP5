#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi20-tolaxis-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FVQ27=1dc8219beda37fbcd6fd4232c964208fa0f17c8f
BACKEND_BLOB=6f39d60a87c1987ae95d7faec2f55f865af90a08
FGC02_BRANCH=origin/work/f-gc02-physical-coupling-seam
FGC02_FIXTURE=tests/fgc/test_fgc02_physical_coupling.f90
FGC02_FIXTURE_BLOB=d8c3863a1acb08eb60712c7dd58bafc4cc5de5a6

git diff --quiet "$FVQ27" -- src || { echo 'FSI20_TOLAXIS_PRODUCTION_IMMUTABILITY=FAIL'; exit 1; }
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == "$BACKEND_BLOB" ]]
[[ "$(git rev-parse "$FGC02_BRANCH:$FGC02_FIXTURE")" == "$FGC02_FIXTURE_BLOB" ]]
grep -Fq 'real(real64), parameter :: tolerances(ntol) = [1.0e-12_real64, 1.0e-13_real64, 1.0e-14_real64]' tests/fsi/test_fsi20_fixed_horizon_tolerance_axis.f90
grep -Fq 'request%numerical%min_step_duration = 1.0e-6_real64' tests/fsi/test_fsi20_fixed_horizon_tolerance_axis.f90
grep -Fq 'request%numerical%compartment_balance_tolerance = hard_mass_gate' tests/fsi/test_fsi20_fixed_horizon_tolerance_axis.f90
echo 'FSI20_TOLAXIS_SOURCE_LOCK=PASS'
echo 'FSI20_TOLAXIS_FGC02_PHYSICS_AND_MASS_LOCK=PASS'

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
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c tests/fsi/test_fsi20_fixed_horizon_tolerance_axis.f90 -o "$out/test.o"
  gfortran "$opt" "${objects[@]}" "$out/test.o" -o "$out/test"
  timeout 240s "$out/test" > "$out/run1.txt"
  timeout 240s "$out/test" > "$out/run2.txt"
  cmp "$out/run1.txt" "$out/run2.txt"
  grep -Fq 'FSI20_FIXED_HORIZON_TOLERANCE_AXIS_DRIVER PASS' "$out/run1.txt"
  echo "FSI20_TOLAXIS_REPEAT_${tag}=PASS"
}

build_and_run -O0 o0
build_and_run -O2 o2
cmp "$BUILD/o0/run1.txt" "$BUILD/o2/run1.txt"
echo 'FSI20_TOLAXIS_O0_O2_IDENTITY=PASS'
cat "$BUILD/o0/run1.txt"

python3 - "$BUILD/o0/run1.txt" <<'PY'
from pathlib import Path
import math,re,sys
lines=Path(sys.argv[1]).read_text().splitlines()
endpoints={}
compares={}
cross={}
for line in lines:
    if line.startswith('FSI20_TOLAXIS_ENDPOINT:'):
        m=re.match(r'FSI20_TOLAXIS_ENDPOINT:TOL_INDEX=(\d+):HEAD_TOL=\s*([^:]+):N=(\d+):MAX_MASS_RESIDUAL=\s*([^:]+):MAX_SOLVER_RESIDUAL=\s*(\S+)',line)
        if not m: raise SystemExit('bad endpoint row: '+line)
        key=(int(m.group(1)),int(m.group(3)))
        endpoints[key]=(float(m.group(2)),float(m.group(4)),float(m.group(5)))
    elif line.startswith('FSI20_TOLAXIS_COMPARE:'):
        m=re.match(r'FSI20_TOLAXIS_COMPARE:TOL_INDEX=(\d+):HEAD_TOL=\s*([^:]+):N=(\d+):N2=(\d+):DHEAD=\s*([^:]+):DTHETA=\s*(\S+)',line)
        if not m: raise SystemExit('bad compare row: '+line)
        key=(int(m.group(1)),int(m.group(3)))
        compares[key]=(float(m.group(2)),int(m.group(4)),float(m.group(5)),float(m.group(6)))
    elif line.startswith('FSI20_TOLAXIS_CROSS:'):
        m=re.match(r'FSI20_TOLAXIS_CROSS:TOL_INDEX=(\d+):HEAD_TOL=\s*([^:]+):N=(\d+):DHEAD_BASE_TO_STRICT=\s*([^:]+):DTHETA_BASE_TO_STRICT=\s*(\S+)',line)
        if not m: raise SystemExit('bad cross row: '+line)
        key=(int(m.group(1)),int(m.group(3)))
        cross[key]=(float(m.group(2)),float(m.group(4)),float(m.group(5)))
expected_n=[1,2,4,8,16,32,64,128,256,512,1024]
if len(endpoints)!=33: raise SystemExit(f'expected 33 endpoint rows, got {len(endpoints)}')
if len(compares)!=30: raise SystemExit(f'expected 30 compare rows, got {len(compares)}')
if len(cross)!=22: raise SystemExit(f'expected 22 cross rows, got {len(cross)}')
if max(v[1] for v in endpoints.values()) > 1e-12: raise SystemExit('hard mass gate exceeded')
print('FSI20_TOLAXIS_ALL_TRAJECTORIES_MASS_HARD=PASS')

baseline_outer=compares[(1,1)][2]
expected_outer=2.55242948426825933e-4
if abs(baseline_outer-expected_outer) > 5e-15*max(1.0,abs(expected_outer)):
    raise SystemExit(f'baseline outer step-doubling drift: {baseline_outer:.17e}')
print('FSI20_TOLAXIS_BASELINE_OUTER_DHEAD_LOCK=PASS')

max_cross_h=0.0; max_cross_t=0.0
for (_,n),(tol,dh,dt) in cross.items():
    max_cross_h=max(max_cross_h,dh); max_cross_t=max(max_cross_t,dt)
print(f'FSI20_TOLAXIS_MAX_ENDPOINT_DHEAD_BASE_TO_STRICT={max_cross_h:.17e}')
print(f'FSI20_TOLAXIS_MAX_ENDPOINT_DTHETA_BASE_TO_STRICT={max_cross_t:.17e}')

for n in expected_n[:-1]:
    base=compares[(1,n)][2]
    vals=[compares[(i,n)][2] for i in (1,2,3)]
    spread=max(vals)-min(vals)
    rel=spread/max(abs(base),1e-300)
    print('FSI20_TOLAXIS_DHEAD_SENSITIVITY:N='+str(n)+':VALUES='+','.join(f'{v:.17e}' for v in vals)+f':ABS_SPREAD={spread:.17e}:REL_SPREAD={rel:.17e}')

max_rel=max((max(compares[(i,n)][2] for i in (1,2,3))-min(compares[(i,n)][2] for i in (1,2,3)))/max(abs(compares[(1,n)][2]),1e-300) for n in expected_n[:-1])
print(f'FSI20_TOLAXIS_MAX_STEP_DOUBLING_REL_SPREAD={max_rel:.17e}')
print('FSI20_TOLAXIS_CHARACTERIZATION_ONLY=PASS')
print('FSI20_TOLAXIS_PRODUCTION_METRIC_SELECTED=NO')
PY

echo 'FSI20_FIXED_HORIZON_TOLERANCE_AXIS PASS'
