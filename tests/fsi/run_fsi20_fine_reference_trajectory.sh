#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi20-fine-reference-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FVQ27=1dc8219beda37fbcd6fd4232c964208fa0f17c8f
BACKEND_BLOB=6f39d60a87c1987ae95d7faec2f55f865af90a08
FGC02_BRANCH=origin/work/f-gc02-physical-coupling-seam
FGC02_FIXTURE_BLOB=d8c3863a1acb08eb60712c7dd58bafc4cc5de5a6

fail() { echo "FSI20_FINE_REFERENCE_FAIL $*" >&2; exit 1; }

git diff --quiet "$FVQ27" -- src || {
  echo 'FSI20_FINE_REFERENCE_PRODUCTION_IMMUTABILITY=FAIL' >&2
  git diff --name-only "$FVQ27" -- src >&2
  exit 1
}
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == "$BACKEND_BLOB" ]] || fail 'backend blob drift'
[[ "$(git rev-parse "$FGC02_BRANCH:tests/fgc/test_fgc02_physical_coupling.f90")" == "$FGC02_FIXTURE_BLOB" ]] || fail 'F-GC02 fixture blob drift'
echo 'FSI20_FINE_REFERENCE_PRODUCTION_IMMUTABILITY=PASS'
echo 'FSI20_FINE_REFERENCE_BACKEND_SOURCE_LOCK=PASS'
echo 'FSI20_FINE_REFERENCE_FGC02_PROVENANCE_LOCK=PASS'

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
  src/runtime/mod_fmr_serialized_reference_backend.f90
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
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fsi/test_fsi20_fine_reference_trajectory.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  timeout 180s "$OUT/test" > "$OUT/run1.txt" 2>&1 || { cat "$OUT/run1.txt" >&2; exit 1; }
  grep -Fq 'FSI20_FINE_REFERENCE_TRAJECTORY_DRIVER PASS' "$OUT/run1.txt"
  if [[ "$opt" == 0 ]]; then
    timeout 180s "$OUT/test" > "$OUT/run2.txt" 2>&1 || { cat "$OUT/run2.txt" >&2; exit 1; }
    cmp "$OUT/run1.txt" "$OUT/run2.txt"
    echo 'FSI20_FINE_REFERENCE_REPEAT_DETERMINISM_O0=PASS'
  fi
done
cmp "$BUILD/o0/run1.txt" "$BUILD/o2/run1.txt"
echo 'FSI20_FINE_REFERENCE_O0_O2_IDENTITY=PASS'

python3 - "$BUILD/o0/run1.txt" integration/f-si/F-SI20_CHARACTERIZATION_EVIDENCE.json <<'PY'
from pathlib import Path
import json,math,sys
lines=Path(sys.argv[1]).read_text().splitlines()
ev=json.loads(Path(sys.argv[2]).read_text())
rows={}
nodes={}
for line in lines:
    if line.startswith('FSI20_FINE_REFERENCE_SUMMARY'):
        p=line.split()
        if len(p)!=8: raise SystemExit(f'bad fine-reference summary: {line}')
        dt=float(p[1])
        rows[round(dt,15)]={
            'dt':dt,'eh':float(p[2]),'et':float(p[3]),'es':float(p[4]),
            'rh':float(p[5]),'rt':float(p[6]),'rs':float(p[7])}
    elif line.startswith('FSI20_FINE_REFERENCE_NODE'):
        p=line.split()
        if len(p)!=7: raise SystemExit(f'bad fine-reference node: {line}')
        dt=round(float(p[1]),15)
        nodes.setdefault(dt,[]).append((int(p[2]),float(p[3]),float(p[4]),float(p[5]),float(p[6])))
if len(rows)!=7: raise SystemExit(f'expected 7 summary rows, got {len(rows)}')
if set(rows)!=set(nodes): raise SystemExit('summary/node dt mismatch')
if any(len(v)!=4 for v in nodes.values()): raise SystemExit('expected four node rows per endpoint')
prior={round(float(r['dt_day']),15):r for r in ev['baseline_1e_12_temporal_rows']}
if set(prior)!=set(rows): raise SystemExit('characterization/fine-reference dt mismatch')
print('FSI20_FINE_REFERENCE_FIELD_ORDER=dt,step_doubling_dhead,half_to_ref256_dhead,ref128_to_ref256_dhead,d_over_half_endpoint_error,half_error_over_reference_delta,half_to_ref256_dtheta,ref128_to_ref256_dtheta,signed_half_storage_error,signed_reference_storage_delta')
for key in sorted(rows,reverse=True):
    r=rows[key]; d=prior[key]['max_abs_head_cm']
    values=[d,r['eh'],r['rh'],r['et'],r['rt'],r['es'],r['rs']]
    if not all(math.isfinite(x) for x in values): raise SystemExit('nonfinite fine-reference value')
    d_over_e=d/r['eh'] if r['eh']!=0.0 else math.inf
    e_over_ref=r['eh']/r['rh'] if r['rh']!=0.0 else math.inf
    print('FSI20_FINE_REFERENCE_COMPARE:DT='+f"{r['dt']:.17e}"+
          ':STEP_DOUBLING_DHEAD='+f'{d:.17e}'+
          ':HALF_TO_REF256_DHEAD='+f"{r['eh']:.17e}"+
          ':REF128_TO_REF256_DHEAD='+f"{r['rh']:.17e}"+
          ':D_OVER_HALF_ENDPOINT_ERROR='+f'{d_over_e:.17e}'+
          ':HALF_ERROR_OVER_REFERENCE_DELTA='+f'{e_over_ref:.17e}'+
          ':HALF_TO_REF256_DTHETA='+f"{r['et']:.17e}"+
          ':REF128_TO_REF256_DTHETA='+f"{r['rt']:.17e}"+
          ':SIGNED_HALF_STORAGE_ERROR='+f"{r['es']:.17e}"+
          ':SIGNED_REFERENCE_STORAGE_DELTA='+f"{r['rs']:.17e}")
    for node,dh,dt,drh,drt in nodes[key]:
        print('FSI20_FINE_REFERENCE_NODE_EVIDENCE:DT='+f"{r['dt']:.17e}"+f':NODE={node}'+
              ':HALF_MINUS_REF256_H='+f'{dh:.17e}'+':HALF_MINUS_REF256_THETA='+f'{dt:.17e}'+
              ':REF128_MINUS_REF256_H='+f'{drh:.17e}'+':REF128_MINUS_REF256_THETA='+f'{drt:.17e}')
print('FSI20_FINE_REFERENCE_NODEWISE_PERSISTABLE_OUTPUT=PASS')
print('FSI20_FINE_REFERENCE_NO_ASYMPTOTIC_ASSUMPTION=PASS')
PY

echo 'FSI20_FINE_REFERENCE_TEMPORAL_GATE_BYPASS=NONPRODUCTION_HUGE_TOLERANCE_ONLY'
echo 'FSI20_FINE_REFERENCE_MASS_GATE=UNCHANGED_HARD_1E-12'
echo 'FSI20_FINE_REFERENCE_PRODUCTION_ACCEPTANCE_CHANGED=NO'
echo 'FSI20_FINE_REFERENCE_METRIC_SELECTED=NO'
echo 'FSI20_FINE_REFERENCE_TRAJECTORY PASS'
