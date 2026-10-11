#!/usr/bin/env bash
set -euo pipefail
B="${TMPDIR:-/tmp}/swap5-a24";rm -rf "${B}";mkdir -p "${B}"
"${FC:-gfortran}" -std=f2008 -Wall -Wextra -pedantic \
 src/solver/mod_soil_water_solver_contract.f90 \
 src/runtime/mod_rfm_matrix_source_provider.f90 \
 tests/fpm/test_ppa_wu05a24_rfm_matrix_source_provider.f90 \
 -J"${B}" -o "${B}/a24"
"${B}/a24"
