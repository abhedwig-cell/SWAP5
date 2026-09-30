#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-nlglob14z28-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

gfortran -std=f2008 -O2 -Wall -Wextra -J"$BUILD" -I"$BUILD" \
  tests/fpe/mod_fpe_nlglob14z28_workspace_contract_stub.f90 \
  src/solver/mod_reference_linear_solver.f90 \
  src/solver/mod_reference_richards_workspace.f90 \
  tests/fpe/test_fpe_nlglob14z28_variable_dimension.f90 \
  -o "$BUILD/z28_test"

"$BUILD/z28_test"
