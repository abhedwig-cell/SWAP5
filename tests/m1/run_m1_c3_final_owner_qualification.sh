#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
fail(){ echo "M1_C3_OWNER_FAIL $*" >&2; exit 1; }

BASE="$(git merge-base HEAD origin/integration/f-ci-canonical)"
expected=$'src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90\nsrc/adapter/mod_b110_production_soil_water_task2.f90\nsrc/solver/mod_b110_dynamic_top_boundary_provider.f90'
actual="$(git diff --name-only "$BASE" -- src | sort)"
[[ "$actual" == "$expected" ]] || { printf '%s\n' "$actual" >&2; fail "unexpected production delta"; }
echo 'M1_C3_BOUNDED_PRODUCTION_DELTA=PASS'

python3 - <<'PY'
from pathlib import Path
import re
provider=Path('src/solver/mod_b110_dynamic_top_boundary_provider.f90').read_text()
adapter=Path('src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90').read_text()
task2=Path('src/adapter/mod_b110_production_soil_water_task2.f90').read_text()
required_provider=[
 'fixed_top_node_conductivity_cm_per_day = -1.0_real64',
 'if (request%fixed_top_node_conductivity_cm_per_day >= 0.0_real64) then',
 'k_top = request%fixed_top_node_conductivity_cm_per_day',
]
required_adapter=[
 'real(real64) :: fixed_top_node_conductivity = -1.0_real64',
 'optional :: fixed_top_node_conductivity',
 'b110_request%fixed_top_node_conductivity_cm_per_day = self%fixed_top_node_conductivity',
]
required_task2=[
 'm1_b111_legacy_application_profile_active',
 'enable_ksatexm_extension=m1_profile',
 'bind_b110_root_sink_provider(root_sink, root_copy)',
 'fmr_resolve_legacy_bottom_boundary(swbotb, legacy_bottom, bottom_status)',
 'fixed_top_node_conductivity=k(1)',
 'swbotb == 6',
 'swkimpl == 0',
]
for needle in required_provider:
    assert needle in provider, needle
for needle in required_adapter:
    assert needle in adapter, needle
for needle in required_task2:
    assert needle in task2, needle
for p,text in [
 ('src/solver/mod_b110_dynamic_top_boundary_provider.f90',provider),
 ('src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90',adapter),
]:
    assert not re.search(r'(?im)^\s*(open|read|write|inquire)\s*\(', text), p
    assert not re.search(r'(?i)pathname|file_unit|parser', text), p
assert 'call HeadCalc' not in task2 and 'call headcalc' not in task2.lower()
print('M1_C3_STATIC_OPTIN_CARRIER=PASS')
print('M1_C3_SOLVER_CONTRACT_NO_FILE_IO=PASS')
print('M1_C3_NO_DUPLICATE_HEADCALC=PASS')
PY

BUILD="${RUNNER_TEMP:-/tmp}/m1-c3-owner-${GITHUB_RUN_ID:-local}-$$"
rm -rf "$BUILD"; mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
COMMON=(-std=f2008 -pedantic-errors -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

# Direct carrier and F-SI39 preservation tests at O0/O2.
for opt in 0 2; do
  OUT="$BUILD/unit-o$opt"; mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -Wno-error=unused-dummy-argument -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_soil_water_solver_contract.f90 -o "$OUT/contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_b110_default_mvg_provider.f90 -o "$OUT/mvg.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_restricted_surface_evaporation.f90 -o "$OUT/evap.o"
  gfortran "${COMMON[@]}" -Wno-error=compare-reals -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_b110_dynamic_top_boundary_provider.f90 -o "$OUT/top.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/m1/test_m1_c3_fixed_top_conductivity.f90 -o "$OUT/fixed.o"
  gfortran -O"$opt" "$OUT/contract.o" "$OUT/mvg.o" "$OUT/evap.o" "$OUT/top.o" "$OUT/fixed.o" -o "$OUT/fixed"
  "$OUT/fixed" > "$OUT/fixed.txt"
  for m in M1_C3_FIXED_TOP_DEFAULT_DYNAMIC=PASS M1_C3_FIXED_TOP_OVERRIDE_STABLE=PASS M1_C3_FIXED_TOP_ORIGIN_IDENTITY=PASS; do
    grep -Fq "$m" "$OUT/fixed.txt" || fail "missing $m O$opt"
  done

  gfortran "${COMMON[@]}" -Wno-error=compare-reals -O"$opt" -J "$OUT" -I "$OUT" -c tests/fsi/test_fsi39_b110_ksatexm.f90 -o "$OUT/fsi39.o"
  gfortran -O"$opt" "$OUT/contract.o" "$OUT/mvg.o" "$OUT/fsi39.o" -o "$OUT/fsi39"
  "$OUT/fsi39" > "$OUT/fsi39.txt"
  grep -Fq 'F_SI39_DEFAULT_DISABLED_PRESERVATION=PASS' "$OUT/fsi39.txt" || fail "F-SI39 default O$opt"
  grep -Fq 'F_SI39_HUPSEL_NEAR_SATURATED_INTERPOLATION=PASS' "$OUT/fsi39.txt" || fail "F-SI39 optin O$opt"
done
cmp -s "$BUILD/unit-o0/fixed.txt" "$BUILD/unit-o2/fixed.txt" || fail 'fixed top O0/O2 drift'
cmp -s "$BUILD/unit-o0/fsi39.txt" "$BUILD/unit-o2/fsi39.txt" || fail 'F-SI39 O0/O2 drift'
cat "$BUILD/unit-o0/fixed.txt"
cat "$BUILD/unit-o0/fsi39.txt"
echo 'M1_C3_UNIT_DEFAULT_PRESERVATION=PASS'

# Replay immutable F-KT15/F-SI35 semantic oracles against the candidate postimage.
FKT15_DONOR=48336cb7f14e9246b03c23e549fe7354a93f9e6b
OWNER_SOURCE=5898e6616dbb6871a9f52d489038235ba1172cae
for object in "$FKT15_DONOR" "$OWNER_SOURCE"; do
  git cat-file -e "$object^{commit}" 2>/dev/null || fail "missing historical oracle $object"
done
git show "$FKT15_DONOR:tests/fkt/fkt15_production_task2_stubs.f90" > "$BUILD/stubs.f90"
git show "$FKT15_DONOR:tests/fkt/test_fkt15_production_task2.f90" > "$BUILD/task2-test.f90"
git show "$FKT15_DONOR:tests/fkt/test_fkt15_production_surface_regimes.f90" > "$BUILD/surface-test.f90"
git show "$OWNER_SOURCE:tests/fsi/test_fsi35_task2_dispatch_equivalence.f90" > "$BUILD/dispatch-test.f90"
python3 - "$BUILD/stubs.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
needle='module MOD_MvG\n  use MOD_grid, only: numnod\n  implicit none\n'
assert needle in s
s=s.replace(needle, needle+'  integer :: swsophy = 0\n',1)
p.write_text(s)
print('M1_C3_HISTORICAL_STUB_INTERFACE_SHIM=PASS')
PY

FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
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
SOILWATER=src/legacy/b1_10_port/soilwater.f90

run_replay(){
  local opt="$1" tag="$2" out="$BUILD/$tag"; mkdir -p "$out"; local objs=()
  for src in "${MODULES[@]}"; do
    local obj="$out/$(basename "${src%.*}").o"
    gfortran "${FLAGS[@]}" "$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objs+=("$obj")
  done
  gfortran "${FLAGS[@]}" "$opt" -J "$out" -I "$out" -c "$SOILWATER" -o "$out/soilwater.o"
  gfortran "${FLAGS[@]}" "$opt" -J "$out" -I "$out" -c "$BUILD/task2-test.f90" -o "$out/task2-test.o"
  gfortran "${FLAGS[@]}" "$opt" "${objs[@]}" "$out/task2-test.o" -o "$out/task2-test"
  timeout 90s env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$out/task2-test" > "$out/task2.txt"
  for m in FKT15_ACCEPTED_TYPED_ROUTE=PASS FKT15_ACCEPTED_SENSITIVITY=PASS FKT15_EIGHT_WORKER_CAPSULE_ISOLATION=PASS FKT15_RETRY_FAIL_CLOSED=PASS FKT15_PRODUCTION_TASK2_GATE=PASS; do
    grep -Fq "$m" "$out/task2.txt" || { cat "$out/task2.txt" >&2; fail "$tag missing $m"; }
  done

  gfortran "${FLAGS[@]}" "$opt" -J "$out" -I "$out" -c "$BUILD/surface-test.f90" -o "$out/surface-test.o"
  gfortran "${FLAGS[@]}" "$opt" "${objs[@]}" "$out/surface-test.o" -o "$out/surface-test"
  timeout 90s env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$out/surface-test" > "$out/surface.txt"
  for m in FKT15_PRODUCTION_SURFACE_FLUX=PASS FKT15_PRODUCTION_ATMOSPHERIC_HEAD=PASS FKT15_PRODUCTION_PONDED_HEAD=PASS FKT15_PRODUCTION_SURFACE_HARD_MASS=PASS FKT15_PRODUCTION_SURFACE_REGIMES_GATE=PASS; do
    grep -Fq "$m" "$out/surface.txt" || { cat "$out/surface.txt" >&2; fail "$tag missing $m"; }
  done

  gfortran "${FLAGS[@]}" "$opt" -J "$out" -I "$out" -c "$BUILD/dispatch-test.f90" -o "$out/dispatch-test.o"
  gfortran "${FLAGS[@]}" "$opt" "${objs[@]}" "$out/soilwater.o" "$out/dispatch-test.o" -o "$out/dispatch-test"
  timeout 90s env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$out/dispatch-test" > "$out/dispatch.txt"
  grep -Fq 'FSI35_STANDALONE_WORKER_TASK2_EQUIVALENCE=PASS' "$out/dispatch.txt" || fail "$tag dispatch equivalence"
  grep -Fq 'FSI35_STANDALONE_USES_COMMON_SOLVER_SERVICE=PASS' "$out/dispatch.txt" || fail "$tag common service"
}
run_replay -O0 replay-o0
run_replay -O2 replay-o2
cmp -s "$BUILD/replay-o0/task2.txt" "$BUILD/replay-o2/task2.txt" || fail 'Task2 replay O0/O2 drift'
cmp -s "$BUILD/replay-o0/surface.txt" "$BUILD/replay-o2/surface.txt" || fail 'surface replay O0/O2 drift'
cmp -s "$BUILD/replay-o0/dispatch.txt" "$BUILD/replay-o2/dispatch.txt" || fail 'dispatch replay O0/O2 drift'
echo 'M1_C3_FSI35_FKT15_SEMANTIC_REPLAY=PASS'
echo 'M1_C3_OWNER_QUALIFICATION=PASS'
