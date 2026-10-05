#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "$0")/../.." && pwd)"
build_dir="$(mktemp -d)"
trap 'rm -rf "$build_dir"' EXIT
cd "$build_dir"
for opt in 0 2; do
  gfortran -O"$opt" -fcheck=all -ffree-line-length-none \
    "$root_dir/src/runtime/mod_fmr_irrigation_water_limits.f90" \
    "$root_dir/tests/irrigation/test_mig431_water_limits.f90" -o "test_$opt"
  ./"test_$opt"
  printf 'F_MIG431_IRRIGATION_LIMITS_O%s=PASS\n' "$opt"
done
