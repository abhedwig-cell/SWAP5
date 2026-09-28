#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-timeint07a-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"; trap 'rm -rf "$BUILD"' EXIT
python3 tests/rom/materialize_f_rom0_headcalc_stubs.py --source tests/fsi/fsi04_real_headcalc_stubs.f90 --output "$BUILD/stub.f90" --nodes 16 --dz-cm 10
python3 tests/fpe/materialize_fpe_timeint03_binding.py --source src/adapter/mod_reference_richards_legacy_binding.f90 --output "$BUILD/mod_fpe_timeint03_reference_binding.f90"
python3 tests/fpe/materialize_fpe_timeint02_headcalc.py --source src/legacy/b1_10_port/headcalc.f90 --output "$BUILD/headcalc_bdf2.f90"
python3 tests/fpe/materialize_fpe_timeint04b_floor.py --source "$BUILD/headcalc_bdf2.f90" --output "$BUILD/headcalc_timeint04b.f90"
python3 tests/fpe/materialize_fpe_timeint05_variable_bdf2.py --source "$BUILD/headcalc_timeint04b.f90" --output "$BUILD/headcalc_timeint05.f90"
python3 tests/fpe/compile_fpe_timeint03_closure.py --root "$ROOT" --stub "$BUILD/stub.f90" --target tests/fpe/test_fpe_timeint07_third_difference.f90 --external-source "$BUILD/headcalc_timeint05.f90" --external-module-source "$BUILD/mod_fpe_timeint03_reference_binding.f90" --build "$BUILD/compile" --opt 2
python3 tests/fpe/run_fpe_timeint07a.py "$BUILD/compile/timeint03_test" docs/performance/F-PE-BOFEK01_TESTBANK.json
