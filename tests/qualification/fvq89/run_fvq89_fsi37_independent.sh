#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq89-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FVQ89_QUALIFICATION_FAIL $*" >&2; exit 1; }

# Exact F-SI37 production payload from tested source SHA
# 992d524e3a4f5f7e21ddd9b6992c0e043f66c9fd.
[[ "$(git rev-parse HEAD:src/solver/mod_soil_water_accepted_step_direction_contract.f90)" == 52698b1ad2350bf787862a053a49c7c73c3358f0 ]] || fail 'F-SI37 contract blob drift'
[[ "$(git rev-parse HEAD:src/solver/mod_b110_default_mvg_directional_provider.f90)" == b1e794d2f0e661a2abb14280a59175e1cf1d5724 ]] || fail 'F-SI37 MVG directional provider blob drift'
[[ "$(git rev-parse HEAD:src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90)" == 0a957376b9a9fdea00ab6009f129803fb5341e4a ]] || fail 'F-SI37 dynamic-top directional adapter blob drift'
[[ "$(git rev-parse HEAD:src/adapter/mod_reference_richards_accepted_step_directional_service.f90)" == ef395ac3fb0cf6f347031bf2081a74b74b5167ae ]] || fail 'F-SI37 accepted-step service blob drift'

# Audited dependencies. All are unchanged from the owner baseline except the
# temporal-indicator dependency, which is deliberately pinned to live canonical.
[[ "$(git rev-parse HEAD:src/solver/mod_soil_water_solver_contract.f90)" == 276941d76ba951a89c43899e61fd0532418d8230 ]] || fail 'solver contract drift'
[[ "$(git rev-parse HEAD:src/solver/mod_reference_linear_solver.f90)" == 5b6ecd2341b315967bcfac6b879c3afe227fb245 ]] || fail 'linear solver drift'
[[ "$(git rev-parse HEAD:src/solver/mod_reference_richards_workspace.f90)" == 74f99556005ae39614f9df678467b1e19097bae2 ]] || fail 'workspace drift'
[[ "$(git rev-parse HEAD:src/legacy/b1_10_port/headcalc.f90)" == 3ff8d5cfd6963dfb7dafb33ec454fbc0df938a55 ]] || fail 'HeadCalc drift'
[[ "$(git rev-parse HEAD:src/adapter/mod_reference_richards_legacy_binding.f90)" == 03a64b6d09fd804242bcf76f7cb5277f59a6230a ]] || fail 'reference adapter drift'
[[ "$(git rev-parse HEAD:src/solver/mod_b110_default_mvg_provider.f90)" == fea5a1681b1c3bdefce1cdbb6d48a9396c8266b6 ]] || fail 'B110 value provider drift'
[[ "$(git rev-parse HEAD:src/solver/mod_b110_source_sink_provider.f90)" == d6c57add72387e5c0022a44319fff08046194aac ]] || fail 'B110 source/sink provider drift'
[[ "$(git rev-parse HEAD:src/solver/mod_fixed_flux_top_boundary_provider.f90)" == fb226f133bd48d8ab945f111c76897aeff49facf ]] || fail 'fixed-flux provider drift'
[[ "$(git rev-parse HEAD:src/solver/mod_b110_dynamic_top_boundary_provider.f90)" == 3eadae0f32aba49534cd58464e28c0af5bc9bf7d ]] || fail 'dynamic top provider drift'
[[ "$(git rev-parse HEAD:src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90)" == 7a3cc3d01d994ea21bb0b48798cd2fb4aba9495e ]] || fail 'dynamic top solver adapter drift'
[[ "$(git rev-parse HEAD:src/process/mod_restricted_surface_evaporation.f90)" == a213af4deec2fe854d79120899827852a57237d1 ]] || fail 'surface evaporation process drift'
[[ "$(git rev-parse HEAD:src/solver/mod_reference_richards_temporal_indicator.f90)" == b648502dea7dfd5de8279bcfa06908c705dcfd2f ]] || fail 'current canonical temporal indicator drift'

# Reuse only the legacy-reference stub materializer, not any F-SI37 owner test.
python3 tests/qualification/fvq89/fvq89_make_reference_stubs.py \
  tests/fsi/fsi04_real_headcalc_stubs.f90 "$BUILD/reference_stubs.f90"
grep -Fq 'Operation order follows SWAP 4.3.1 tridag.f90' "$BUILD/reference_stubs.f90" || fail 'legacy TRIDAG oracle missing'
grep -Fq 'case (6)' "$BUILD/reference_stubs.f90" || fail 'legacy hcomean methods missing'

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
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
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

  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" \
    -c tests/qualification/fvq89/test_fvq89_fsi37_independent.f90 -o "$out/test.o"
  gfortran "$opt" "${objects[@]}" "$out/test.o" -o "$out/test_fvq89"
  timeout 180s "$out/test_fvq89" | tee "$out/output.txt"

  grep -Fq 'FVQ89_FD_CASES=5' "$out/output.txt" || fail "FD case count missing opt=$tag"
  grep -Fq 'FVQ89_ACCEPTED_ENDPOINT_REFERENCE=PASS' "$out/output.txt" || fail "accepted endpoint marker missing opt=$tag"
  grep -Fq 'FVQ89_ZERO_SINGLE_MIXED_DIRECTIONS=PASS' "$out/output.txt" || fail "direction coverage marker missing opt=$tag"
  grep -Fq 'FVQ89_NO_COMMITTED_STATE_MUTATION=PASS' "$out/output.txt" || fail "state mutation marker missing opt=$tag"
  grep -Fq 'FVQ89_RETRY_NO_DERIVATIVE_LEAK=PASS' "$out/output.txt" || fail "retry leak marker missing opt=$tag"
  grep -Fq 'FVQ89_FAIL_CLOSED=PASS' "$out/output.txt" || fail "fail-closed marker missing opt=$tag"
  grep -Fq 'FVQ89_FSI37_INDEPENDENT PASS' "$out/output.txt" || fail "qualification marker missing opt=$tag"

  grep '^FVQ89_SIGNATURE ' "$out/output.txt" > "$out/signatures.txt"
  [[ "$(wc -l < "$out/signatures.txt")" -eq 5 ]] || fail "signature count wrong opt=$tag"
  echo "FVQ89_OPT_PASS=$tag"
}

build_and_run -O0 o0
build_and_run -O2 o2

cmp "$BUILD/o0/signatures.txt" "$BUILD/o2/signatures.txt" || fail 'O0/O2 derivative bit signatures differ'
echo 'FVQ89_O0_O2_DERIVATIVE_BIT_IDENTITY=PASS'

[[ "$(grep -Eic 'call[[:space:]]+reference_tridag_backsolve' src/adapter/mod_reference_richards_accepted_step_directional_service.f90)" -eq 1 ]] || fail 'expected exactly one tangent backsolve site'
if grep -Eiq 'finite.?difference|centered.?difference|perturb.*solve' \
  src/adapter/mod_reference_richards_accepted_step_directional_service.f90 \
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90 \
  src/solver/mod_b110_default_mvg_directional_provider.f90; then
  fail 'finite-difference production derivative construction detected'
fi
if grep -Eiq 'save[[:space:]]*::|save[[:space:]]+[a-zA-Z_]' \
  src/solver/mod_soil_water_accepted_step_direction_contract.f90 \
  src/solver/mod_b110_default_mvg_directional_provider.f90 \
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90 \
  src/adapter/mod_reference_richards_accepted_step_directional_service.f90; then
  fail 'persistent SAVE state detected in F-SI37 production sources'
fi

echo 'FVQ89_BOUNDED_ANALYTIC_IMPLEMENTATION=PASS'
echo 'FVQ89_QUALIFICATION PASS'
