#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fci67-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

TX=src/transaction/mod_transaction_reference.f90
CONTRACTS=src/runtime/mod_canonical_contracts.f90
RUNTIME=src/runtime/mod_canonical_interval_runtime.f90
POLICY=src/runtime/mod_rossfast_d3r_execution_policy.f90
TEST=tests/fci/test_fci67_rossfast_d3r_execution_policy.f90

# F-CI67 is an adapter-only admission on the exact F-CI66P canonical surface.
test "$(git rev-parse HEAD:$TX)" = d5a71a526efaebd82054580c3186f8e3545db331
test "$(git rev-parse HEAD:$CONTRACTS)" = 3cbb81b25626e6574ae83416f088dc52882f91fc
test "$(git rev-parse HEAD:$RUNTIME)" = b12327aa6e77bdbf4586fe0bed82cf0e7704f237

grep -Fq 'ROSSFAST_D3R_MAX_FULL_INDEX = 8' "$POLICY"
grep -Fq 'ROSSFAST_D3R_HALF_ONLY_INDEX = 9' "$POLICY"
grep -Fq 'max_retries_cap = ROSSFAST_D3R_MAX_FULL_INDEX - index' "$POLICY"
grep -Fq 'grid_units = nint(units_real)' "$POLICY"
grep -Fq 'do index = 0, ROSSFAST_D3R_MAX_FULL_INDEX' "$POLICY"

COMMON=(-std=f2008 -Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -fbacktrace -fopenmp)
for opt in o0 o2; do
  flag=-O0
  [[ "$opt" == o2 ]] && flag=-O2
  gfortran "${COMMON[@]}" "$flag" -J "$BUILD/$opt" \
    "$TX" "$CONTRACTS" "$RUNTIME" "$POLICY" "$TEST" -o "$BUILD/$opt/test"
  "$BUILD/$opt/test" > "$BUILD/$opt/output.txt"
  grep -Fq 'FCI67_ROSSFAST_D3R_EXECUTION_POLICY_GATE PASS' "$BUILD/$opt/output.txt"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo "FCI67_O0_O2_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'FCI67_ROSSFAST_D3R_EXECUTION_POLICY_ADMISSION=PASS'
