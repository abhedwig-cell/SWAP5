#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-/tmp}/fpe-h17a-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
gfortran -std=f2008 -ffree-line-length-none -O2 tests/fpe/test_fpe_zero_waste01_h17a_adapter_vectors.f90 -o "$BUILD/test"
"$BUILD/test" 60 100000
"$BUILD/test" 200 30000
"$BUILD/test" 1000 5000
