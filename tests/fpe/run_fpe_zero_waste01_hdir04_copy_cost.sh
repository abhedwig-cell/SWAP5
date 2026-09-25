#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-/tmp}/fpe-hdir04-copy-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

gfortran -std=f2008 -ffree-line-length-none -O2 tests/fpe/test_fpe_zero_waste01_hdir04_copy_cost.f90 -o "$BUILD/test"
"$BUILD/test" 60 200000
"$BUILD/test" 200 100000
"$BUILD/test" 1000 20000
