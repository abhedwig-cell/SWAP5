#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-timeint17d-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"; trap 'rm -rf "$BUILD"' EXIT
python3 tests/rom/materialize_f_rom0_headcalc_stubs.py --source tests/fsi/fsi04_real_headcalc_stubs.f90 --output "$BUILD/stub.f90" --nodes 16 --dz-cm 10
python3 tests/fpe/compile_fpe_timeint03_closure.py --root "$ROOT" --stub "$BUILD/stub.f90" \
  --target tests/fpe/test_fpe_timeint17d_provider_fd.f90 --build "$BUILD/candidate" --opt 2
python3 tests/fpe/run_fpe_timeint17d.py "$BUILD/candidate/timeint03_test" docs/performance/F-PE-BOFEK01_TESTBANK.json
