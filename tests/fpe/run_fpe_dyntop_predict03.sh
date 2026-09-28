#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-dyntop-predict03-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"; trap 'rm -rf "$BUILD"' EXIT
python3 tests/rom/materialize_f_rom0_headcalc_stubs.py --source tests/fsi/fsi04_real_headcalc_stubs.f90 --output "$BUILD/stub.f90" --nodes 16 --dz-cm 10
python3 tests/rom/compile_f_rom0_fortran_closure.py --root "$ROOT" --stub "$BUILD/stub.f90" --target tests/fpe/test_fpe_dyntop_predict02.f90 --external-source src/legacy/b1_10_port/headcalc.f90 --build "$BUILD/compile" --opt 2
python3 tests/fpe/run_fpe_dyntop_predict03.py "$BUILD/compile/rom0_test" docs/performance/F-PE-BOFEK01_TESTBANK.json docs/performance/F-PE-DYNTOP-PREDICT03_VALIDATION_BANK.json
