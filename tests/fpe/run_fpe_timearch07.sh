#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-timearch07-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

python3 tests/fpe/guard_fpe_timearch07_source.py

# Preserve the production decision-service extraction and TimeControl compile.
bash tests/fpe/run_fpe_timearch06.sh

# Verify the actual worker-local trace carrier at O0 and O2 under OpenMP.
for opt in 0 2; do
  mkdir -p "$BUILD/worker_o$opt"
  gfortran -std=f2008 -Wall -Wextra -fopenmp -O"$opt"     -J"$BUILD/worker_o$opt" -I"$BUILD/worker_o$opt"     src/solver/mod_soil_water_accepted_step_direction_contract.f90     src/transaction/mod_accepted_trajectory_directional_sensitivity.f90     src/runtime/mod_a23bu_worker_execution_context.f90     tests/runtime/test_a23bu_worker_context.f90     -o "$BUILD/worker_o$opt/test_worker"
  "$BUILD/worker_o$opt/test_worker" | tee "$BUILD/worker_o$opt.txt"
  grep -Fq 'A23BU_WORKER_CONTEXT_GATE PASS' "$BUILD/worker_o$opt.txt"
done
cmp "$BUILD/worker_o0.txt" "$BUILD/worker_o2.txt"
echo "F_PE_TIMEARCH07_WORKER_O0_O2_IDENTITY=PASS"

# Preserve the already-qualified observation-only attribution harness.
bash tests/fpe/run_fpe_timearch03_attribution.sh

echo "F_PE_TIMEARCH07=PASS"
