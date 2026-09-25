#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-/tmp}/fpe-zero-waste01-atomic-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

gfortran -std=f2008 -ffree-line-length-none -O2 -fopenmp   tests/fpe/test_fpe_zero_waste01_atomic_tracking.f90 -o "$BUILD/test"
OMP_NUM_THREADS=1 "$BUILD/test"
