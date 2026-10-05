#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "$0")/../.." && pwd)"
build_dir="$(mktemp -d)"
trap 'rm -rf "$build_dir"' EXIT
cd "$build_dir"
for opt in 0 2; do
  gfortran -O"$opt" -fcheck=all -ffree-line-length-none \
    "$root_dir/src/process/mod_tillage_constitutive_process.f90" \
    "$root_dir/src/runtime/mod_fmr_tillage_event_owner.f90" \
    "$root_dir/tests/tillage/test_mig431_tillage_owner.f90" -o "test_$opt"
  ./"test_$opt"
  printf 'F_MIG431_TILLAGE_OWNER_O%s=PASS\n' "$opt"
done
