#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-timearch07-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

python3 tests/fpe/guard_fpe_timearch07_source.py

for opt in 0 2; do
  mkdir -p "$BUILD/o$opt"
  gfortran -std=f2008 -Wall -Wextra -O"$opt" -J"$BUILD/o$opt" -I"$BUILD/o$opt"     -c tests/fpe/timearch06_timecontrol_compile_stubs.f90 -o "$BUILD/o$opt/stubs.o"
  gfortran -std=f2008 -Wall -Wextra -O"$opt" -J"$BUILD/o$opt" -I"$BUILD/o$opt"     -c src/adapter/mod_b1_10_interval_seam.f90 -o "$BUILD/o$opt/interval.o"
  gfortran -std=f2008 -Wall -Wextra -O"$opt" -J"$BUILD/o$opt" -I"$BUILD/o$opt"     -c src/legacy/b1_10_fci11_port/mod_b1_10_timestep_decision_service.f90 -o "$BUILD/o$opt/decision.o"
  gfortran -std=f2008 -Wall -Wextra -ffree-line-length-none -O"$opt"     -J"$BUILD/o$opt" -I"$BUILD/o$opt" -Isrc/legacy/b1_10_fci11_port     -c src/legacy/b1_10_fci11_port/timecontrol.f90 -o "$BUILD/o$opt/timecontrol.o"
  gfortran -std=f2008 -Wall -Wextra -O"$opt" -J"$BUILD/o$opt" -I"$BUILD/o$opt"     tests/fpe/test_fpe_timearch07_trace.f90     "$BUILD/o$opt/timecontrol.o" "$BUILD/o$opt/decision.o" "$BUILD/o$opt/interval.o" "$BUILD/o$opt/stubs.o"     -o "$BUILD/timearch07_o$opt"
  "$BUILD/timearch07_o$opt" | tee "$BUILD/result_o$opt.txt"
  grep -Fq 'F_PE_TIMEARCH07_TRACE=PASS' "$BUILD/result_o$opt.txt"
done

cmp "$BUILD/result_o0.txt" "$BUILD/result_o2.txt"
echo "F_PE_TIMEARCH07_O0_O2_IDENTITY=PASS"

bash tests/fpe/run_fpe_timearch06.sh

echo "F_PE_TIMEARCH07=PASS"
