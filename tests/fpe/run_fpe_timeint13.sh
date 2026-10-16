#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-timeint13-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

python3 tests/rom/materialize_f_rom0_headcalc_stubs.py   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stub.f90" --nodes 16 --dz-cm 10

python3 tests/fpe/materialize_fpe_timeint03_binding.py   --source src/adapter/mod_reference_richards_legacy_binding.f90   --output "$BUILD/mod_fpe_timeint03_reference_binding.f90"

python3 tests/fpe/materialize_fpe_timeint02_headcalc.py   --source src/legacy/b1_10_port/headcalc.f90   --output "$BUILD/headcalc_bdf2.f90"

python3 tests/fpe/materialize_fpe_timeint04b_floor.py   --source "$BUILD/headcalc_bdf2.f90"   --output "$BUILD/headcalc_timeint04b.f90"

python3 tests/fpe/materialize_fpe_timeint05_variable_bdf2.py   --source "$BUILD/headcalc_timeint04b.f90"   --output "$BUILD/headcalc_timeint05.f90"

python3 tests/fpe/compile_fpe_timeint03_closure.py   --root "$ROOT" --stub "$BUILD/stub.f90"   --target tests/fpe/test_fpe_timeint13_order.f90   --external-source "$BUILD/headcalc_timeint05.f90"   --external-module-source "$BUILD/mod_fpe_timeint03_reference_binding.f90"   --external-module-source tests/fpe/mod_fpe_timeint13_predicted_k_provider.f90   --build "$BUILD/order" --opt 2

python3 tests/fpe/compile_fpe_timeint03_closure.py   --root "$ROOT" --stub "$BUILD/stub.f90"   --target tests/fpe/test_fpe_timeint05_variable_bdf2.f90   --external-source "$BUILD/headcalc_timeint05.f90"   --external-module-source "$BUILD/mod_fpe_timeint03_reference_binding.f90"   --build "$BUILD/fullbdf2" --opt 2

python3 tests/fpe/compile_fpe_timeint03_closure.py   --root "$ROOT" --stub "$BUILD/stub.f90"   --target tests/fpe/test_fpe_timeint13_dyntop.f90   --external-source "$BUILD/headcalc_timeint05.f90"   --external-module-source "$BUILD/mod_fpe_timeint03_reference_binding.f90"   --external-module-source tests/fpe/mod_fpe_timeint13_predicted_k_provider.f90   --build "$BUILD/dyntop" --opt 2

python3 tests/fpe/compile_fpe_timeint03_closure.py   --root "$ROOT" --stub "$BUILD/stub.f90"   --target tests/fpe/test_fpe_timeint12a_implicit_be.f90   --external-source src/legacy/b1_10_port/headcalc.f90   --external-module-source "$BUILD/mod_fpe_timeint03_reference_binding.f90"   --external-module-source tests/fpe/mod_fpe_timeint12_dynamic_top_provider.f90   --build "$BUILD/be" --opt 2

python3 tests/fpe/run_fpe_timeint13.py   "$BUILD/order/timeint03_test"   "$BUILD/fullbdf2/timeint03_test"   "$BUILD/dyntop/timeint03_test"   "$BUILD/be/timeint03_test"   docs/performance/F-PE-BOFEK01_TESTBANK.json
