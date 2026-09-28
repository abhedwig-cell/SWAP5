#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-timearch06-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

python3 tests/fpe/guard_fpe_timearch06_source.py

for opt in 0 2; do
  gfortran -std=f2008 -Wall -Wextra -O"$opt" -J"$BUILD/o$opt" -I"$BUILD/o$opt" \
    src/legacy/b1_10_fci11_port/mod_b1_10_timestep_decision_service.f90 \
    tests/fpe/test_fpe_timearch06_service.f90 \
    -o "$BUILD/timearch06_o$opt"
  "$BUILD/timearch06_o$opt" | tee "$BUILD/result_o$opt.txt"
  grep -Fq 'F_PE_TIMEARCH06_SERVICE=PASS' "$BUILD/result_o$opt.txt"
done

cmp "$BUILD/result_o0.txt" "$BUILD/result_o2.txt"
echo "F_PE_TIMEARCH06_O0_O2_IDENTITY=PASS"

# The already-qualified test-only compatibility matrix must remain green.
gfortran -std=f2008 -Wall -Wextra -O2 -J"$BUILD/compat" -I"$BUILD/compat" \
  tests/fpe/mod_fpe_timearch02_contract.f90 \
  tests/fpe/test_fpe_timearch02_contract.f90 \
  -o "$BUILD/timearch02_compat"
"$BUILD/timearch02_compat" | tee "$BUILD/compat.txt"
grep -Fq 'F_PE_TIMEARCH02_CONTRACT=PASS' "$BUILD/compat.txt"

echo "F_PE_TIMEARCH06=PASS"
