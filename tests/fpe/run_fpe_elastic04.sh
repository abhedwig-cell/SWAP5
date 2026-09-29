#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)";cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic04-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD";trap 'rm -rf "$BUILD"' EXIT
python3 tests/rom/materialize_f_rom0_headcalc_stubs.py --source tests/fsi/fsi04_real_headcalc_stubs.f90 --output "$BUILD/stub.f90" --nodes 16 --dz-cm 10
python3 tests/rom/compile_f_rom0_fortran_closure.py --root "$ROOT" --stub "$BUILD/stub.f90" --target tests/fpe/test_fpe_elastic04_provider_identity.f90 --external-source tests/fpe/mod_fpe_elastic01_provider.f90 --external-source tests/fpe/mod_fpe_elastic04_typed_provider.f90 --build "$BUILD/provider" --opt 2
python3 tests/fpe/run_fpe_elastic04_provider_identity.py "$BUILD/provider/rom0_test" docs/performance/evidence/F-PE-ELASTIC02_STARINGREEKS_2018.csv

python3 tests/rom/compile_f_rom0_fortran_closure.py --root "$ROOT" --stub "$BUILD/stub.f90" --target tests/fpe/test_fpe_elastic01_case.f90 --external-source src/legacy/b1_10_port/headcalc.f90 --external-source tests/fpe/mod_fpe_elastic01_provider.f90 --build "$BUILD/legacy" --opt 2
python3 tests/rom/compile_f_rom0_fortran_closure.py --root "$ROOT" --stub "$BUILD/stub.f90" --target tests/fpe/test_fpe_elastic04_case.f90 --external-source src/legacy/b1_10_port/headcalc.f90 --external-source tests/fpe/mod_fpe_elastic04_typed_provider.f90 --build "$BUILD/typed" --opt 2
python3 tests/fpe/run_fpe_elastic04_dynamic_identity.py "$BUILD/legacy/rom0_test" "$BUILD/typed/rom0_test" docs/performance/evidence/F-PE-ELASTIC02_STARINGREEKS_2018.csv
