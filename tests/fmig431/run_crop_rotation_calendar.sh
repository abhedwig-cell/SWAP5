#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for opt in 0 2; do
  (
    cd "$TMP"
    gfortran -std=f2008 -O"$opt" -Wall -Wextra -Werror -fcheck=all \
      "$ROOT/src/crop/mod_crop_rotation_calendar.f90" \
      "$ROOT/tests/fmig431/test_crop_rotation_calendar.f90" -o "calendar_O$opt"
    "./calendar_O$opt"
  )
done
echo 'SW431_CROP_CALENDAR_SELECTOR_O0_O2=PASS'
