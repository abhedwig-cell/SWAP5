#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-planvalid01-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

gfortran -std=f2008 -ffree-line-length-none -O2 -J "$BUILD" -I "$BUILD" -c src/runtime/mod_fmr_runtime_core.f90 -o "$BUILD/runtime.o"
gfortran -std=f2008 -ffree-line-length-none -O2 -J "$BUILD" -I "$BUILD" -c tests/fpe/test_fpe_planvalid01_baseline.f90 -o "$BUILD/test.o"
gfortran -O2 "$BUILD/runtime.o" "$BUILD/test.o" -o "$BUILD/test"

"$BUILD/test" 1 100000
"$BUILD/test" 100 10000
"$BUILD/test" 1000 100
"$BUILD/test" 10000 3
