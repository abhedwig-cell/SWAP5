#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-/tmp}/ftab02-f0-${GITHUB_RUN_ID:-local}-$$"
rm -rf "$BUILD"; mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_TAB02_F0_GATE_FAIL $*" >&2; exit 1; }

# Freeze the existing standalone/worker dispatch authorities as qualification
# fixtures; the F0 production delta does not rewrite them.
FKT15_DONOR=48336cb7f14e9246b03c23e549fe7354a93f9e6b
FSI35_DONOR=5898e6616dbb6871a9f52d489038235ba1172cae
git cat-file -e "$FKT15_DONOR^{commit}" || fail "missing F-KT15 donor"
git cat-file -e "$FSI35_DONOR^{commit}" || fail "missing F-SI35 donor"
git show "$FKT15_DONOR:tests/fkt/fkt15_production_task2_stubs.f90" > "$BUILD/stubs.f90"
git show "$FSI35_DONOR:tests/fsi/test_fsi35_task2_dispatch_equivalence.f90" > "$BUILD/fsi35-test.f90"
python3 - "$BUILD/stubs.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
needle="module MOD_MvG\n  use MOD_grid, only: numnod\n  implicit none\n"
assert needle in s
s=s.replace(needle,needle+"  integer :: swsophy = 0\n",1)
p.write_text(s)
print("F_TAB02_F0_HISTORICAL_STUB_SHIM=PASS")
PY

python3 - <<'PY'
from pathlib import Path
task=Path("src/adapter/mod_b110_production_soil_water_task2.f90").read_text().lower()
assert "standalone_generated_mvg_opt_in = .false." in task
assert "call execute_b110_production_task2(worker, .false.)" in task
assert "call execute_b110_production_task2(standalone_worker, standalone_generated_mvg_opt_in)" in task
assert "standalone_generated_mvg_state%matches(parameters)" in task
assert "request%evaluation%constitutive => generated_constitutive" in task
assert "request%evaluation%constitutive => constitutive" in task
for path in [
    "src/runtime/mod_a23bu_worker_execution_context.f90",
    "src/transaction/mod_transaction_reference.f90",
    "src/kernel/mod_kernel_transactions.f90",
]:
    text=Path(path).read_text().lower()
    assert "b110_generated_mvg_table_state_t" not in text, path
    assert "standalone_generated_mvg_state" not in text, path
print("F_TAB02_F0_EXPLICIT_STANDALONE_OPTIN_STATIC=PASS")
print("F_TAB02_F0_WORKER_MULTISWAP_SELECTION_UNCHANGED_STATIC=PASS")
print("F_TAB02_F0_NO_TRANSACTION_PHYSICAL_STATE_OWNERSHIP=PASS")
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
MODULES=(
  "$BUILD/stubs.f90"
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_generated_mvg_tspack.f90
  src/solver/mod_b110_generated_mvg_table_state.f90
  src/solver/mod_b110_generated_mvg_provider.f90
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

compile_suite(){
  local opt="$1" tag="$2"
  local out="$BUILD/$tag"; mkdir -p "$out"
  local objs=()
  for src in "${MODULES[@]}"; do
    local obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$src" -o "$obj" || fail "$tag compile $src"
    objs+=("$obj")
  done

  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c     tests/fsi/test_ftab02f0_standalone_generated_selection.f90 -o "$out/f0-test.o" || fail "$tag f0 test compile"
  gfortran -fopenmp "$opt" "${objs[@]}" "$out/f0-test.o" -o "$out/f0-test" || fail "$tag f0 link"
  env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$out/f0-test" > "$out/f0-positive.txt" 2>&1 || {
    cat "$out/f0-positive.txt" >&2; fail "$tag f0 positive runtime";
  }
  for marker in     F_TAB02_F0_DEFAULT_ANALYTICAL_NO_GENERATION=PASS     F_TAB02_F0_WORKER_PATH_ANALYTICAL=PASS     F_TAB02_F0_EXACT_HUPSEL_GENERATED_BIND=PASS     F_TAB02_F0_SINGLE_GENERATION_REUSE=PASS     F_TAB02_F0_EXACT_PARAMETER_INVALIDATION_REBUILD=PASS     F_TAB02_F0_RESET_RELEASES_NUMERICAL_STATE=PASS     "F-TAB02-F0 STANDALONE SELECTION LIFETIME GATE PASS"; do
      grep -Fq "$marker" "$out/f0-positive.txt" || { cat "$out/f0-positive.txt" >&2; fail "$tag missing $marker"; }
  done

  set +e
  env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$out/f0-test" neighbor-negative > "$out/f0-negative.txt" 2>&1
  local rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || fail "$tag neighbor unexpectedly accepted"
  grep -Fq 'F-TAB02-F0: standalone generated state unavailable' "$out/f0-negative.txt" || {
    cat "$out/f0-negative.txt" >&2; fail "$tag neighbor did not fail at generated-state seam";
  }
  echo "F_TAB02_F0_UNSUPPORTED_NEIGHBOR_FAIL_CLOSED=PASS" >> "$out/f0-positive.txt"

  # Replay the existing F-SI35 standalone/worker identity on the default path.
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/legacy/b1_10_port/soilwater.f90 -o "$out/soilwater.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$BUILD/fsi35-test.f90" -o "$out/fsi35-test.o"
  gfortran -fopenmp "$opt" "${objs[@]}" "$out/soilwater.o" "$out/fsi35-test.o" -o "$out/fsi35-test"
  env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$out/fsi35-test" > "$out/fsi35.txt"
  grep -Fq 'FSI35_STANDALONE_WORKER_TASK2_EQUIVALENCE=PASS' "$out/fsi35.txt" || fail "$tag FSI35 identity"
  grep -Fq 'FSI35_STANDALONE_USES_COMMON_SOLVER_SERVICE=PASS' "$out/fsi35.txt" || fail "$tag FSI35 common service"
}

compile_suite -O0 o0
compile_suite -O2 o2

cmp -s "$BUILD/o0/f0-positive.txt" "$BUILD/o2/f0-positive.txt" || {
  diff -u "$BUILD/o0/f0-positive.txt" "$BUILD/o2/f0-positive.txt" >&2 || true
  fail "F0 O0/O2 marker/output drift"
}
cmp -s "$BUILD/o0/fsi35.txt" "$BUILD/o2/fsi35.txt" || fail "FSI35 O0/O2 drift"

cat "$BUILD/o0/f0-positive.txt"
cat "$BUILD/o0/fsi35.txt"
echo 'F_TAB02_F0_O0_O2_OUTPUT_IDENTITY=PASS'
echo 'F_TAB02_F0_FSI35_DEFAULT_PRESERVATION=PASS'
echo 'F-TAB02-F0 OWNER QUALIFICATION PASS'
