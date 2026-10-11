#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-nlglob14z47-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT

compile_and_run() {
  local optimization="$1"
  local label="$2"
  local build_dir="$BUILD/$label"

  gfortran -std=f2008 "$optimization" -Wall -Wextra -ffree-line-length-none \
    -J"$build_dir" -I"$build_dir" \
    src/solver/mod_soil_water_solver_contract.f90 \
    src/solver/mod_reference_richards_state_binding.f90 \
    src/runtime/mod_timestep_numerical_profile.f90 \
    src/runtime/mod_moving_interface_manager.f90 \
    tests/fpe/test_fpe_nlglob14z47_eligibility.f90 \
    -o "$build_dir/z47_eligibility"

  "$build_dir/z47_eligibility" > "$BUILD/$label.out"
  cat "$BUILD/$label.out"
  echo "F_PE_NLGLOB14Z47_${label^^}=PASS"
}

compile_and_run -O0 o0
compile_and_run -O2 o2

cmp "$BUILD/o0.out" "$BUILD/o2.out"
echo 'F_PE_NLGLOB14Z47_O0_O2_STABLE=PASS'
