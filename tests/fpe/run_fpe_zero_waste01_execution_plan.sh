#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-/tmp}/fpe-zero-waste01-plan-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -O2 -J"$BUILD" -I"$BUILD"   -c src/runtime/mod_fmr_runtime_core.f90 -o "$BUILD/core.o"
gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -O2 -J"$BUILD" -I"$BUILD"   -c src/runtime/mod_fmr_serialized_execution_plan.f90 -o "$BUILD/plan.o"
gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -O2 -J"$BUILD" -I"$BUILD"   -c tests/fpe/test_fpe_zero_waste01_execution_plan.f90 -o "$BUILD/test.o"
gfortran -O2 "$BUILD/core.o" "$BUILD/plan.o" "$BUILD/test.o" -o "$BUILD/test"
"$BUILD/test"
