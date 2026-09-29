#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-timeint12a-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"; trap 'rm -rf "$BUILD"' EXIT
python3 tests/rom/materialize_f_rom0_headcalc_stubs.py --source tests/fsi/fsi04_real_headcalc_stubs.f90 --output "$BUILD/stub.f90" --nodes 16 --dz-cm 10
python3 tests/fpe/materialize_fpe_timeint12a_dynamic_adapter.py --source src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90 --output "$BUILD/dynamic_adapter.f90"
python3 tests/fpe/materialize_fpe_timeint12a_binding.py --source src/adapter/mod_reference_richards_legacy_binding.f90 --output "$BUILD/reference_binding.f90"
python3 tests/fpe/compile_fpe_timeint03_closure.py --root "$ROOT" --stub "$BUILD/stub.f90" --target tests/fpe/test_fpe_timeint12a_dynamic_be.f90 --external-source src/legacy/b1_10_port/headcalc.f90 --external-module-source "$BUILD/dynamic_adapter.f90" --external-module-source "$BUILD/reference_binding.f90" --build "$BUILD/compile" --opt 2
python3 tests/fpe/run_fpe_timeint12a.py "$BUILD/compile/timeint03_test" docs/performance/F-PE-BOFEK01_TESTBANK.json
