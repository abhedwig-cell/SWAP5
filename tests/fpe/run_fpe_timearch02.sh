#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
python3 tests/fpe/guard_fpe_timearch02_source.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-timearch02-$$"
mkdir -p "$BUILD"
for opt in 0 2; do
  gfortran -std=f2008 -O"$opt" -J"$BUILD" -I"$BUILD" -c tests/fpe/mod_fpe_timearch02_contract.f90 -o "$BUILD/mod_o$opt.o"
  gfortran -std=f2008 -O"$opt" -J"$BUILD" -I"$BUILD" tests/fpe/test_fpe_timearch02_contract.f90 "$BUILD/mod_o$opt.o" -o "$BUILD/test_o$opt"
  "$BUILD/test_o$opt"
done
echo F_PE_TIMEARCH02=PASS
