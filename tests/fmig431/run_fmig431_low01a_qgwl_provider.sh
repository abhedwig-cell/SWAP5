#!/usr/bin/env bash
set -euo pipefail
build="${TMPDIR:-/tmp}/fmig431-low01a-provider-$$"
trap 'rm -rf "$build"' EXIT
mkdir -p "$build"
gfortran -std=f2008 -Wall -Wextra -Werror -J "$build" -I "$build" \
  src/runtime/mod_fmr_legacy_qgwl_bottom_boundary_provider.f90 \
  tests/fmig431/test_fmig431_low01a_qgwl_provider.f90 -o "$build/test"
"$build/test"
