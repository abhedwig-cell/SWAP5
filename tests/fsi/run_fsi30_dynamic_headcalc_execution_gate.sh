#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-/tmp}/fsi30-dynamic-exec-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

fail() { echo "FSI30_DYNAMIC_EXEC_RUNNER_FAIL $*" >&2; exit 1; }

grep -Fq 'case (FSI_TOP_MODE_DYNAMIC_PROVIDER)' src/adapter/mod_reference_richards_legacy_binding.f90 || fail 'typed solver dynamic admission missing'
grep -Fq "route = 'dynamic-top-provider-required'" src/adapter/mod_reference_richards_legacy_binding.f90 || fail 'dynamic provider fail-closed route missing'
grep -Fq 'evaluation_context%dynamic_top_boundary%evaluate' src/legacy/b1_10_port/headcalc.f90 || fail 'HeadCalc dynamic provider consumption missing'
grep -Fq 'case (SW_TOP_BOUNDARY_REGIME_FLUX)' src/legacy/b1_10_port/headcalc.f90 || fail 'HeadCalc dynamic flux route missing'
grep -Fq 'case (SW_TOP_BOUNDARY_REGIME_HEAD)' src/legacy/b1_10_port/headcalc.f90 || fail 'HeadCalc dynamic head route missing'
grep -Fq 'fsi_ws%residual(NN) = fsi_ws%residual(NN) - state%qbot' src/legacy/b1_10_port/headcalc.f90 || fail 'prescribed qbot residual authority missing'
grep -Fq "result%interface_sensitivity%method = 'same-tridag-factor'" src/adapter/mod_reference_richards_legacy_binding.f90 || fail 'F-SI28 same-factor tangent seam missing'
[[ "$(git hash-object src/solver/mod_fixed_flux_top_boundary_provider.f90)" == 'fb226f133bd48d8ab945f111c76897aeff49facf' ]] || fail 'fixed-flux provider blob drift'
echo 'FSI30_DYNAMIC_EXEC_SOURCE_GUARD=PASS'

FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
SOURCES=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
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
  tests/fsi/test_fsi30_dynamic_headcalc_execution.f90
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
  gfortran "${FLAGS[@]}" -O"$opt" "${objects[@]}" -o "$out/test_fsi30_dynamic_exec"
  if ! timeout 90s env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$out/test_fsi30_dynamic_exec" > "$out/output.txt"; then
    cat "$out/output.txt"
    fail "O${opt} execution failed"
  fi
  for marker in \
    FSI30_REAL_SOLVER_DYNAMIC_FLUX=PASS \
    FSI30_REAL_SOLVER_ATMOSPHERIC_HEAD=PASS \
    FSI30_REAL_SOLVER_PONDED_HEAD=PASS \
    FSI30_REAL_SOLVER_LINEAR_RUNOFF=PASS \
    FSI30_REAL_SOLVER_HARD_MASS_CLOSURE=PASS \
    FSI30_FSI28_TANGENT_PRESERVATION=PASS \
    FSI30_FIXED_FLUX_REGRESSION=PASS \
    FSI30_DYNAMIC_MISSING_PROVIDER_FAIL_CLOSED=PASS \
    FSI30_DYNAMIC_HEADCALC_EXECUTION_GATE=PASS; do
      grep -Fq "$marker" "$out/output.txt" || fail "O${opt} missing $marker"
  done
  [[ "$(grep -c '^FSI30_CASE:' "$out/output.txt")" == 4 ]] || fail "O${opt} expected four dynamic execution cases"
  cat "$out/output.txt"
  echo "FSI30_DYNAMIC_EXEC_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || fail 'O0/O2 observable execution output differs'
echo 'FSI30_DYNAMIC_EXEC_O0_O2_IDENTITY=PASS'
echo 'FSI30_DYNAMIC_HEADCALC_EXECUTION_RUNNER=PASS'
