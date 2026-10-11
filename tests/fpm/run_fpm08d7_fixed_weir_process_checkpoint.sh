#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
for opt in 0 2; do
  mkdir -p "$work/O$opt"
  gfortran -std=f2008 -Wall -Wextra -Werror -pedantic -O"$opt" -J"$work/O$opt" -I"$work/O$opt" \
    "$root/src/process/mod_restricted_fixed_weir_surface_water.f90" \
    "$root/tests/fpm/test_fpm08d7_fixed_weir_process.f90" \
    -o "$work/test_O$opt"
  "$work/test_O$opt" > "$work/out_O$opt.txt"
  grep -q '^PASS_FPM08D7_FIXED_WEIR_PROCESS$' "$work/out_O$opt.txt"
done
cmp "$work/out_O0.txt" "$work/out_O2.txt"
echo PASS_FPM08D7_FIXED_WEIR_O0_O2_IDENTITY
