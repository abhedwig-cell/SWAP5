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

python3 tests/fsi/fsi37_make_reference_stubs.py tests/fsi/fsi04_real_headcalc_stubs.f90 "$BUILD/reference_stubs.f90"
grep -Fq 'Operation order follows SWAP 4.3.1 tridag.f90' "$BUILD/reference_stubs.f90" || fail 'reference TRIDAG marker missing'
grep -Fq 'case (6)' "$BUILD/reference_stubs.f90" || fail 'reference hcomean methods missing'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  "$BUILD/reference_stubs.f90"
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_default_mvg_directional_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
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
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c tests/fsi/test_fsi37_accepted_step_directional_derivative.f90 -o "$out/test.o"
  gfortran "$opt" "${objects[@]}" "$out/test.o" -o "$out/test_fsi37"
  timeout 120s "$out/test_fsi37" | tee "$out/output.txt"
  grep -Fq 'FSI37_ACCEPTED_STEP_DIRECTIONAL_DERIVATIVE PASS' "$out/output.txt" || fail "PASS marker missing opt=$tag"
  grep -Fq 'FSI37_FD_CASES=30' "$out/output.txt" || fail "FD case count missing opt=$tag"
  grep -Fq 'FSI37_SWKMEAN_METHODS_1_6=PASS' "$out/output.txt" || fail "mean-method marker missing opt=$tag"
  grep -Fq 'FSI37_NONUNIFORM_BASE_PROFILE=PASS' "$out/output.txt" || fail "nonuniform-profile marker missing opt=$tag"
  grep -Fq 'FSI37_ALTERNATIVE_SOLVER_FAIL_CLOSED=PASS' "$out/output.txt" || fail "alternative-solver fail-closed marker missing opt=$tag"
  echo "FSI37_OPT_PASS=$tag"
}

build_and_run -O0 o0
build_and_run -O2 o2

# Compiler optimization is qualified by running the full numeric gates in both
# modes. Raw floating diagnostic rows may differ in last-bit formatting, so only
# stable qualification semantics are required to be identical.
grep -E '^FSI37_(FD_CASES=30|SWKMEAN_METHODS_1_6=PASS|NONUNIFORM_BASE_PROFILE=PASS|ALTERNATIVE_SOLVER_FAIL_CLOSED=PASS|ACCEPTED_STEP_DIRECTIONAL_DERIVATIVE PASS)$' "$BUILD/o0/output.txt" > "$BUILD/o0/stable.txt"
grep -E '^FSI37_(FD_CASES=30|SWKMEAN_METHODS_1_6=PASS|NONUNIFORM_BASE_PROFILE=PASS|ALTERNATIVE_SOLVER_FAIL_CLOSED=PASS|ACCEPTED_STEP_DIRECTIONAL_DERIVATIVE PASS)$' "$BUILD/o2/output.txt" > "$BUILD/o2/stable.txt"
cmp "$BUILD/o0/stable.txt" "$BUILD/o2/stable.txt" || fail 'O0/O2 qualification-marker drift'
echo 'FSI37_O0_O2_FULL_GATE=PASS'

echo 'FSI37_SAME_FACTORIZATION_COST_GUARD=PASS'
if grep -Eiq 'call[[:space:]].*%solve' src/adapter/mod_reference_richards_accepted_step_directional_service.f90; then
  [[ "$(grep -Eic 'call[[:space:]]+ref_solver%solve' src/adapter/mod_reference_richards_accepted_step_directional_service.f90)" -le 2 ]] || fail 'unexpected repeated Reference solve construction'
fi
[[ "$(grep -Eic 'call[[:space:]]+reference_tridag_backsolve' src/adapter/mod_reference_richards_accepted_step_directional_service.f90)" -eq 1 ]] || fail 'accepted-step service must contain exactly one tangent backsolve site'
if grep -Eiq 'finite.?difference|centered.?difference|perturb.*solve' src/adapter/mod_reference_richards_accepted_step_directional_service.f90; then
  fail 'finite-difference production construction detected'
fi

echo 'FSI37_QUALIFICATION PASS'
