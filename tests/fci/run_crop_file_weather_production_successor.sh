#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
# Exact bounded live-window successor: initial crop creation and preceding
# physical day events and immediate source-backed initial owner; no emerged
# daily growth, root coupling or external disk codec admission.
BASE=2bc609a3a9ca14a5efb05a8a8849ced1f22a2036
fail(){ echo "CROP_FILE_WEATHER_SOURCE_SUCCESSOR_FAIL $*" >&2; exit 1; }
git merge-base --is-ancestor "$BASE" HEAD || fail 'reconciled canonical baseline absent'
test "$(git rev-parse HEAD:src/adapter/mod_swap_daily_weather_file_adapter.f90)" = eb1fe3881b53209e01aba7bec0d69a8160bb29c6 || fail 'postimage drift: src/adapter/mod_swap_daily_weather_file_adapter.f90'
test "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" = d3a0719dfd5c7fb7a0061502c56fe4eede1ca9de || fail 'postimage drift: src/runtime/mod_fmr_production_application_bootstrap.f90'
test "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_multiswap_runtime.f90)" = d320ea43f8dd0958c841c86a00beb22282588656 || fail 'postimage drift: src/runtime/mod_fmr_serialized_multiswap_runtime.f90'
test "$(git rev-parse HEAD:tests/fmig431/run_crop_file_weather_production.sh)" = f848713d8638a7e8da03c53922cc8d83e7b35f0b || fail 'postimage drift: tests/fmig431/run_crop_file_weather_production.sh'
test "$(git rev-parse HEAD:tests/fmig431/test_crop_file_weather_production.f90)" = 598b06fba84d4d818b4c42504bb8a52d5d19f42a || fail 'postimage drift: tests/fmig431/test_crop_file_weather_production.f90'
test "$(git rev-parse HEAD:tests/support/augment_bartholomeus_backend_sources.py)" = a811a0a0684ebb39c32bb7376426eb86e4f13826 || fail 'postimage drift: tests/support/augment_bartholomeus_backend_sources.py'
test "$(git rev-parse HEAD:src/crop/mod_wofost_emergence_initialization.f90)" = 22847445e59e64238ae3de843dcd1f0723b2d11d || fail "postimage drift: src/crop/mod_wofost_emergence_initialization.f90"
while IFS= read -r path; do
  case "$path" in
    src/crop/mod_wofost_emergence_initialization.f90|src/adapter/mod_swap_daily_weather_file_adapter.f90|src/runtime/mod_fmr_production_application_bootstrap.f90|src/runtime/mod_fmr_serialized_multiswap_runtime.f90) ;;
    src/process/mod_frost_hydraulic_effect.f90)
      # Central bounded invalid-input successor, not crop science drift.
      # Complete highest/current F-CI archive and affected crop owner O0/O2
      # evidence are required; no allowance for an arbitrary frost postimage.
      test "$(git rev-parse "HEAD:$path")" = 0dd5b541af936d292d23575f798c3cdd5be19c47 || fail "unqualified frost invalid-input successor: $path"
      python3 tests/frost/run_mc_irr01_managed_weather_highest_successor.py --verify-only || fail 'frost invalid-input qualified archive'
      ;;
    src/runtime/mod_fmr_irrigation_allocation_binding.f90)
      # Centrally scoped managed-weather preparation successor. The current
      # crop closure now includes this module; both owner gates must execute.
      # No wildcard allowance for any further source or owner mutation.
      test "$(git rev-parse "HEAD:$path")" = dfe51ab8e50204e8a7adc84219757a7b77df68e2 || fail "unqualified irrigation allocation successor: $path"
      ;;
    *) fail "unqualified additional production mutation: $path" ;;
  esac
done < <(git diff --name-only "$BASE" HEAD -- src)
test "$(git rev-parse HEAD:reference)" = "$(git rev-parse "$BASE:reference")" || fail 'reference tree drift'
echo 'CROP_FILE_WEATHER_EXACT_SOURCE_SUCCESSOR=PASS'
if [[ "${1:-}" == --verify-only ]]; then exit 0; fi
bash tests/fmig431/run_crop_file_weather_production.sh
bash tests/fmig431/run_crop_fkt_b110_scientific_successor.sh
echo 'CROP_FILE_WEATHER_OWNER_CROSS_PRESERVATION=PASS'
