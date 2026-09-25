#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-newton-candidate01-reduction-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
gfortran -std=f2008 -ffree-line-length-none -O2 tests/fpe/test_fpe_newton_candidate01_reductions.f90 -o "$BUILD/test"
"$BUILD/test"
