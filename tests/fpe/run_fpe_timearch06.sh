#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-timearch06-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

python3 tests/fpe/guard_fpe_timearch06_source.py

for opt in 0 2; do
  mkdir -p "$BUILD/o$opt"
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
mkdir -p "$BUILD/compat"
gfortran -std=f2008 -Wall -Wextra -O2 -J"$BUILD/compat" -I"$BUILD/compat" \
  tests/fpe/mod_fpe_timearch02_contract.f90 \
  tests/fpe/test_fpe_timearch02_contract.f90 \
  -o "$BUILD/timearch02_compat"
"$BUILD/timearch02_compat" | tee "$BUILD/compat.txt"
grep -Fq 'F_PE_TIMEARCH02_CONTRACT=PASS' "$BUILD/compat.txt"

echo "F_PE_TIMEARCH06=PASS"

# Compile the actual production TimeControl include closure against minimal
# dependency stubs. This is syntax/integration evidence for the new service use.
mkdir -p "$BUILD/timecontrol"
gfortran -std=f2008 -Wall -Wextra -O2 -J"$BUILD/timecontrol" -I"$BUILD/timecontrol" \
  -c tests/fpe/timearch06_timecontrol_compile_stubs.f90 \
  -o "$BUILD/timecontrol/stubs.o"
gfortran -std=f2008 -Wall -Wextra -O2 -J"$BUILD/timecontrol" -I"$BUILD/timecontrol" \
  -c src/adapter/mod_b1_10_interval_seam.f90 \
  -o "$BUILD/timecontrol/interval.o"
gfortran -std=f2008 -Wall -Wextra -O2 -J"$BUILD/timecontrol" -I"$BUILD/timecontrol" \
  -c src/legacy/b1_10_fci11_port/mod_b1_10_timestep_decision_service.f90 \
  -o "$BUILD/timecontrol/decision.o"
gfortran -std=f2008 -Wall -Wextra -ffree-line-length-none -O2 \
  -J"$BUILD/timecontrol" -I"$BUILD/timecontrol" -Isrc/legacy/b1_10_fci11_port \
  -c src/legacy/b1_10_fci11_port/timecontrol.f90 \
  -o "$BUILD/timecontrol/timecontrol.o"
echo "F_PE_TIMEARCH06_TIMECONTROL_COMPILE=PASS"
