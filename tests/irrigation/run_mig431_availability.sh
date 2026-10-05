#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "$0")/../.." && pwd)"
build_dir="$(mktemp -d)"
trap 'rm -rf "$build_dir"' EXIT
cd "$build_dir"
for opt in 0 2; do
  gfortran -O"$opt" -fcheck=all -ffree-line-length-none \
    "$root_dir/src/process/mod_irrigation_availability_process.f90" \
    "$root_dir/tests/irrigation/test_mig431_availability.f90" -o "test_$opt"
  ./"test_$opt"
  printf 'F_MIG431_EXTERNAL_AVAILABILITY_O%s=PASS\n' "$opt"
done
