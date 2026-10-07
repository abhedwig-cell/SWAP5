#!/usr/bin/env bash
set -euo pipefail
FC="${FC:-gfortran}"
for opt in 0 2; do
 d="$(mktemp -d)"; trap 'rm -rf "$d"' EXIT
 "$FC" -std=f2008 -Wall -Wextra -Werror -O"$opt" -J"$d" -I"$d" \
   src/runtime/mod_fmr_legacy_explicit_cauchy_bottom_boundary_provider.f90 \
   tests/fmig431/test_low03_explicit_provider.f90 -o "$d/t"
 "$d/t"
 rm -rf "$d"; trap - EXIT
done

# Serialized binding is compiled by canonical qualification; this focused gate remains the independent pure source oracle.
