#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
for opt in -O0 -O2; do
  gfortran "$opt" -std=f2008 -ffree-line-length-none -fcheck=all \
    -ffpe-trap=invalid,zero,overflow \
    "$root/src/crop/mod_b111_crop_n_fixation_policy.f90" \
    "$root/tests/fwof/pp02/test_b111_crop_n_fixation_policy.f90" \
    -o "$work/test_b111_nfix"
  "$work/test_b111_nfix"
done
