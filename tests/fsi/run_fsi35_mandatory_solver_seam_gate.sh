#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-/tmp}/fsi35-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"; mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "FSI35_GATE_FAIL $*" >&2; exit 35; }

SOILWATER=src/legacy/b1_10_port/soilwater.f90
TASK2=src/adapter/mod_b110_production_soil_water_task2.f90
CONTRACT=src/solver/mod_soil_water_solver_contract.f90
REFERENCE_BINDING=src/adapter/mod_reference_richards_legacy_binding.f90
HEADCALC=src/legacy/b1_10_port/headcalc.f90

# Architecture gate: MOD_SoilWater may not know or invoke HeadCalc.
if grep -Eqi '(^|[^[:alnum:]_])headcalc([^[:alnum:]_]|$)' "$SOILWATER"; then
  grep -Ein 'headcalc' "$SOILWATER" >&2 || true
  fail 'MOD_SoilWater still depends on HeadCalc'
fi
grep -Fq 'use mod_b110_production_soil_water_task2, only: run_b110_production_task2' "$SOILWATER" || fail 'Task2 service binding missing'
grep -Fq 'call run_b110_production_task2(worker)' "$SOILWATER" || fail 'worker Task2 does not use service'
grep -Fq 'call run_b110_production_task2()' "$SOILWATER" || fail 'standalone Task2 does not use service'

grep -Fq 'type, abstract, public :: soil_water_solver_t' "$CONTRACT" || fail 'common solver contract missing'
grep -Fq 'class(soil_water_solver_t), intent(inout) :: solver' "$TASK2" || fail 'common dynamic invocation seam missing'
grep -Fq 'type, extends(soil_water_solver_t) :: b110_legacy_compat_solver_t' "$TASK2" || fail 'legacy compatibility path is not behind soil_water_solver_t'
grep -Fq 'call invoke_soil_water_solver(solver, request, workspace, result)' "$TASK2" || fail 'solver service invocation missing'

echo 'FSI35_COMMON_SOLVER_SERVICE_STATIC_GATE=PASS'

# Production-wide direct HeadCalc call classification. Only adapter-boundary
# implementation files may invoke HeadCalc. The HeadCalc definition itself is
# solver-internal and is not a call hit.
mapfile -t CALL_HITS < <(grep -RinE --include='*.f90' 'call[[:space:]]+headcalc[[:space:]]*\(' src || true)
for hit in "${CALL_HITS[@]}"; do
  case "$hit" in
    src/adapter/mod_reference_richards_legacy_binding.f90:*) echo "ADAPTER_BOUNDARY_ALLOWED $hit" ;;
    src/adapter/mod_b110_production_soil_water_task2.f90:*) echo "ADAPTER_BOUNDARY_ALLOWED $hit" ;;
    *) echo "PRODUCTION_INTERFACE_VIOLATION $hit" >&2; fail 'unapproved direct HeadCalc call' ;;
  esac
done
[[ ${#CALL_HITS[@]} -ge 1 ]] || fail 'dependency audit found no adapter HeadCalc implementation call'
echo "SOLVER_INTERNAL_ALLOWED $HEADCALC"
echo 'FSI35_HEADCALC_DEPENDENCY_AUDIT=PASS'

# F-SI31 isolation and process-view source locks must remain untouched by this remediation.
git diff --quiet 267f2a6ec61f78d3ba4ce75b3e5a7fdc08479135..HEAD -- \
  src/solver/mod_soil_water_solver_contract.f90 \
  src/solver/mod_process_hydraulic_view.f90 \
  src/runtime/mod_fmr_serialized_reference_backend.f90 \
  src/runtime/mod_groundwater_predictor_corrector_window.f90 \
  src/transaction/mod_transaction_reference.f90 || fail 'protected contract/runtime/coupling source changed'
echo 'FSI35_RESEARCH_PROCESS_TRANSACTION_COUPLING_PRESERVATION=PASS'

# Reuse the definitive F-KT15 test oracle against the current source postimage.
DONOR=48336cb7f14e9246b03c23e549fe7354a93f9e6b
git cat-file -e "$DONOR^{commit}" 2>/dev/null || git fetch --no-tags origin "$DONOR" >/dev/null 2>&1 || fail 'cannot fetch F-KT15 donor'
mkdir -p tests/fkt
for p in \
  tests/fkt/fkt15_production_task2_stubs.f90 \
  tests/fkt/test_fkt15_production_task2.f90 \
  tests/fkt/test_fkt15_production_surface_regimes.f90; do
  git show "$DONOR:$p" > "$p" || fail "cannot materialize $p"
done

FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
MODULES=(
 tests/fkt/fkt15_production_task2_stubs.f90
 src/runtime/mod_a23bu_worker_execution_context.f90
 src/solver/mod_soil_water_solver_contract.f90
 src/solver/mod_reference_linear_solver.f90
 src/solver/mod_reference_richards_workspace.f90
 src/solver/mod_reference_richards_state_binding.f90
 src/solver/mod_b110_default_mvg_provider.f90
 src/solver/mod_b110_source_sink_provider.f90
 src/solver/mod_fixed_flux_top_boundary_provider.f90
 src/solver/mod_reference_richards_temporal_indicator.f90
 src/solver/mod_surface_evaporation_capacity_contract.f90
 src/solver/mod_b110_surface_evaporation_capacity_provider.f90
 src/process/mod_restricted_surface_evaporation.f90
 src/solver/mod_b110_dynamic_top_boundary_provider.f90
 src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
 src/legacy/b1_10_port/headcalc.f90
 src/adapter/mod_reference_richards_legacy_binding.f90
 src/adapter/mod_b110_production_soil_water_task2.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objs=()
  for src in "${MODULES[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${FLAGS[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c "$src" -o "$obj"
    objs+=("$obj")
  done
  gfortran "${FLAGS[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c "$SOILWATER" -o "$OUT/soilwater.o"

  gfortran "${FLAGS[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c tests/fkt/test_fkt15_production_task2.f90 -o "$OUT/task2-test.o"
  gfortran "${FLAGS[@]}" -O"$opt" "${objs[@]}" "$OUT/task2-test.o" -o "$OUT/task2-test"
  timeout 90s env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$OUT/task2-test" > "$OUT/task2.txt"
  for mark in \
    FKT15_ACCEPTED_TYPED_ROUTE=PASS \
    FKT15_ACCEPTED_SENSITIVITY=PASS \
    FKT15_SINGLE_HYDRAULIC_AUTHORITY=PASS \
    FKT15_UNSUPPORTED_DIRECT_FALLBACK_SEAM=PASS \
    FKT15_STALE_SENSITIVITY_CLEAR=PASS \
    FKT15_EIGHT_WORKER_CAPSULE_ISOLATION=PASS \
    FKT15_RETRY_FAIL_CLOSED=PASS \
    FKT15_PRODUCTION_TASK2_GATE=PASS; do
    grep -Fq "$mark" "$OUT/task2.txt" || { cat "$OUT/task2.txt" >&2; fail "O$opt missing $mark"; }
  done

  gfortran "${FLAGS[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c tests/fkt/test_fkt15_production_surface_regimes.f90 -o "$OUT/surface-test.o"
  gfortran "${FLAGS[@]}" -O"$opt" "${objs[@]}" "$OUT/surface-test.o" -o "$OUT/surface-test"
  timeout 90s env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$OUT/surface-test" > "$OUT/surface.txt"
  for mark in \
    FKT15_PRODUCTION_SURFACE_FLUX=PASS \
    FKT15_PRODUCTION_ATMOSPHERIC_HEAD=PASS \
    FKT15_PRODUCTION_PONDED_HEAD=PASS \
    FKT15_PRODUCTION_LINEAR_RUNOFF=PASS \
    FKT15_PRODUCTION_SURFACE_METADATA_IDENTITY=PASS \
    FKT15_PRODUCTION_SURFACE_HARD_MASS=PASS \
    FKT15_PRODUCTION_FLUX_ONLY_TANGENT_SCOPE=PASS \
    FKT15_PRODUCTION_SURFACE_REGIMES_GATE=PASS; do
    grep -Fq "$mark" "$OUT/surface.txt" || { cat "$OUT/surface.txt" >&2; fail "surface O$opt missing $mark"; }
  done
  echo "FSI35_FULL_RICHARDS_SERVICE_O${opt}=PASS"
done
cmp "$BUILD/o0/task2.txt" "$BUILD/o2/task2.txt" || fail 'Task2 O0/O2 output differs'
cmp "$BUILD/o0/surface.txt" "$BUILD/o2/surface.txt" || fail 'surface O0/O2 output differs'
echo 'FSI35_FULL_RICHARDS_O0_O2_IDENTITY=PASS'

echo 'FSI35_MANDATORY_SOLVER_SEAM_GATE=PASS'
