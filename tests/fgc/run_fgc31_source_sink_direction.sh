#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fgc31-source-sink-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail(){ echo "FGC31_SOURCE_SINK_GATE_FAIL $*" >&2; exit 31; }

python3 tests/qualification/fvq89/fvq89_make_reference_stubs.py   tests/fsi/fsi04_real_headcalc_stubs.f90 "$BUILD/reference_stubs.f90" >/dev/null

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

build_and_run(){
  local opt="$1" tag="$2" out="$BUILD/$2"
  mkdir -p "$out"
  local objects=()
  for src in "${MODULE_SRC[@]}"; do
    local obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out"     -c tests/fgc/test_fgc31_source_sink_direction.f90 -o "$out/test.o"
  gfortran "$opt" "${objects[@]}" "$out/test.o" -o "$out/test_fgc31_source_sink"
  timeout 180s "$out/test_fgc31_source_sink" > "$out/output.txt" 2>&1 || {
    cat "$out/output.txt" >&2
    fail "execution $tag"
  }
  for marker in     'FGC31_SOURCE_SINK_RHS_FD=PASS'     'FGC31_SOURCE_SINK_BOTTOM_HEAD_QBOT_FD=PASS'     'FGC31_ABSENT_ZERO_DIRECTION_IDENTITY=PASS'     'FGC31_SOURCE_SINK_DIRECTION_FAIL_CLOSED=PASS'     'FGC31_SOURCE_SINK_NO_EXTRA_NONLINEAR_SOLVE=PASS'; do
    grep -Fxq "$marker" "$out/output.txt" || { cat "$out/output.txt" >&2; fail "missing $tag marker $marker"; }
  done
  grep '^FGC31_SOURCE_SINK_FD_ERROR' "$out/output.txt" > "$out/signatures.txt"
  echo "FGC31_SOURCE_SINK_O${tag}=PASS"
}

build_and_run -O0 0
build_and_run -O2 2
cmp "$BUILD/0/signatures.txt" "$BUILD/2/signatures.txt" || fail 'O0/O2 FD signature drift'
echo 'FGC31_SOURCE_SINK_O0_O2_EXACT_SIGNATURE_IDENTITY=PASS'

[[ "$(grep -Eic 'call[[:space:]]+reference_tridag_backsolve' src/adapter/mod_reference_richards_accepted_step_directional_service.f90)" -eq 1 ]] || fail 'tangent backsolve count changed'
if grep -Eiq 'finite.?difference|perturb.*solve'   src/adapter/mod_reference_richards_accepted_step_directional_service.f90   src/solver/mod_soil_water_accepted_step_direction_contract.f90; then
  fail 'production finite-difference construction detected'
fi
if grep -Eiq 'save[[:space:]]*::|save[[:space:]]+[a-zA-Z_]'   src/adapter/mod_reference_richards_accepted_step_directional_service.f90   src/solver/mod_soil_water_accepted_step_direction_contract.f90; then
  fail 'persistent SAVE state detected'
fi

cat "$BUILD/0/output.txt"
echo 'FGC31_SOURCE_SINK_BOUNDED_ANALYTIC_IMPLEMENTATION=PASS'
echo 'F-GC31 SOURCE-SINK DIRECTION GATE PASS'
