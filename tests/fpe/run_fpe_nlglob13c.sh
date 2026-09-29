#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-nlglob13c-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"; trap 'rm -rf "$BUILD"' EXIT

python3 tests/rom/materialize_f_rom0_headcalc_stubs.py --source tests/fsi/fsi04_real_headcalc_stubs.f90 --output "$BUILD/stub.f90" --nodes 16 --dz-cm 10
python3 tests/fpe/materialize_fpe_timeint03_binding.py --source src/adapter/mod_reference_richards_legacy_binding.f90 --output "$BUILD/mod_fpe_timeint03_reference_binding.f90"
python3 tests/fpe/materialize_fpe_nlglob11a_headspace_predictor.py --source tests/fpe/test_fpe_timeint17a_same_route.f90 --output "$BUILD/timeint17a_headspace.f90"
python3 tests/fpe/materialize_fpe_nlglob13_subdivision.py --source "$BUILD/timeint17a_headspace.f90" --output "$BUILD/timeint17a_subdiv2.f90"
python3 tests/fpe/materialize_fpe_nlglob13b_quarter_subdivision.py --source "$BUILD/timeint17a_subdiv2.f90" --output "$BUILD/timeint17a_subdiv4.f90"
python3 tests/fpe/materialize_fpe_nlglob13c_overshoot_log.py --source "$BUILD/timeint17a_subdiv4.f90" --output "$BUILD/timeint17a_scaling.f90"

python3 tests/fpe/materialize_fpe_nlglob09_s0_replay.py --source src/legacy/b1_10_port/headcalc.f90 --output "$BUILD/headcalc_s0.f90"
python3 tests/fpe/materialize_fpe_nlglob12a1_representation_accept.py --source "$BUILD/headcalc_s0.f90" --output "$BUILD/headcalc_replay.f90"

python3 tests/fpe/compile_fpe_timeint03_closure.py --root "$ROOT" --stub "$BUILD/stub.f90" \
  --target "$BUILD/timeint17a_scaling.f90" --external-source "$BUILD/headcalc_replay.f90" \
  --external-module-source "$BUILD/mod_fpe_timeint03_reference_binding.f90" \
  --external-module-source tests/fpe/mod_fpe_timeint13_predicted_k_provider.f90 --build "$BUILD/candidate" --opt 2

python3 tests/fpe/run_fpe_nlglob13c.py "$BUILD/candidate/timeint03_test" docs/performance/F-PE-BOFEK01_TESTBANK.json
