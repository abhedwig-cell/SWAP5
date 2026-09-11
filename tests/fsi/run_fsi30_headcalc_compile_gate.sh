#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-/tmp}/fsi30-headcalc-compile-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

fail() { echo "FSI30_HEADCALC_COMPILE_FAIL $*" >&2; exit 1; }

FIXED_PROVIDER_BLOB=fb226f133bd48d8ab945f111c76897aeff49facf
[[ "$(git hash-object src/solver/mod_fixed_flux_top_boundary_provider.f90)" == "$FIXED_PROVIDER_BLOB" ]] || \
  fail 'fixed-flux provider blob drift'

grep -Fq 'provider_dynamic_top_active' src/legacy/b1_10_port/headcalc.f90 || fail 'dynamic HeadCalc activation missing'
grep -Fq 'evaluation_context%dynamic_top_boundary%evaluate' src/legacy/b1_10_port/headcalc.f90 || fail 'dynamic provider evaluation missing'
grep -Fq 'case (SW_TOP_BOUNDARY_REGIME_FLUX)' src/legacy/b1_10_port/headcalc.f90 || fail 'dynamic flux route missing'
grep -Fq 'case (SW_TOP_BOUNDARY_REGIME_HEAD)' src/legacy/b1_10_port/headcalc.f90 || fail 'dynamic head route missing'
grep -Fq 'provider_dynamic_top_result%net_potential_surface_flux*dt' src/legacy/b1_10_port/headcalc.f90 || fail 'dynamic surface mass balance missing'
echo 'FSI30_HEADCALC_SOURCE_GUARD=PASS'

FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -pedantic -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
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
)

for opt in 0 2; do
  out="$BUILD/o$opt"
  mkdir -p "$out"
  for src in "${SOURCES[@]}"; do
    [[ -f "$src" ]] || fail "missing compile dependency $src"
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${FLAGS[@]}" -O"$opt" -J"$out" -I"$out" -c "$src" -o "$obj"
  done
  echo "FSI30_HEADCALC_COMPILE_O${opt}=PASS"
done

echo 'FSI30_HEADCALC_COMPILE_GATE=PASS'
