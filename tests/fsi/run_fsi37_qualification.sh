#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi37-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FSI37_QUALIFICATION_FAIL $*" >&2; exit 1; }

# Governing production/reference sources must remain the audited canonical blobs.
[[ "$(git rev-parse HEAD:src/solver/mod_soil_water_solver_contract.f90)" == 276941d76ba951a89c43899e61fd0532418d8230 ]] || fail 'solver contract drift'
[[ "$(git rev-parse HEAD:src/solver/mod_reference_linear_solver.f90)" == 5b6ecd2341b315967bcfac6b879c3afe227fb245 ]] || fail 'linear solver drift'
[[ "$(git rev-parse HEAD:src/solver/mod_reference_richards_workspace.f90)" == 74f99556005ae39614f9df678467b1e19097bae2 ]] || fail 'workspace drift'
[[ "$(git rev-parse HEAD:src/legacy/b1_10_port/headcalc.f90)" == 3ff8d5cfd6963dfb7dafb33ec454fbc0df938a55 ]] || fail 'HeadCalc drift'
[[ "$(git rev-parse HEAD:src/adapter/mod_reference_richards_legacy_binding.f90)" == 03a64b6d09fd804242bcf76f7cb5277f59a6230a ]] || fail 'reference adapter drift'
[[ "$(git rev-parse HEAD:src/solver/mod_b110_default_mvg_provider.f90)" == fea5a1681b1c3bdefce1cdbb6d48a9396c8266b6 ]] || fail 'B110 value provider drift'
[[ "$(git rev-parse HEAD:src/solver/mod_b110_source_sink_provider.f90)" == d6c57add72387e5c0022a44319fff08046194aac ]] || fail 'B110 source/sink provider drift'
[[ "$(git rev-parse HEAD:src/solver/mod_fixed_flux_top_boundary_provider.f90)" == fb226f133bd48d8ab945f111c76897aeff49facf ]] || fail 'fixed-flux provider drift'
[[ "$(git rev-parse HEAD:src/solver/mod_b110_dynamic_top_boundary_provider.f90)" == 3eadae0f32aba49534cd58464e28c0af5bc9bf7d ]] || fail 'dynamic top value provider drift'
[[ "$(git rev-parse HEAD:src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90)" == 7a3cc3d01d994ea21bb0b48798cd2fb4aba9495e ]] || fail 'dynamic top solver adapter drift'
[[ "$(git rev-parse HEAD:src/process/mod_restricted_surface_evaporation.f90)" == a213af4deec2fe854d79120899827852a57237d1 ]] || fail 'surface evaporation process drift'

python3 tests/fsi/fsi37_make_reference_stubs.py tests/fsi/fsi04_real_headcalc_stubs.f90 "$BUILD/reference_stubs.f90"
grep -Fq 'Operation order follows SWAP 4.3.1 tridag.f90' "$BUILD/reference_stubs.f90" || fail 'reference TRIDAG marker missing'
grep -Fq 'case (6)' "$BUILD/reference_stubs.f90" || fail 'reference hcomean methods missing'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  "$BUILD/reference_stubs.f90"
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/solver/mod_soil_water_solver_contract.f90
  tests/fsi/mod_fsi37_dummy_alternative_solver.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_default_mvg_directional_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
  src/adapter/mod_reference_richards_accepted_step_directional_service.f90
)

build_and_run() {
  local opt="$1" tag="$2" out="$BUILD/$2"
  mkdir -p "$out"
  local objects=()
  for src in "${MODULE_SRC[@]}"; do
    local obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done

  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c tests/fsi/test_fsi37_accepted_step_directional_derivative.f90 -o "$out/fixed_test.o"
  gfortran "$opt" "${objects[@]}" "$out/fixed_test.o" -o "$out/test_fixed"
  timeout 120s "$out/test_fixed" | tee "$out/fixed_output.txt"
  grep -Fq 'FSI37_ACCEPTED_STEP_DIRECTIONAL_DERIVATIVE PASS' "$out/fixed_output.txt" || fail "fixed PASS marker missing opt=$tag"
  grep -Fq 'FSI37_FD_CASES=30' "$out/fixed_output.txt" || fail "fixed FD case count missing opt=$tag"
  grep -Fq 'FSI37_SWKMEAN_METHODS_1_6=PASS' "$out/fixed_output.txt" || fail "fixed mean-method marker missing opt=$tag"
  grep -Fq 'FSI37_NONUNIFORM_BASE_PROFILE=PASS' "$out/fixed_output.txt" || fail "fixed nonuniform-profile marker missing opt=$tag"
  grep -Fq 'FSI37_ALTERNATIVE_SOLVER_FAIL_CLOSED=PASS' "$out/fixed_output.txt" || fail "alternative-solver fail-closed marker missing opt=$tag"

  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c tests/fsi/test_fsi37_dynamic_surface_flux_direction.f90 -o "$out/dynamic_test.o"
  gfortran "$opt" "${objects[@]}" "$out/dynamic_test.o" -o "$out/test_dynamic"
  timeout 120s "$out/test_dynamic" | tee "$out/dynamic_output.txt"
  grep -Fq 'FSI37_DYNAMIC_SURFACE_FLUX_DIRECTION PASS' "$out/dynamic_output.txt" || fail "dynamic PASS marker missing opt=$tag"
  grep -Fq 'FSI37_DYNAMIC_FD_CASES=12' "$out/dynamic_output.txt" || fail "dynamic FD case count missing opt=$tag"
  grep -Fq 'FSI37_DYNAMIC_SWKMEAN_METHODS_1_6=PASS' "$out/dynamic_output.txt" || fail "dynamic mean-method marker missing opt=$tag"
  grep -Fq 'FSI37_DYNAMIC_TOP_FLUX_AND_MODE5_MASS_DERIVATIVE=PASS' "$out/dynamic_output.txt" || fail "dynamic flux/mass marker missing opt=$tag"
  grep -Fq 'FSI37_DYNAMIC_CAPACITY_LIMITED_FAIL_CLOSED=PASS' "$out/dynamic_output.txt" || fail "dynamic capacity fail-closed marker missing opt=$tag"

  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c tests/fsi/test_fsi37_dynamic_head_fail_closed.f90 -o "$out/head_fail_test.o"
  gfortran "$opt" "${objects[@]}" "$out/head_fail_test.o" -o "$out/test_head_fail"
  timeout 120s "$out/test_head_fail" | tee "$out/head_fail_output.txt"
  grep -Fq 'FSI37_DYNAMIC_HEAD_FAIL_CLOSED PASS' "$out/head_fail_output.txt" || fail "dynamic-head PASS marker missing opt=$tag"
  grep -Fq 'FSI37_DYNAMIC_HEAD_PHYSICAL_VALID=PASS' "$out/head_fail_output.txt" || fail "dynamic-head physical-valid marker missing opt=$tag"
  grep -Fq 'FSI37_DYNAMIC_HEAD_SENSITIVITY_FAIL_CLOSED=PASS' "$out/head_fail_output.txt" || fail "dynamic-head sensitivity fail-closed marker missing opt=$tag"
  grep -Fq 'FSI37_DYNAMIC_HEAD_ON_OFF_IDENTITY=PASS' "$out/head_fail_output.txt" || fail "dynamic-head identity marker missing opt=$tag"
  echo "FSI37_OPT_PASS=$tag"
}

build_and_run -O0 o0
build_and_run -O2 o2

# Full numerical gates execute independently under both optimization modes.
# Only stable qualification semantics are compared byte-for-byte.
{
  grep -E '^FSI37_(FD_CASES=30|SWKMEAN_METHODS_1_6=PASS|NONUNIFORM_BASE_PROFILE=PASS|ALTERNATIVE_SOLVER_FAIL_CLOSED=PASS|ACCEPTED_STEP_DIRECTIONAL_DERIVATIVE PASS)$' "$BUILD/o0/fixed_output.txt"
  grep -E '^FSI37_DYNAMIC_(FD_CASES=12|SWKMEAN_METHODS_1_6=PASS|TOP_FLUX_AND_MODE5_MASS_DERIVATIVE=PASS|CAPACITY_LIMITED_FAIL_CLOSED=PASS|SURFACE_FLUX_DIRECTION PASS)$' "$BUILD/o0/dynamic_output.txt"
  grep -E '^FSI37_DYNAMIC_HEAD_(PHYSICAL_VALID=PASS|SENSITIVITY_FAIL_CLOSED=PASS|ON_OFF_IDENTITY=PASS|FAIL_CLOSED PASS)$' "$BUILD/o0/head_fail_output.txt"
} > "$BUILD/o0/stable.txt"
{
  grep -E '^FSI37_(FD_CASES=30|SWKMEAN_METHODS_1_6=PASS|NONUNIFORM_BASE_PROFILE=PASS|ALTERNATIVE_SOLVER_FAIL_CLOSED=PASS|ACCEPTED_STEP_DIRECTIONAL_DERIVATIVE PASS)$' "$BUILD/o2/fixed_output.txt"
  grep -E '^FSI37_DYNAMIC_(FD_CASES=12|SWKMEAN_METHODS_1_6=PASS|TOP_FLUX_AND_MODE5_MASS_DERIVATIVE=PASS|CAPACITY_LIMITED_FAIL_CLOSED=PASS|SURFACE_FLUX_DIRECTION PASS)$' "$BUILD/o2/dynamic_output.txt"
  grep -E '^FSI37_DYNAMIC_HEAD_(PHYSICAL_VALID=PASS|SENSITIVITY_FAIL_CLOSED=PASS|ON_OFF_IDENTITY=PASS|FAIL_CLOSED PASS)$' "$BUILD/o2/head_fail_output.txt"
} > "$BUILD/o2/stable.txt"
cmp "$BUILD/o0/stable.txt" "$BUILD/o2/stable.txt" || fail 'O0/O2 qualification-marker drift'
echo 'FSI37_O0_O2_FULL_GATE=PASS'

echo 'FSI37_BOUNDED_COST_GUARD=PASS'
[[ "$(grep -Eic 'call[[:space:]]+reference_tridag_backsolve' src/adapter/mod_reference_richards_accepted_step_directional_service.f90)" -eq 1 ]] || fail 'accepted-step service must contain exactly one tangent backsolve site'
if grep -Eiq 'finite.?difference|centered.?difference|perturb.*solve' src/adapter/mod_reference_richards_accepted_step_directional_service.f90 src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90; then
  fail 'finite-difference production construction detected'
fi
if grep -Eiq 'save[[:space:]]*::|save[[:space:]]+[a-zA-Z_]' src/solver/mod_soil_water_accepted_step_direction_contract.f90 src/solver/mod_b110_default_mvg_directional_provider.f90 src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90 src/adapter/mod_reference_richards_accepted_step_directional_service.f90; then
  fail 'persistent SAVE state detected in F-SI37 source'
fi

echo 'FSI37_QUALIFICATION PASS'
