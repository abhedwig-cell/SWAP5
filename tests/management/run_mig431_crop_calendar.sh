#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "$0")/../.." && pwd)"
build_dir="$(mktemp -d)"
trap 'rm -rf "$build_dir"' EXIT
cd "$build_dir"
for opt in 0 2; do
  gfortran -O"$opt" -fcheck=all -ffree-line-length-none \
    "$root_dir/src/process/mod_crop_calendar_management_process.f90" \
    "$root_dir/src/runtime/mod_fmr_crop_calendar_restart.f90" \
    "$root_dir/tests/management/test_mig431_crop_calendar.f90" -o "test_$opt"
  ./"test_$opt"
  gfortran -O"$opt" -fcheck=all -ffree-line-length-none \
    "$root_dir/src/process/mod_crop_calendar_management_process.f90" \
    "$root_dir/src/runtime/mod_fmr_crop_calendar_observation_binding.f90" \
    "$root_dir/tests/management/test_mig431_crop_observation.f90" -o "observation_$opt"
  ./"observation_$opt"
  printf 'F_MIG431_CROP_CALENDAR_O%s=PASS\n' "$opt"
done
