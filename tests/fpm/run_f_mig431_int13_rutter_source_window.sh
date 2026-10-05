#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-int13-rutter-window-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

for opt in 0 2; do
  mkdir -p "$BUILD/o$opt"
  gfortran -std=f2008 -pedantic-errors -ffree-line-length-none -Wall -Wextra -Werror \
    -Wno-error=unused-dummy-argument -Wno-error=compare-reals -fcheck=all -fbacktrace \
    -ffpe-trap=invalid,zero,overflow -O"$opt" \
    -J"$BUILD/o$opt" -I"$BUILD/o$opt" \
    "$ROOT/src/solver/mod_soil_water_solver_contract.f90" \
    "$ROOT/src/solver/mod_b110_default_mvg_provider.f90" \
    "$ROOT/src/process/mod_restricted_surface_evaporation.f90" \
    "$ROOT/src/solver/mod_b110_dynamic_top_boundary_provider.f90" \
    "$ROOT/src/crop/mod_crop_root_uptake_input_contract.f90" \
    "$ROOT/src/process/mod_rutter_interception_process.f90" \
    "$ROOT/src/process/mod_rutter_event_integrator.f90" \
    "$ROOT/src/runtime/mod_interception_source_window_runtime.f90" \
    "$ROOT/src/runtime/mod_rutter_source_window_processor.f90" \
    "$ROOT/src/runtime/mod_fmr_rutter_output_application_binding.f90" \
    "$ROOT/src/runtime/mod_fmr_rutter_source_window_application.f90" \
    "$ROOT/tests/fpm/test_f_mig431_int13_rutter_source_window.f90" \
    -o "$BUILD/o$opt/test"
  "$BUILD/o$opt/test" > "$BUILD/o$opt/output.txt"
done
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o0/output.txt"
echo F_MIG431_INT13_RUTTER_SOURCE_WINDOW_O0_O2_IDENTITY=PASS
