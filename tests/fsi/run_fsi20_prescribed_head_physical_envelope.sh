#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi20-envelope-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FVQ27=1dc8219beda37fbcd6fd4232c964208fa0f17c8f
BACKEND_BLOB=6f39d60a87c1987ae95d7faec2f55f865af90a08
FGC02_BRANCH=origin/work/f-gc02-physical-coupling-seam
FGC02_FIXTURE=tests/fgc/test_fgc02_physical_coupling.f90
FGC02_FIXTURE_BLOB=d8c3863a1acb08eb60712c7dd58bafc4cc5de5a6

fail() { echo "FSI20_ENVELOPE_FAIL $*" >&2; exit 1; }

git diff --quiet "$FVQ27" -- src || fail 'production source drift from F-VQ27'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == "$BACKEND_BLOB" ]] || fail 'backend blob drift'
[[ "$(git rev-parse "$FGC02_BRANCH:$FGC02_FIXTURE")" == "$FGC02_FIXTURE_BLOB" ]] || fail 'F-GC02 fixture drift'
grep -Fq 'real(real64), parameter :: initial_heads(nh) = [-25.0_real64, -75.0_real64, -250.0_real64]' tests/fsi/test_fsi20_prescribed_head_physical_envelope.f90
grep -Fq 'real(real64), parameter :: head_jumps(nd) = [-0.1_real64, -0.01_real64, 0.001_real64, 0.01_real64, 0.1_real64]' tests/fsi/test_fsi20_prescribed_head_physical_envelope.f90
grep -Fq 'integer, parameter :: nh = 3, nd = 5, nref = 128' tests/fsi/test_fsi20_prescribed_head_physical_envelope.f90
grep -Fq 'request%numerical%max_iterations = 8' tests/fsi/test_fsi20_prescribed_head_physical_envelope.f90
grep -Fq 'request%numerical%max_backtracking = 4' tests/fsi/test_fsi20_prescribed_head_physical_envelope.f90
grep -Fq 'request%numerical%min_step_duration = 1.0e-6_real64' tests/fsi/test_fsi20_prescribed_head_physical_envelope.f90
grep -Fq 'request%numerical%compartment_balance_tolerance = hard_mass_gate' tests/fsi/test_fsi20_prescribed_head_physical_envelope.f90
echo 'FSI20_ENVELOPE_SOURCE_LOCK=PASS'
echo 'FSI20_ENVELOPE_EXACT_FGC02_SOLVER_AND_MASS_CONTROLS=PASS'

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
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c tests/fsi/test_fsi20_prescribed_head_physical_envelope.f90 -o "$out/test.o"
  gfortran "$opt" "${objects[@]}" "$out/test.o" -o "$out/test"
  timeout 180s "$out/test" > "$out/run1.txt" 2>&1 || { cat "$out/run1.txt" >&2; exit 1; }
  timeout 180s "$out/test" > "$out/run2.txt" 2>&1 || { cat "$out/run2.txt" >&2; exit 1; }
  cmp "$out/run1.txt" "$out/run2.txt"
  grep -Fq 'FSI20_PRESCRIBED_HEAD_PHYSICAL_ENVELOPE_DRIVER PASS' "$out/run1.txt"
  echo "FSI20_ENVELOPE_REPEAT_${tag}=PASS"
}

build_and_run -O0 o0
build_and_run -O2 o2
cmp "$BUILD/o0/run1.txt" "$BUILD/o2/run1.txt"
echo 'FSI20_ENVELOPE_O0_O2_IDENTITY=PASS'
cat "$BUILD/o0/run1.txt"

python3 - "$BUILD/o0/run1.txt" <<'PY'
from pathlib import Path
import math,re,sys
rows=[]
pat=re.compile(
 r'FSI20_ENVELOPE_CASE=(\d+):H0=\s*([^:]+):JUMP=\s*([^:]+):HBOT=\s*([^:]+)'
 r':DHEAD=\s*([^:]+):DTHETA=\s*([^:]+):EHEAD_N1_REF=\s*([^:]+):EHEAD_N2_REF=\s*([^:]+)'
 r':ETHETA_N1_REF=\s*([^:]+):ETHETA_N2_REF=\s*([^:]+):DHEAD_OVER_E2=\s*([^:]+)'
 r':SIGNED_STORAGE_N2_REF=\s*([^:]+):MAX_MASS=\s*([^:]+):MAX_SOLVER_RES=\s*(\S+)')
for line in Path(sys.argv[1]).read_text().splitlines():
    if not line.startswith('FSI20_ENVELOPE_CASE='): continue
    m=pat.match(line)
    if not m: raise SystemExit('bad envelope row: '+line)
    vals=[float(m.group(i)) for i in range(2,15)]
    if not all(math.isfinite(v) for v in vals): raise SystemExit('nonfinite envelope metric')
    rows.append({'case':int(m.group(1)),'h0':vals[0],'jump':vals[1],'hbot':vals[2],
                 'dhead':vals[3],'dtheta':vals[4],'e1h':vals[5],'e2h':vals[6],
                 'e1t':vals[7],'e2t':vals[8],'ratio':vals[9],'storage':vals[10],
                 'mass':vals[11],'solver':vals[12]})
if len(rows)!=15: raise SystemExit(f'expected 15 envelope rows, got {len(rows)}')
if max(r['mass'] for r in rows) > 1e-12: raise SystemExit('hard mass gate exceeded')
print('FSI20_ENVELOPE_ALL_15_CASES_CONVERGED_MASS_HARD=PASS')

# Exact original +0.01 cm / -75 cm probe must remain represented and source-consistent.
base=[r for r in rows if abs(r['h0']+75.0)<1e-12 and abs(r['jump']-0.01)<1e-12]
if len(base)!=1: raise SystemExit('missing exact F-GC02 envelope row')
expected=2.55242948426825933e-4
if abs(base[0]['dhead']-expected) > 5e-15*max(1.0,abs(expected)):
    raise SystemExit(f'FGC02 DHEAD drift {base[0]["dhead"]:.17e}')
print('FSI20_ENVELOPE_EXACT_FGC02_DHEAD_LOCK=PASS')

ratios=[r['ratio'] for r in rows]
print(f'FSI20_ENVELOPE_DHEAD_MIN={min(r["dhead"] for r in rows):.17e}')
print(f'FSI20_ENVELOPE_DHEAD_MAX={max(r["dhead"] for r in rows):.17e}')
print(f'FSI20_ENVELOPE_E2_MIN={min(r["e2h"] for r in rows):.17e}')
print(f'FSI20_ENVELOPE_E2_MAX={max(r["e2h"] for r in rows):.17e}')
print(f'FSI20_ENVELOPE_DHEAD_OVER_E2_MIN={min(ratios):.17e}')
print(f'FSI20_ENVELOPE_DHEAD_OVER_E2_MAX={max(ratios):.17e}')

for h0 in (-25.0,-75.0,-250.0):
    rr=[r for r in rows if abs(r['h0']-h0)<1e-12]
    print(f'FSI20_ENVELOPE_H0={h0:.1f}:DHEAD_MIN={min(r["dhead"] for r in rr):.17e}:DHEAD_MAX={max(r["dhead"] for r in rr):.17e}:RATIO_MIN={min(r["ratio"] for r in rr):.17e}:RATIO_MAX={max(r["ratio"] for r in rr):.17e}')

# Raw dimensional characterization only. No normalization or production threshold is admitted here.
print('FSI20_ENVELOPE_RAW_DIMENSIONAL_CHARACTERIZATION_ONLY=PASS')
print('FSI20_ENVELOPE_NORMALIZATION_SELECTED=NO')
print('FSI20_ENVELOPE_PRODUCTION_TOLERANCE_SELECTED=NO')
PY

echo 'FSI20_PRESCRIBED_HEAD_PHYSICAL_ENVELOPE PASS'
