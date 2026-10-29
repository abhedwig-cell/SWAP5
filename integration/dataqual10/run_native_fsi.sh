#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD=/tmp/dq10-fsi35-native
BASE=d8414c1ba11bee9f061622fd2495f631a57d2383
SOILWATER=src/legacy/b1_10_port/soilwater.f90
FC="${FC:-gfortran}"
fail(){ echo "DATAQUAL10_FSI35_NATIVE_FAIL $*" >&2; exit 93; }
cp "$BUILD/original-fkt15_stubs.f90" "$BUILD/fkt15_stubs.f90"
# The immutable F-KT15 stub predates the later explicit SWSOPHY import used by
# the M1-C3 profile guard. Add only that interface symbol, with the historical
# analytical default, without changing any oracle calculation.
python3 - "$BUILD/fkt15_stubs.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
needle='module MOD_MvG\n  use MOD_grid, only: numnod\n  implicit none\n'
assert needle in s
if 'integer :: swsophy = 0' not in s:
    s=s.replace(needle,needle+'  integer :: swsophy = 0\n',1)
p.write_text(s)
print('FCI93_M1C3_HISTORICAL_STUB_INTERFACE_SHIM=PASS')
PY

FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
MODULES=(
  "$BUILD/fkt15_stubs.f90"
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_default_mvg_directional_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/solver/mod_surface_evaporation_capacity_contract.f90
  src/solver/mod_b110_surface_evaporation_capacity_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90
  src/runtime/mod_fmr_legacy_bottom_boundary_application_binding.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_reference_richards_accepted_step_directional_service.f90
  src/adapter/mod_b110_production_soil_water_task2.f90
)
# Materialize the exact admitted compile algorithm. Other owners may extend
# the current helper for their own modules; the native oracle still uses the
# immutable algorithm and compiles the exact current 27-dependency closure.
mapfile -t MODULES < <(python3 - "$BASE" "${MODULES[@]}" <<'PY_HELPER'
import subprocess, sys
from pathlib import Path
helper='tests/support/augment_bartholomeus_backend_sources.py'
code=Path('/tmp/dq10-fsi35-native/helper.py').read_text()
sys.argv=[helper,'--all',*sys.argv[2:]]
exec(compile(code,helper,'exec'),{'__file__':str(Path(helper).resolve()),'__name__':'__main__'})
PY_HELPER
)
echo 'FCI93_IMMUTABLE_COMPILE_HELPER_MATERIALIZED=PASS'

run_replay(){
  local opt="$1"
  local tag="$2"
  local out="$BUILD/$tag"
  mkdir -p "$out"; objs=()
  for src in "${MODULES[@]}"; do
    obj="$out/$(basename "${src%.*}").o"
    "$FC" "${FLAGS[@]}" "$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objs+=("$obj")
  done
  "$FC" "${FLAGS[@]}" "$opt" -J "$out" -I "$out" -c "$SOILWATER" -o "$out/soilwater.o"

  "$FC" "${FLAGS[@]}" "$opt" -J "$out" -I "$out" -c "$BUILD/fkt15_task2.f90" -o "$out/task2-test.o"
  "$FC" "${FLAGS[@]}" "$opt" "${objs[@]}" "$out/task2-test.o" -o "$out/task2-test"
  timeout 90s env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$out/task2-test" > "$out/task2.txt"
  for mark in FKT15_ACCEPTED_TYPED_ROUTE=PASS FKT15_ACCEPTED_SENSITIVITY=PASS FKT15_EIGHT_WORKER_CAPSULE_ISOLATION=PASS FKT15_RETRY_FAIL_CLOSED=PASS FKT15_PRODUCTION_TASK2_GATE=PASS; do
    grep -Fq "$mark" "$out/task2.txt" || { cat "$out/task2.txt" >&2; fail "$tag missing $mark"; }
  done

  "$FC" "${FLAGS[@]}" "$opt" -J "$out" -I "$out" -c "$BUILD/fkt15_surface.f90" -o "$out/surface-test.o"
  "$FC" "${FLAGS[@]}" "$opt" "${objs[@]}" "$out/surface-test.o" -o "$out/surface-test"
  timeout 90s env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$out/surface-test" > "$out/surface.txt"
  for mark in FKT15_PRODUCTION_SURFACE_FLUX=PASS FKT15_PRODUCTION_ATMOSPHERIC_HEAD=PASS FKT15_PRODUCTION_PONDED_HEAD=PASS FKT15_PRODUCTION_SURFACE_HARD_MASS=PASS FKT15_PRODUCTION_SURFACE_REGIMES_GATE=PASS; do
    grep -Fq "$mark" "$out/surface.txt" || { cat "$out/surface.txt" >&2; fail "$tag missing $mark"; }
  done

  "$FC" "${FLAGS[@]}" "$opt" -J "$out" -I "$out" -c "$BUILD/fsi35_dispatch.f90" -o "$out/dispatch-test.o"
  "$FC" "${FLAGS[@]}" "$opt" "${objs[@]}" "$out/soilwater.o" "$out/dispatch-test.o" -o "$out/dispatch-test"
  timeout 90s env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$out/dispatch-test" > "$out/dispatch.txt"
  grep -Fq 'FSI35_STANDALONE_WORKER_TASK2_EQUIVALENCE=PASS' "$out/dispatch.txt" || { cat "$out/dispatch.txt" >&2; fail "$tag standalone/worker equivalence"; }
  grep -Fq 'FSI35_STANDALONE_USES_COMMON_SOLVER_SERVICE=PASS' "$out/dispatch.txt" || { cat "$out/dispatch.txt" >&2; fail "$tag common solver service"; }
}

run_replay -O0 o0
run_replay -O2 o2
cmp "$BUILD/o0/task2.txt" "$BUILD/o2/task2.txt" || fail 'Task2 O0/O2 output drift'
cmp "$BUILD/o0/surface.txt" "$BUILD/o2/surface.txt" || fail 'surface O0/O2 output drift'
cmp "$BUILD/o0/dispatch.txt" "$BUILD/o2/dispatch.txt" || fail 'dispatch O0/O2 output drift'
cat "$BUILD/o0/task2.txt" "$BUILD/o0/surface.txt" "$BUILD/o0/dispatch.txt"
echo 'FCI93_FSI35_CURRENT_SEMANTIC_REPLAY=PASS'
echo 'FCI93_FSI35_SUCCESSOR_PRESERVATION=PASS'

echo "FCI93_FIXED_K_NATIVE_IMMUTABLE_ORACLE_O0_O2=PASS"
