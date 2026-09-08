#!/usr/bin/env bash
set -euo pipefail
repo=$(git rev-parse --show-toplevel)
work=$(mktemp -d)
trap 'find "$work" -type f -delete; rmdir "$work"' EXIT
for opt in 0 2; do
  gfortran -O"$opt" -std=f2008 -Wall -Wextra -Werror -fcheck=all \
    "$repo/src/process/mod_snow_process.f90" "$repo/tests/fpm/test_fpm02_snow_process.f90" \
    -J"$work" -o "$work/fpm02_o$opt"
  "$work/fpm02_o$opt" > "$work/out_o$opt"
done
cmp "$work/out_o0" "$work/out_o2"
grep -q '^FPM02_SNOW_PROCESS_PASS$' "$work/out_o0"
