#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${TMPDIR:-/tmp}/swap5-gwview01-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
gfortran -std=f2008 -ffree-line-length-none -O2 \
  src/runtime/mod_groundwater_coupling_contract.f90 \
  src/runtime/mod_modflow6_multiswap_cell_response.f90 \
  src/runtime/mod_modflow6_linear_response_backend.f90 \
  src/runtime/mod_modflow6_api_binding.f90 \
  tests/fpe/test_fpe_zero_waste01_gwview01.f90 \
  -o "$BUILD/test"
for n in 100 1000 3000 10000; do "$BUILD/test" "$n"; done
