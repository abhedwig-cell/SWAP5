#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-/tmp}/fpe-zero-waste01-gwreg-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
gfortran -std=f2008 -ffree-line-length-none -O2 tests/fpe/test_fpe_zero_waste01_gwreg_resolution.f90 -o "$BUILD/test"
for n in 100 1000 10000; do "$BUILD/test" "$n"; done
