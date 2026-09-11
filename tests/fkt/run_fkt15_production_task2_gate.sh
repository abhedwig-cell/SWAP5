#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-/tmp}/fkt15-task2-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

fail() { echo "FKT15_RUNNER_FAIL $*" >&2; exit 1; }
BASE=1b3d8ba6cc70d74a124f20f01f0c47a102763ae0
CANONICAL=4f62af04df8ad686a8066f6c164cdcf79d319999

if git remote get-url origin >/dev/null 2>&1; then
  live="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
  [[ "$live" == "$CANONICAL" ]] || fail "canonical moved: $live"
fi

git merge-base --is-ancestor "$BASE" HEAD || fail 'F-KT15R closeout is not an ancestor'

mapfile -t prod < <(git diff --name-only "$BASE"..HEAD -- 'src/**' | sort)
expected=(
  src/adapter/mod_b110_production_soil_water_task2.f90
  src/adapter/mod_b1_10_reference_model.f90
  src/legacy/b1_10_port/soilwater.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
)
[[ "${prod[*]}" == "${expected[*]}" ]] || {
  printf 'actual production delta:\n%s\n' "${prod[*]}" >&2
  printf 'expected production delta:\n%s\n' "${expected[*]}" >&2
  fail 'unexpected production source delta'
}
if git diff --name-only "$BASE"..HEAD | grep -q '^reference/'; then
  fail 'reference tree changed'
fi

declare -A locks=(
 [src/solver/mod_soil_water_solver_contract.f90]=276941d76ba951a89c43899e61fd0532418d8230
 [src/solver/mod_reference_richards_state_binding.f90]=a2488ce3a6a6eff665a59d3dd68907d26f8304ec
 [src/adapter/mod_reference_richards_legacy_binding.f90]=03a64b6d09fd804242bcf76f7cb5277f59a6230a
 [src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90]=7a3cc3d01d994ea21bb0b48798cd2fb4aba9495e
 [src/legacy/b1_10_port/headcalc.f90]=3ff8d5cfd6963dfb7dafb33ec454fbc0df938a55
 [src/adapter/mod_soil_water_transaction_result_bridge.f90]=ba7547ec4c39f61c4724ed146e2b1ba9daf4baba
 [src/solver/mod_fixed_flux_top_boundary_provider.f90]=fb226f133bd48d8ab945f111c76897aeff49facf
)
for path in "${!locks[@]}"; do
  [[ "$(git hash-object "$path")" == "${locks[$path]}" ]] || fail "owner source drift: $path"
done

grep -Fq 'call SoilWaterStateVar(1)' src/legacy/b1_10_port/soilwater.f90 || fail 'step-start state save missing'
grep -Fq 'call try_b110_production_task2(worker, typed_task2_handled)' src/legacy/b1_10_port/soilwater.f90 || fail 'typed task2 callsite missing'
grep -Fq 'if (.not. typed_task2_handled) then' src/legacy/b1_10_port/soilwater.f90 || fail 'direct fallback guard missing'
grep -Fq 'call headcalc(worker, history=worker%history)' src/legacy/b1_10_port/soilwater.f90 || fail 'direct HeadCalc fallback missing'
[[ "$(grep -c 'call try_b110_production_task2' src/legacy/b1_10_port/soilwater.f90)" == 1 ]] || fail 'typed task2 must occur exactly once'
grep -Fq 'call map_soil_water_interface_sensitivity_to_trial' src/adapter/mod_b1_10_reference_model.f90 || fail 'F-KT14 mapper not used'
grep -Fq 'call a23bu_reset_soil_water_trial_result(worker)' src/adapter/mod_b110_production_soil_water_task2.f90 || fail 'trial result reset missing'
grep -Fq 'sensitivity_route_admitted = swbotb == 2' src/adapter/mod_b110_production_soil_water_task2.f90 || fail 'bottom sensitivity gate missing'
grep -Fq 'initial_surface%regime == SW_TOP_BOUNDARY_REGIME_FLUX' src/adapter/mod_b110_production_soil_water_task2.f90 || fail 'initial smooth-flux sensitivity gate missing'
grep -Fq 'accepted_surface%regime == SW_TOP_BOUNDARY_REGIME_FLUX' src/adapter/mod_b110_production_soil_water_task2.f90 || fail 'accepted smooth-flux sensitivity gate missing'
grep -Fq "trim(accepted_surface%route) == 'surface-flux'" src/adapter/mod_b110_production_soil_water_task2.f90 || fail 'accepted surface-flux route gate missing'
grep -Fq "error stop 'F-KT15: admitted typed soil-water solve failed closed'" src/adapter/mod_b110_production_soil_water_task2.f90 || fail 'post-admission failure must fail closed'
echo 'FKT15_SOURCE_GUARD=PASS'

FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
SOURCES=(
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
  tests/fkt/test_fkt15_production_task2.f90
)

for opt in 0 2; do
  out="$BUILD/o$opt"
  mkdir -p "$out"
  objects=()
  for src in "${SOURCES[@]}"; do
    [[ -f "$src" ]] || fail "missing compile dependency $src"
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${FLAGS[@]}" -O"$opt" -J"$out" -I"$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  # Compile the actual legacy callsite against the production adapter. It is kept
  # out of the focused executable link because this gate tests the adapter itself,
  # but this catches module/interface drift in SoilWater(2).
  gfortran "${FLAGS[@]}" -O"$opt" -J"$out" -I"$out" -c \
    src/legacy/b1_10_port/soilwater.f90 -o "$out/soilwater_callsite.o"
  echo "FKT15_SOILWATER_TASK2_CALLSITE_COMPILE_O${opt}=PASS"

  gfortran "${FLAGS[@]}" -O"$opt" "${objects[@]}" -o "$out/test_fkt15"
  if ! timeout 90s env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$out/test_fkt15" > "$out/output.txt"; then
    cat "$out/output.txt" || true
    fail "O${opt} execution failed"
  fi
  for marker in \
    FKT15_ACCEPTED_TYPED_ROUTE=PASS \
    FKT15_ACCEPTED_SENSITIVITY=PASS \
    FKT15_SINGLE_HYDRAULIC_AUTHORITY=PASS \
    FKT15_UNSUPPORTED_DIRECT_FALLBACK_SEAM=PASS \
    FKT15_STALE_SENSITIVITY_CLEAR=PASS \
    FKT15_EIGHT_WORKER_CAPSULE_ISOLATION=PASS \
    FKT15_RETRY_FAIL_CLOSED=PASS \
    FKT15_PRODUCTION_TASK2_GATE=PASS; do
    grep -Fq "$marker" "$out/output.txt" || fail "O${opt} missing $marker"
  done
  cat "$out/output.txt"
  echo "FKT15_TASK2_O${opt}=PASS"
done
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || fail 'O0/O2 observable output differs'
echo 'FKT15_TASK2_O0_O2_IDENTITY=PASS'
echo 'FKT15_PRODUCTION_TASK2_RUNNER=PASS'
