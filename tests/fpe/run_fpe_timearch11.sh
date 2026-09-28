#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-timearch11-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"; trap 'rm -rf "$BUILD"' EXIT
python3 tests/fpe/guard_fpe_timearch11_source.py
for opt in 0 2; do
  mkdir -p "$BUILD/o$opt"
  gfortran -std=f2008 -Wall -Wextra -pedantic -O"$opt" -J"$BUILD/o$opt" -I"$BUILD/o$opt"     src/legacy/b1_10_fci11_port/mod_b1_10_timestep_decision_service.f90     src/runtime/mod_timestep_controller_contract.f90     tests/fpe/test_fpe_timearch11_controller_contract.f90     -o "$BUILD/o$opt/test_controller"
  "$BUILD/o$opt/test_controller" | tee "$BUILD/o$opt.txt"
done
cmp "$BUILD/o0.txt" "$BUILD/o2.txt"
echo "F_PE_TIMEARCH11_O0_O2_IDENTITY=PASS"
bash tests/fpe/run_fpe_timearch10.sh
echo "F_PE_TIMEARCH11=PASS"
