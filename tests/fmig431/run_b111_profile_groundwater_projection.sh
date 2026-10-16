#!/usr/bin/env bash
set -euo pipefail
FC="${FC:-gfortran}"
for opt in 0 2; do
  d="$(mktemp -d)"
  trap 'rm -rf "$d"' EXIT
  "$FC" -O"$opt" -std=f2008 -Wall -Wextra -Werror -J"$d" -I"$d" \
    src/solver/mod_b111_profile_groundwater_projection.f90 \
    tests/fmig431/test_b111_profile_groundwater_projection.f90 -o "$d/t"
  "$d/t"
  rm -rf "$d"; trap - EXIT
done
