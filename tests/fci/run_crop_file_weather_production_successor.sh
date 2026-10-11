#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
# Exact source-qualified task2/task3 successor; independent pre-emergence
# flags and schema2 restart use the existing owner. Delayed emergence remains
# explicitly blocked. Preserve bounded default physical outputs.
# Initial crop creation and preceding
# physical day events and immediate source-backed initial owner; no emerged
# daily growth, root coupling or external disk codec admission.
BASE=0d9f2c5da26e2214c3b19d56acdc734bf62d33f4
fail(){ echo "CROP_FILE_WEATHER_SOURCE_SUCCESSOR_FAIL $*" >&2; exit 1; }
verify_crop_frost_highest(){
  if [[ "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" == bc04a4239b2b0d8ef21f962af14be6ef28fbe436 ]]; then
    python3 tests/fmig431/run_crop_task2_frost_successor.py --verify-only
  else
    python3 tests/frost/run_frost_nan_guard_highest_successor.py --verify-only
  fi
}
git merge-base --is-ancestor "$BASE" HEAD || fail 'reconciled canonical baseline absent'
test "$(git rev-parse HEAD:src/adapter/mod_swap_daily_weather_file_adapter.f90)" = eb1fe3881b53209e01aba7bec0d69a8160bb29c6 || fail 'postimage drift: src/adapter/mod_swap_daily_weather_file_adapter.f90'
test "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" = bc04a4239b2b0d8ef21f962af14be6ef28fbe436 || fail 'postimage drift: src/runtime/mod_fmr_production_application_bootstrap.f90'
test "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_multiswap_runtime.f90)" = d320ea43f8dd0958c841c86a00beb22282588656 || fail 'postimage drift: src/runtime/mod_fmr_serialized_multiswap_runtime.f90'
test "$(git rev-parse HEAD:tests/fmig431/run_crop_file_weather_production.sh)" = cf317b2130e3f685caf92f6d3a46ae933e100335 || fail 'postimage drift: tests/fmig431/run_crop_file_weather_production.sh'
test "$(git rev-parse HEAD:tests/fmig431/test_crop_file_weather_production.f90)" = 97b810649eb9c8c5207061c17651d2eec7ec2ee8 || fail 'postimage drift: tests/fmig431/test_crop_file_weather_production.f90'
test "$(git rev-parse HEAD:tests/support/augment_bartholomeus_backend_sources.py)" = a811a0a0684ebb39c32bb7376426eb86e4f13826 || fail 'postimage drift: tests/support/augment_bartholomeus_backend_sources.py'
test "$(git rev-parse HEAD:src/crop/mod_wofost_emergence_initialization.f90)" = 22847445e59e64238ae3de843dcd1f0723b2d11d || fail "postimage drift: src/crop/mod_wofost_emergence_initialization.f90"
test "$(git rev-parse HEAD:src/crop/mod_crop_lifecycle_continuation.f90)" = d465dfe184048797d3932e8783869e7f25a6e38d || fail 'historical task2 source drift: src/crop/mod_crop_lifecycle_continuation.f90'
test "$(git rev-parse HEAD:src/crop/mod_crop_lifecycle_daily_composition.f90)" = 0a80e03bf2dd013eec61bbe972f8eeb64f05b2f8 || fail 'historical task2 source drift: src/crop/mod_crop_lifecycle_daily_composition.f90'
test "$(git rev-parse HEAD:src/runtime/mod_fmr_crop_weather_physical_event_composition.f90)" = 14b8d5e07c7abb08416a3d64e05fc06e9737af4a || fail 'historical task2 source drift: src/runtime/mod_fmr_crop_weather_physical_event_composition.f90'
test "$(git rev-parse HEAD:src/runtime/mod_fmr_wofost_crop_transaction.f90)" = 0f7fccc714a908083f4550394ca1fdd28f354d47 || fail 'historical task2 source drift: src/runtime/mod_fmr_wofost_crop_transaction.f90'
while IFS= read -r path; do
  case "$path" in
src/crop/mod_crop_lifecycle_continuation.f90|src/crop/mod_crop_lifecycle_daily_composition.f90|src/runtime/mod_fmr_crop_weather_physical_event_composition.f90|src/runtime/mod_fmr_wofost_crop_transaction.f90|src/runtime/mod_fmr_production_application_bootstrap.f90) ;;
    src/process/mod_frost_hydraulic_effect.f90)
      # Central bounded invalid-input successor, not crop science drift.
      # Complete highest/current F-CI archive and affected crop owner O0/O2
      # evidence are required; no allowance for an arbitrary frost postimage.
      test "$(git rev-parse "HEAD:$path")" = 0dd5b541af936d292d23575f798c3cdd5be19c47 || fail "unqualified frost invalid-input successor: $path"
      verify_crop_frost_highest || fail 'frost invalid-input qualified archive'
      ;;

    src/runtime/mod_fmr_irrigation_allocation_binding.f90)
      # Disjoint MC-IRR01 successor. It is absent from the immutable crop
      # compile closure; full irrigation preservation owns its execution.
      # No wildcard allowance for any further source or owner mutation.
      test "$(git rev-parse "HEAD:$path")" = ab5ac97c5017da9ba0560e674fb5888e422de5e5 || fail "unqualified irrigation allocation successor: $path"
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
