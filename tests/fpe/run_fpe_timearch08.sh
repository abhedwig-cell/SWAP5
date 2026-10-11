#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-timearch08-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

python3 tests/fpe/guard_fpe_timearch08_source.py
python3 tests/fpe/run_fpe_timearch08_shadow.py

# Re-run full TIMEARCH07 preservation with the shadow present but execution-isolated.
bash tests/fpe/run_fpe_timearch07.sh

for opt in 0 2; do
  mkdir -p "$BUILD/o$opt"
  gfortran -std=f2008 -Wall -Wextra -fopenmp -O"$opt"     -J"$BUILD/o$opt" -I"$BUILD/o$opt"     src/solver/mod_soil_water_accepted_step_direction_contract.f90     src/transaction/mod_accepted_trajectory_directional_sensitivity.f90     src/runtime/mod_a23bu_worker_execution_context.f90     tests/fpe/test_fpe_timearch08_shadow_context.f90     -o "$BUILD/o$opt/test_shadow"
  "$BUILD/o$opt/test_shadow" | tee "$BUILD/o$opt.txt"
done
cmp "$BUILD/o0.txt" "$BUILD/o2.txt"
echo "F_PE_TIMEARCH08_O0_O2_IDENTITY=PASS"
echo "F_PE_TIMEARCH08=PASS"
