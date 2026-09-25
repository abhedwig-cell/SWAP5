#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fahl46-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
gfortran -std=f2008 -ffree-line-length-none -O3 research/ahl/test_fahl46_direct_hermite_screen.f90 -o "$BUILD/test"
"$BUILD/test" | tee "$BUILD/result.txt"
grep -Fq 'FAHL46_DIRECT_HERMITE_SCREEN=PASS' "$BUILD/result.txt"
