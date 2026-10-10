#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
for opt in O0 O2; do
  gfortran -"$opt" -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror \
    -fcheck=all -ffpe-trap=invalid,zero,overflow \
    "$root/src/crop/mod_b111_nfixation_policy.f90" \
    "$root/tests/fwof/pp02/test_b111_nfixation_policy.f90" \
    -o "$work/test_nfix"
  "$work/test_nfix"
done
python3 "$root/tools/audits/probe_swap431_b111_nfix_policy.py"
