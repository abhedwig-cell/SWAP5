#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-nlglob14n1-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"; trap 'rm -rf "$BUILD"' EXIT

python3 tests/rom/materialize_f_rom0_headcalc_stubs.py --source tests/fsi/fsi04_real_headcalc_stubs.f90 --output "$BUILD/stub.f90" --nodes 16 --dz-cm 10
python3 tests/fpe/materialize_fpe_timeint03_binding.py --source src/adapter/mod_reference_richards_legacy_binding.f90 --output "$BUILD/mod_fpe_timeint03_reference_binding.f90"

python3 tests/fpe/materialize_fpe_nlglob11a_headspace_predictor.py --source tests/fpe/test_fpe_timeint17a_same_route.f90 --output "$BUILD/timeint17a_headspace.f90"
python3 tests/fpe/materialize_fpe_nlglob13_subdivision.py --source "$BUILD/timeint17a_headspace.f90" --output "$BUILD/timeint17a_subdiv.f90"
python3 tests/fpe/materialize_fpe_nlglob14a_root.py --source "$BUILD/timeint17a_subdiv.f90" --output "$BUILD/timeint17a_root.f90"
python3 tests/fpe/materialize_fpe_nlglob14c_klag_remainder.py --source "$BUILD/timeint17a_root.f90" --output "$BUILD/timeint17a_switch.f90"
python3 tests/fpe/materialize_fpe_nlglob14d_persistent_mode.py --source "$BUILD/timeint17a_switch.f90" --output "$BUILD/timeint17a_policy.f90"
python3 tests/fpe/materialize_fpe_nlglob14f_state_log.py --source "$BUILD/timeint17a_policy.f90" --output "$BUILD/timeint17a_stateobs.f90"
python3 tests/fpe/materialize_fpe_nlglob14g_forcing_reversal.py --source "$BUILD/timeint17a_stateobs.f90" --output "$BUILD/timeint17a_reversal.f90"
python3 tests/fpe/materialize_fpe_nlglob14n1_root_failure.py --source "$BUILD/timeint17a_reversal.f90" --output "$BUILD/timeint17a_diag.f90"

python3 tests/fpe/materialize_fpe_nlglob09_s0_replay.py --source src/legacy/b1_10_port/headcalc.f90 --output "$BUILD/headcalc_s0.f90"
python3 tests/fpe/materialize_fpe_nlglob12a1_representation_accept.py --source "$BUILD/headcalc_s0.f90" --output "$BUILD/headcalc_replay.f90"

python3 tests/fpe/compile_fpe_timeint03_closure.py --root "$ROOT" --stub "$BUILD/stub.f90"   --target "$BUILD/timeint17a_diag.f90" --external-source "$BUILD/headcalc_replay.f90"   --external-module-source "$BUILD/mod_fpe_timeint03_reference_binding.f90"   --external-module-source tests/fpe/mod_fpe_timeint13_predicted_k_provider.f90 --build "$BUILD/dynamic" --opt 2

python3 tests/fpe/run_fpe_nlglob14n1.py "$BUILD/dynamic/timeint03_test" docs/performance/F-PE-BOFEK01_TESTBANK.json
