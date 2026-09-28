#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-timearch02-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

for OPT in 0 2; do
  gfortran -std=f2008 -Wall -Wextra -Werror -O"$OPT"     tests/fpe/test_fpe_timearch02_decision_contract.f90     -o "$BUILD/timearch02_O$OPT"
  "$BUILD/timearch02_O$OPT" | tee "$BUILD/O$OPT.log"
  grep -q '^F_PE_TIMEARCH02=PASS$' "$BUILD/O$OPT.log"
done

echo F_PE_TIMEARCH02_O0_O2=PASS
