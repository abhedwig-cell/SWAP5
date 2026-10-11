#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
# Exact bounded live-window successor: initial crop creation and preceding
# physical day events; no emerged WOFOST, root or external disk codec admission.
BASE=e3b9685470639355e1899b95c25f9a7ddee15fe6
fail(){ echo "CROP_FILE_WEATHER_SOURCE_SUCCESSOR_FAIL $*" >&2; exit 1; }
git merge-base --is-ancestor "$BASE" HEAD || fail 'reconciled canonical baseline absent'
test "$(git rev-parse HEAD:src/adapter/mod_swap_daily_weather_file_adapter.f90)" = eb1fe3881b53209e01aba7bec0d69a8160bb29c6 || fail 'postimage drift: src/adapter/mod_swap_daily_weather_file_adapter.f90'
test "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" = 7440ed4b9177e46887429bab49526dd33740b181 || fail 'postimage drift: src/runtime/mod_fmr_production_application_bootstrap.f90'
test "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_multiswap_runtime.f90)" = d320ea43f8dd0958c841c86a00beb22282588656 || fail 'postimage drift: src/runtime/mod_fmr_serialized_multiswap_runtime.f90'
test "$(git rev-parse HEAD:tests/fmig431/run_crop_file_weather_production.sh)" = e9aa70432108a5b3ab4d07d93a51d772e88c94a8 || fail 'postimage drift: tests/fmig431/run_crop_file_weather_production.sh'
test "$(git rev-parse HEAD:tests/fmig431/test_crop_file_weather_production.f90)" = b3eaa9d8cece36096a38ba16bb1b111eb2dda80c || fail 'postimage drift: tests/fmig431/test_crop_file_weather_production.f90'
test "$(git rev-parse HEAD:tests/support/augment_bartholomeus_backend_sources.py)" = a811a0a0684ebb39c32bb7376426eb86e4f13826 || fail 'postimage drift: tests/support/augment_bartholomeus_backend_sources.py'
while IFS= read -r path; do
  case "$path" in
    src/adapter/mod_swap_daily_weather_file_adapter.f90|src/runtime/mod_fmr_production_application_bootstrap.f90|src/runtime/mod_fmr_serialized_multiswap_runtime.f90) ;;
    *) fail "unqualified additional production mutation: $path" ;;
  esac
done < <(git diff --name-only "$BASE" HEAD -- src)
test "$(git rev-parse HEAD:reference)" = "$(git rev-parse "$BASE:reference")" || fail 'reference tree drift'
echo 'CROP_FILE_WEATHER_EXACT_SOURCE_SUCCESSOR=PASS'
if [[ "${1:-}" == --verify-only ]]; then exit 0; fi
bash tests/fmig431/run_crop_file_weather_production.sh
bash tests/fmig431/run_crop_fkt_b110_scientific_successor.sh
echo 'CROP_FILE_WEATHER_OWNER_CROSS_PRESERVATION=PASS'
