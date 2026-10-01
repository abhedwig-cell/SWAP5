#!/usr/bin/env bash
set -euo pipefail
B="${TMPDIR:-/tmp}/swap5-a25-node-s";rm -rf "${B}";mkdir -p "${B}"
"${FC:-gfortran}" -std=f2008 -Wall -Wextra -pedantic \
 src/solver/mod_soil_water_solver_contract.f90 \
 src/runtime/mod_process_hydraulic_view.f90 \
 src/process/macropore/mod_rfm_surface_sorptivity.f90 \
 tests/fpm/test_ppa_wu05a25_rfm_node_sorptivity.f90 \
 -J"${B}" -o "${B}/a25s"
"${B}/a25s"
