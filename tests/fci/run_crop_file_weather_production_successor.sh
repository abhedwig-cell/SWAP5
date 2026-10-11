#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
# Exact bounded live-window successor: preceding physical day only; no
# initial-day, emerged WOFOST, root coupling or external disk codec admission.
BASE=e3b9685470639355e1899b95c25f9a7ddee15fe6
fail(){ echo "CROP_FILE_WEATHER_SOURCE_SUCCESSOR_FAIL $*" >&2; exit 1; }
git merge-base --is-ancestor "$BASE" HEAD || fail 'reconciled canonical baseline absent'
test "$(git rev-parse HEAD:src/adapter/mod_swap_daily_weather_file_adapter.f90)" = eb1fe3881b53209e01aba7bec0d69a8160bb29c6 || fail 'postimage drift: src/adapter/mod_swap_daily_weather_file_adapter.f90'
test "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" = 2f58adace1d37a661d53e42e87feead32db83ba9 || fail 'postimage drift: src/runtime/mod_fmr_production_application_bootstrap.f90'
test "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_multiswap_runtime.f90)" = d320ea43f8dd0958c841c86a00beb22282588656 || fail 'postimage drift: src/runtime/mod_fmr_serialized_multiswap_runtime.f90'
test "$(git rev-parse HEAD:tests/fmig431/run_crop_file_weather_production.sh)" = 8750f319b4e25f014d788bf6154f65a8a2eb1217 || fail 'postimage drift: tests/fmig431/run_crop_file_weather_production.sh'
test "$(git rev-parse HEAD:tests/fmig431/test_crop_file_weather_production.f90)" = 4af910089b132cbc3213d372730b7885511a71b2 || fail 'postimage drift: tests/fmig431/test_crop_file_weather_production.f90'
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
