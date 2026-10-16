#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-dynerr01-${GITHUB_RUN_ID:-local}-$$"
CANDIDATE_SRC="src/solver/fpe_dynerr01_temporal_indicator_generated.f90"
mkdir -p "$BUILD"
trap 'rm -f "$CANDIDATE_SRC"; rm -rf "$BUILD"' EXIT

python3 tests/rom/materialize_f_rom0_headcalc_stubs.py   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stub.f90" --nodes 16 --dz-cm 10

python3 tests/fpe/materialize_fpe_dynerr01_indicator.py   src/solver/mod_reference_richards_temporal_indicator.f90 "$CANDIDATE_SRC"

test -s "$CANDIDATE_SRC"
grep -Fq "module mod_fpe_dynerr01_temporal_indicator" "$CANDIDATE_SRC"

python3 tests/rom/compile_f_rom0_fortran_closure.py   --root "$ROOT"   --stub "$BUILD/stub.f90"   --target tests/fpe/test_fpe_dynerr01_indicator.f90   --external-source src/legacy/b1_10_port/headcalc.f90   --build "$BUILD/compile" --opt 2

python3 tests/fpe/run_fpe_dynerr01.py   "$BUILD/compile/rom0_test" docs/performance/F-PE-BOFEK01_TESTBANK.json
